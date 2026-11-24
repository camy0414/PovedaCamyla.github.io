---
title: "Práctica MongoDB 3: Validación, índices y modelado"
description: Validación con $jsonSchema, índices compuestos (ESR), únicos, de texto, parciales y TTL leídos con explain, y patrones de modelado Bucket y Computed sobre la plataforma de música.
date: 2026-11-23T12:01:00
---

Tercera práctica propia sobre la **plataforma de música** ([práctica 1](/PovedaCamyla.github.io/recipes/practica-mongo-1-crud-arreglos), [práctica 2](/PovedaCamyla.github.io/recipes/practica-mongo-2-agregaciones)). Aquí el foco no es *qué* devuelve una consulta sino **qué tan bien** se guarda y se encuentra la información.

## 3.1 Validación de esquema

**Enunciado.** Agregue a la colección `escuchas` una validación que exija `usuario_id` (texto), `cancion_id` (entero), `fecha` (fecha), `segundos` (entero entre 1 y 3600) y `dispositivo` (solo `movil`, `web` o `parlante`). Pruebe un documento válido y uno inválido.

```javascript
use('musica_practica');

db.runCommand({
  collMod: "escuchas",
  validator: { $jsonSchema: {
    bsonType: "object",
    required: ["usuario_id", "cancion_id", "fecha", "segundos", "dispositivo"],
    properties: {
      usuario_id:  { bsonType: "string" },
      cancion_id:  { bsonType: ["int", "long"] },
      fecha:       { bsonType: "date" },
      segundos:    { bsonType: ["int", "long"], minimum: 1, maximum: 3600 },
      dispositivo: { enum: ["movil", "web", "parlante"] }
    }
  } },
  validationLevel: "moderate",
  validationAction: "error"
});

// Válido
db.escuchas.insertOne({ usuario_id: "u5", cancion_id: 9, fecha: new Date(),
                        segundos: 234, dispositivo: "web" });

// Inválido: dispositivo no permitido y segundos fuera de rango
db.escuchas.insertOne({ usuario_id: "u5", cancion_id: 9, fecha: new Date(),
                        segundos: 0, dispositivo: "tv" });
// MongoServerError: Document failed validation
//   ... propertiesNotSatisfied: [ { propertyName: 'segundos', ... },
//                                 { propertyName: 'dispositivo', ... } ]
```

**Por qué así.** MongoDB no exige esquema, pero la aplicación sí espera uno: una escucha sin `fecha` rompería los reportes de la práctica 2. `$jsonSchema` pone esas reglas en la base de datos, igual que un `CHECK` en SQL. `collMod` agrega la validación a una colección que ya existe; para una nueva se pasa en `createCollection`. `validationLevel: "moderate"` valida inserciones y los documentos que ya cumplían, sin bloquear la actualización de documentos viejos que no cumplan. En mongosh los números sin decimales se guardan como `int` o `double` según cómo se escriban; si un cliente envía `234.0`, se puede usar `NumberInt(234)` o aceptar también `"double"` en el esquema.

## 3.2 Índice compuesto con la regla ESR

**Enunciado.** La pantalla “historial” muestra las escuchas de un usuario desde una fecha, de la más reciente a la más antigua. Cree el índice adecuado y compare el plan antes y después.

```javascript
const consulta = () => db.escuchas.find(
  { usuario_id: "u3", fecha: { $gte: ISODate("2026-11-17T00:00:00Z") } }
).sort({ fecha: -1 });

consulta().explain("executionStats");                 // antes: COLLSCAN

db.escuchas.createIndex({ usuario_id: 1, fecha: -1 }, { name: "ix_usuario_fecha" });

consulta().explain("executionStats");                 // después: IXSCAN
```

Qué mirar en el `explain`:

| Campo | Sin índice | Con `ix_usuario_fecha` |
|---|---|---|
| `winningPlan.stage` | `SORT` sobre `COLLSCAN` | `FETCH` sobre `IXSCAN` (sin `SORT`) |
| `totalDocsExamined` | todos los de la colección | 5 (solo los que se devuelven) |
| `totalKeysExamined` | 0 | 5 |
| `nReturned` | 5 | 5 |

**Por qué así.** La regla **ESR** (*Equality, Sort, Range*) ordena los campos del índice: primero el de igualdad (`usuario_id`), luego el de ordenamiento y al final el de rango. Aquí `fecha` es a la vez orden y rango, por eso basta un índice de dos campos. Como el índice ya guarda las escuchas de cada usuario ordenadas por fecha, MongoDB las lee en orden y no tiene que ordenar en memoria. La señal de un buen índice es `totalDocsExamined` ≈ `nReturned`. En 20 documentos la diferencia de tiempo no se nota; en millones de escuchas, sí.

## 3.3 Índice único compuesto

**Enunciado.** Un usuario no puede tener dos playlists con el mismo nombre, pero dos usuarios distintos sí. Haga que la base de datos lo garantice.

```javascript
db.playlists.createIndex({ usuario_id: 1, nombre: 1 }, { unique: true });

db.playlists.insertOne({ _id: "pl4", nombre: "Rumba", usuario_id: "u1", publica: true,
                         seguidores: 0, canciones: [] });        // OK: otro usuario
db.playlists.insertOne({ _id: "pl5", nombre: "Rumba", usuario_id: "u3", publica: true,
                         seguidores: 0, canciones: [] });
// MongoServerError: E11000 duplicate key error collection: musica_practica.playlists
//   index: usuario_id_1_nombre_1 dup key: { usuario_id: "u3", nombre: "Rumba" }
```

**Por qué así.** La unicidad es sobre la **combinación** de campos. Validarlo en la aplicación (buscar y luego insertar) deja una ventana en la que dos peticiones simultáneas pasan la validación; el índice único no tiene esa ventana. Es el mismo razonamiento del `DUP_VAL_ON_INDEX` del taller de PL/SQL.

## 3.4 Índice de texto

**Enunciado.** Permita buscar canciones por palabras del título, sin importar tildes ni mayúsculas.

```javascript
db.canciones.createIndex({ titulo: "text" }, { default_language: "spanish" });

db.canciones.find(
  { $text: { $search: "rio" } },
  { _id: 0, titulo: 1, score: { $meta: "textScore" } }
).sort({ score: { $meta: "textScore" } });
// { titulo: "Tambor del río", score: ... }
```

**Por qué así.** El índice de texto separa el título en palabras, quita las palabras vacías del español (*del*, *de*, *en*) y aplica raíces (*stemming*), y desde la versión 3 del índice ignora tildes: por eso “rio” encuentra “río”. A diferencia de `$regex`, busca **palabras** (raíces) y no fragmentos de texto, así que “mar” no se comporta como el `/mar/i` de la práctica 1. Solo puede haber un índice de texto por colección.

## 3.5 Índice parcial

**Enunciado.** La sección “Populares” solo consulta canciones con más de 10.000 reproducciones, ordenadas de mayor a menor. Cree un índice que cubra solo esas canciones.

```javascript
db.canciones.createIndex(
  { reproducciones: -1 },
  { name: "ix_populares", partialFilterExpression: { reproducciones: { $gt: 10000 } } }
);

// Usa el índice: el filtro está contenido en el del índice
db.canciones.find({ reproducciones: { $gt: 20000 } }).sort({ reproducciones: -1 });

// NO puede usarlo: pide canciones que el índice no tiene
db.canciones.find({ reproducciones: { $gt: 5000 } }).sort({ reproducciones: -1 });
```

**Por qué así.** Un índice parcial es más pequeño y más barato de mantener porque solo indexa los documentos que cumplen la expresión. La condición para usarlo es que la consulta garantice que todos los resultados están en el índice; si no, MongoDB lo descarta para no devolver resultados incompletos.

## 3.6 Índice TTL para sesiones

**Enunciado.** Guarde las sesiones de reproducción activas y haga que MongoDB las borre solas una hora después de la última actividad.

```javascript
db.sesiones.createIndex({ ultima_actividad: 1 }, { expireAfterSeconds: 3600 });

db.sesiones.insertOne({ usuario_id: "u1", dispositivo: "movil",
                        cancion_actual: 8, ultima_actividad: new Date() });

// Cada interacción renueva la sesión
db.sesiones.updateOne({ usuario_id: "u1" }, { $currentDate: { ultima_actividad: true } });
```

**Por qué así.** Un proceso de MongoDB revisa el índice TTL aproximadamente cada 60 segundos y borra los documentos cuya fecha más `expireAfterSeconds` ya pasó, así que el borrado no es exacto al segundo. El campo debe ser de tipo fecha; si no lo es, el documento nunca expira.

## 3.7 Modelado: patrones Bucket y Computed

**Enunciado.** Con millones de escuchas, guardar una por documento hace crecer mucho la colección y sus índices. Proponga un modelo con el patrón **Bucket** (un documento por usuario y día) que además guarde totales precalculados (**Computed**), y escriba la operación que registra una escucha.

```javascript
// Un documento por usuario y por día
{
  _id: "u3_2026-11-17",
  usuario_id: "u3",
  dia: ISODate("2026-11-17T00:00:00Z"),
  escuchas: [
    { cancion_id: 5,  hora: ISODate("2026-11-17T22:05:00Z"), segundos: 187 },
    { cancion_id: 4,  hora: ISODate("2026-11-17T22:09:00Z"), segundos: 221 },
    { cancion_id: 10, hora: ISODate("2026-11-17T22:13:00Z"), segundos: 258 }
  ],
  total_escuchas: 3,      // Computed
  total_segundos: 666     // Computed
}

// Registrar una escucha: una sola operación atómica
db.escuchas_por_dia.updateOne(
  { _id: "u3_2026-11-17" },
  {
    $push: { escuchas: { cancion_id: 9, hora: ISODate("2026-11-17T23:40:00Z"), segundos: 90 } },
    $inc:  { total_escuchas: 1, total_segundos: 90 },
    $setOnInsert: { usuario_id: "u3", dia: ISODate("2026-11-17T00:00:00Z") }
  },
  { upsert: true }
);
```

**Por qué así.**

| Decisión | Motivo |
|---|---|
| Un documento por usuario **y día** | El arreglo queda acotado (nadie escucha millones de canciones en un día) y lejos del límite de 16 MB por documento |
| `_id` con usuario y día | El `upsert` encuentra o crea el documento del día sin consultar antes |
| `total_escuchas` y `total_segundos` | Los reportes diarios leen dos números en lugar de recorrer el arreglo |
| `$push` + `$inc` en el mismo `updateOne` | Se actualizan juntos de forma atómica: los totales nunca quedan desfasados del arreglo |

Lo que **no** se debe hacer es embeber todas las escuchas dentro del documento del usuario: sería un arreglo sin límite que crece con cada canción (anti-patrón *unbounded array*) y cada lectura del perfil traería todo el historial.

## Resumen de índices de la práctica

```javascript
db.escuchas.getIndexes();
db.playlists.getIndexes();
db.canciones.getIndexes();
db.sesiones.getIndexes();
```

| Colección | Índice | Tipo | Para qué |
|---|---|---|---|
| `escuchas` | `{ usuario_id: 1, fecha: -1 }` | Compuesto | Historial de un usuario |
| `playlists` | `{ usuario_id: 1, nombre: 1 }` | Único compuesto | Nombres sin repetir por usuario |
| `canciones` | `{ titulo: "text" }` | Texto | Buscador |
| `canciones` | `{ reproducciones: -1 }` | Parcial | Sección “Populares” |
| `sesiones` | `{ ultima_actividad: 1 }` | TTL | Borrado automático |
