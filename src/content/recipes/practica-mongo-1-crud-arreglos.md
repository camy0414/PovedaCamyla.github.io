---
title: "Práctica MongoDB 1: CRUD, operadores y arreglos"
description: Ejercicios propios sobre una plataforma de música ficticia, con filtros, proyecciones, $regex, $all, $elemMatch, $expr, $push con modificadores, arrayFilters, upsert y borrado.
date: 2026-11-23T12:03:00
---

Práctica hecha por mi cuenta, con un caso distinto a los de los talleres (`sample_mflix` y `sample_airbnb`): una **plataforma de música** ficticia con artistas, canciones, usuarios, playlists y escuchas. Los datos son inventados y pequeños a propósito, para poder comprobar cada resultado a mano.

<a href="/PovedaCamyla.github.io/evidencias/practicas/musica_dataset.js" download>Descargar el script de datos (musica_dataset.js)</a>

## El modelo

| Colección | Documento de ejemplo | Decisión de modelado |
|---|---|---|
| `artistas` | nombre, país, géneros | Colección propia: se consulta sola |
| `canciones` | título, `artista: { _id, nombre }`, año, duración, géneros, reproducciones | Copia del nombre del artista (*Extended Reference*) para no hacer `$lookup` al listar |
| `usuarios` | nombre, plan, país, `preferencias: { generos, idioma }` | Las preferencias van embebidas: siempre se leen con el usuario |
| `playlists` | nombre, dueño, `canciones: [{ cancion_id, titulo, agregada }]` | Arreglo acotado de referencias con el título copiado |
| `escuchas` | usuario, canción, fecha, segundos, dispositivo | Colección aparte: crece sin límite, no puede ir embebida en el usuario |

```javascript
// Un documento de cada colección
{ _id: 8, titulo: "Mar de papel", artista: { _id: "a3", nombre: "Lucía Ríos" },
  anio: 2022, duracion_seg: 203, generos: ["pop", "folk"], reproducciones: 27300, explicito: false }

{ _id: "pl1", nombre: "Para estudiar", usuario_id: "u1", publica: true, seguidores: 120,
  canciones: [ { cancion_id: 7, titulo: "Raíces", agregada: ISODate("2026-09-01T00:00:00Z") }, ... ] }

{ usuario_id: "u1", cancion_id: 8, fecha: ISODate("2026-11-16T08:10:00Z"), segundos: 203, dispositivo: "movil" }
```

Antes de cada práctica conviene **volver a cargar el script de datos**, porque los ejercicios de actualización cambian los documentos.

## Consultas

### 1.1 Filtros combinados y proyección

**Enunciado.** Liste las canciones de pop o folk lanzadas desde 2020 que no sean explícitas. Muestre solo título, artista y año, de la más a la menos reproducida.

```javascript
use('musica_practica');

db.canciones.find(
  { generos: { $in: ["pop", "folk"] }, anio: { $gte: 2020 }, explicito: false },
  { _id: 0, titulo: 1, "artista.nombre": 1, anio: 1 }
).sort({ reproducciones: -1 });
```

**Resultado esperado:**

```javascript
{ titulo: "Noche de neón", artista: { nombre: "Neón Sur" }, anio: 2022 }
{ titulo: "Mar de papel",  artista: { nombre: "Lucía Ríos" }, anio: 2022 }
```

**Por qué así.** Las condiciones separadas por coma en el mismo documento son un `AND` implícito; no hace falta `$and`. `$in` sobre un arreglo (`generos`) es verdadero si **algún** elemento está en la lista. *Brillo* es pop y de 2024, pero queda fuera por `explicito: true`. Se puede ordenar por `reproducciones` aunque no se proyecte.

### 1.2 Búsqueda por texto parcial

**Enunciado.** Encuentre las canciones cuyo título contenga “mar”, sin importar mayúsculas.

```javascript
db.canciones.find({ titulo: { $regex: "mar", $options: "i" } }, { _id: 0, titulo: 1 })
            .sort({ titulo: 1 });
```

**Resultado esperado:** `Mar de papel` y `Marea electrónica`.

**Por qué así.** Una expresión regular sin ancla (`^`) obliga a revisar todos los títulos, aunque haya índice. Si la búsqueda fuera “empieza por”, `/^Mar/` (sensible a mayúsculas) sí podría usar un índice sobre `titulo`. Para búsquedas de palabras en un catálogo grande es mejor un índice de texto (práctica 3).

### 1.3 Condiciones sobre el contenido de un arreglo

**Enunciado.** Liste las canciones que tengan exactamente dos géneros y uno de ellos sea electrónica.

```javascript
db.canciones.find(
  { generos: { $all: ["electrónica"], $size: 2 } },
  { _id: 0, titulo: 1, generos: 1 }
);
```

**Resultado esperado:**

```javascript
{ titulo: "Noche de neón",     generos: ["electrónica", "pop"] }
{ titulo: "Marea electrónica", generos: ["cumbia", "electrónica"] }
```

**Por qué así.** `$all` exige que el arreglo contenga todos los valores dados, en cualquier orden. `$size` solo acepta un número exacto; para “dos o más géneros” habría que usar `{ "generos.1": { $exists: true } }` (existe la posición 1) o `$expr` con `$size`.

### 1.4 $elemMatch: el error clásico con arreglos de documentos

**Enunciado.** ¿Hay alguna playlist que tenga la canción 11 agregada **antes** de octubre de 2026? Compare la consulta con notación de punto y con `$elemMatch`.

```javascript
// Versión con notación de punto
db.playlists.find(
  { "canciones.cancion_id": 11, "canciones.agregada": { $lt: ISODate("2026-10-01") } },
  { nombre: 1 }
);
// -> { _id: "pl1", nombre: "Para estudiar" }   ¡incorrecto!

// Versión con $elemMatch
db.playlists.find(
  { canciones: { $elemMatch: { cancion_id: 11, agregada: { $lt: ISODate("2026-10-01") } } } },
  { nombre: 1 }
);
// -> sin resultados   (correcto: la canción 11 se agregó el 3 de octubre)
```

**Por qué así.** Con notación de punto, cada condición se puede cumplir en un **elemento distinto** del arreglo: en *Para estudiar* la canción 11 cumple la primera y la canción 7 (agregada el 1 de septiembre) cumple la segunda. `$elemMatch` exige que **un mismo elemento** cumpla todas las condiciones.

### 1.5 Comparar dos campos del mismo documento con $expr

**Enunciado.** Encuentre las playlists que tienen más de 100 seguidores por cada canción que contienen.

```javascript
db.playlists.find(
  { $expr: { $gt: ["$seguidores", { $multiply: [{ $size: "$canciones" }, 100] }] } },
  { nombre: 1, seguidores: 1 }
);
```

**Resultado esperado:** `{ _id: "pl2", nombre: "Rumba", seguidores: 540 }` (540 > 4 × 100).

**Por qué así.** Los operadores normales de consulta comparan un campo con un valor fijo. `$expr` permite usar expresiones de agregación dentro de `find`, y con ellas comparar un campo contra otro campo o contra un cálculo. Como depende de cada documento, no puede aprovechar un índice para esa condición.

## Modificaciones

### 1.6 Contador con $inc y $currentDate

**Enunciado.** Registre una reproducción de la canción 6: sume 1 a sus reproducciones y guarde la fecha de la última reproducción.

```javascript
db.canciones.updateOne(
  { _id: 6 },
  { $inc: { reproducciones: 1 }, $currentDate: { ultima_reproduccion: true } }
);
// { acknowledged: true, matchedCount: 1, modifiedCount: 1, upsertedCount: 0 }
```

**Por qué así.** `$inc` es atómico: si mil usuarios reproducen la canción a la vez, ninguna suma se pierde. Leer el valor, sumarle 1 en la aplicación y guardarlo con `$set` sí perdería reproducciones (actualización perdida). `$currentDate` usa la hora del servidor, no la del cliente.

### 1.7 Historial reciente con $push, $each y $slice

**Enunciado.** Guarde en el usuario `u2` sus últimas canciones escuchadas, conservando **solo las 3 más recientes**. Agregue dos canciones en una sola operación.

```javascript
db.usuarios.updateOne(
  { _id: "u2" },
  { $push: { recientes: {
      $each: [ { cancion_id: 2, fecha: ISODate("2026-11-17T07:45:00Z") },
               { cancion_id: 3, fecha: ISODate("2026-11-20T08:00:00Z") } ],
      $sort:  { fecha: 1 },
      $slice: -3
  } } }
);
```

**Por qué así.** Es el patrón *Subset*: el usuario guarda una parte pequeña y acotada de su historial (lo que se muestra en su perfil) y el historial completo sigue en `escuchas`. `$slice: -3` conserva los tres últimos tras ordenar, así el arreglo nunca crece sin límite. Si `recientes` no existe, `$push` lo crea.

### 1.8 $addToSet para no repetir

**Enunciado.** Agregue “alternativo” a los géneros preferidos de `u2`. Ejecute la sentencia dos veces y compare.

```javascript
db.usuarios.updateOne({ _id: "u2" }, { $addToSet: { "preferencias.generos": "alternativo" } });
// 1.ª vez: { matchedCount: 1, modifiedCount: 1 }
// 2.ª vez: { matchedCount: 1, modifiedCount: 0 }
```

**Por qué así.** `$addToSet` trata el arreglo como un conjunto: si el valor ya existe, no lo agrega. `matchedCount` y `modifiedCount` muestran la diferencia: el documento se encontró, pero no cambió.

### 1.9 Actualizar elementos de un arreglo con arrayFilters

**Enunciado.** La canción 8 cambió de nombre a “Mar de papel (en vivo)”. Actualice el título en la colección `canciones` y en todas las playlists donde aparece la copia.

```javascript
db.canciones.updateOne({ _id: 8 }, { $set: { titulo: "Mar de papel (en vivo)" } });

db.playlists.updateMany(
  { "canciones.cancion_id": 8 },
  { $set: { "canciones.$[c].titulo": "Mar de papel (en vivo)" } },
  { arrayFilters: [ { "c.cancion_id": 8 } ] }
);
// { matchedCount: 1, modifiedCount: 1 }   -> solo "Para estudiar" la contiene
```

**Por qué así.** Es el costo del *Extended Reference*: copiar el título evita un `$lookup` en cada lectura, pero obliga a actualizar las copias cuando cambia. Como los títulos casi nunca cambian y las playlists se leen todo el tiempo, compensa. `$[c]` con `arrayFilters` actualiza **todos** los elementos que cumplan el filtro; el posicional `$` solo actualizaría el **primero** que coincidió con la consulta.

### 1.10 Quitar una canción de todas las playlists con $pull

**Enunciado.** La canción 11 se retiró del catálogo. Quítela de todas las playlists.

```javascript
db.playlists.updateMany({}, { $pull: { canciones: { cancion_id: 11 } } });
// { matchedCount: 3, modifiedCount: 1 }
```

**Por qué así.** `$pull` recibe una condición y elimina todos los elementos que la cumplan. Con filtro `{}` revisa las tres playlists (`matchedCount: 3`), pero solo cambia la que tenía la canción. Filtrar con `{ "canciones.cancion_id": 11 }` haría lo mismo revisando menos documentos.

### 1.11 Upsert para estadísticas diarias

**Enunciado.** Lleve un contador de escuchas por día en `estadisticas_diarias`, sin consultar antes si el documento del día existe.

```javascript
db.estadisticas_diarias.updateOne(
  { _id: "2026-11-20" },
  { $inc: { escuchas: 1 }, $setOnInsert: { creado: new Date() } },
  { upsert: true }
);
// 1.ª vez: { matchedCount: 0, modifiedCount: 0, upsertedCount: 1, upsertedId: "2026-11-20" }
// 2.ª vez: { matchedCount: 1, modifiedCount: 1, upsertedCount: 0 }
```

**Por qué así.** Con `upsert: true`, si no hay documento que coincida, MongoDB lo crea a partir del filtro y de la actualización (`{ _id: "2026-11-20", escuchas: 1 }`). `$setOnInsert` solo se aplica cuando el documento se crea, así la fecha de creación no se sobrescribe. Hacerlo en dos pasos (buscar y luego insertar) puede crear duplicados si dos procesos llegan a la vez.

### 1.12 Borrar los saltos

**Enunciado.** Elimine las escuchas de 30 segundos o menos (canciones que el usuario saltó) y verifique cuántas se borraron.

```javascript
db.escuchas.countDocuments({ segundos: { $lte: 30 } });   // 1
db.escuchas.deleteMany({ segundos: { $lte: 30 } });
// { acknowledged: true, deletedCount: 1 }
```

**Por qué así.** Contar con el **mismo filtro** antes de borrar es una verificación barata: si el número no es el esperado, el filtro está mal. `deleteMany({})` sin filtro borraría toda la colección; para eso es mejor `drop()`, que además elimina los índices.
