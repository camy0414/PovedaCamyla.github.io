---
title: "Práctica MongoDB 2: Agregaciones"
description: Pipelines sobre la plataforma de música con $group, $unwind, $lookup simple y con pipeline, $dateToString, $bucket, $facet y $merge.
date: 2026-11-23T12:02:00
---

Segunda práctica propia sobre la **plataforma de música** de la [práctica 1](/PovedaCamyla.github.io/recipes/practica-mongo-1-crud-arreglos). Antes de empezar, vuelva a cargar el <a href="/PovedaCamyla.github.io/evidencias/practicas/musica_dataset.js" download>script de datos</a> para partir de los documentos originales.

Un *pipeline* es una lista de etapas: cada una recibe los documentos que deja la anterior. La regla práctica es **filtrar y reducir lo antes posible** (`$match`, `$project`, `$limit`) y unir (`$lookup`) lo más tarde posible.

## 2.1 Top 3 de artistas

**Enunciado.** Calcule por artista el total de reproducciones y el número de canciones, y muestre los 3 con más reproducciones.

```javascript
use('musica_practica');

db.canciones.aggregate([
  { $group: {
      _id: "$artista.nombre",
      reproducciones: { $sum: "$reproducciones" },
      canciones: { $sum: 1 }
  } },
  { $sort: { reproducciones: -1 } },
  { $limit: 3 },
  { $project: { _id: 0, artista: "$_id", reproducciones: 1, canciones: 1 } }
]);
```

**Resultado esperado:**

```javascript
{ reproducciones: 66250, canciones: 3, artista: "Neón Sur" }
{ reproducciones: 37100, canciones: 2, artista: "Lucía Ríos" }
{ reproducciones: 33000, canciones: 2, artista: "Marea Alta" }
```

**Por qué así.** Se agrupa por `artista.nombre` sin `$lookup` gracias a la copia del nombre en cada canción. `$sort` + `$limit` seguidos permiten a MongoDB guardar solo los 3 mejores mientras ordena, en vez de ordenar todo.

## 2.2 Estadísticas por género

**Enunciado.** Para cada género, calcule cuántas canciones tiene, el total de reproducciones y la duración promedio en segundos (sin decimales). Ordene por reproducciones.

```javascript
db.canciones.aggregate([
  { $unwind: "$generos" },
  { $group: {
      _id: "$generos",
      canciones: { $sum: 1 },
      reproducciones: { $sum: "$reproducciones" },
      duracion_prom: { $avg: "$duracion_seg" }
  } },
  { $project: { canciones: 1, reproducciones: 1, duracion_prom: { $round: ["$duracion_prom", 0] } } },
  { $sort: { reproducciones: -1 } }
]);
```

**Resultado esperado:**

| _id | canciones | reproducciones | duracion_prom |
|---|---|---|---|
| pop | 3 | 71550 | 185 |
| electrónica | 3 | 67900 | 222 |
| folk | 2 | 37100 | 240 |
| cumbia | 2 | 33000 | 246 |
| rock | 2 | 24100 | 222 |
| alternativo | 2 | 13000 | 255 |
| jazz | 2 | 5400 | 384 |

**Por qué así.** `$unwind` convierte una canción con dos géneros en dos documentos, uno por género, para poder agrupar por cada uno. Por eso la suma de la columna `canciones` (16) es mayor que el total de canciones (12): las de dos géneros cuentan en ambos.

## 2.3 Tiempo de escucha por usuario con $lookup

**Enunciado.** Para cada usuario, calcule cuántas escuchas tiene (sin contar saltos de 30 segundos o menos), los minutos totales escuchados y el porcentaje de escuchas **completas** (al menos el 90 % de la canción). Muestre el nombre del usuario.

```javascript
db.escuchas.aggregate([
  { $match: { segundos: { $gt: 30 } } },
  { $lookup: { from: "canciones", localField: "cancion_id", foreignField: "_id", as: "cancion" } },
  { $unwind: "$cancion" },
  { $group: {
      _id: "$usuario_id",
      escuchas: { $sum: 1 },
      segundos: { $sum: "$segundos" },
      completas: { $sum: {
        $cond: [ { $gte: ["$segundos", { $multiply: ["$cancion.duracion_seg", 0.9] }] }, 1, 0 ]
      } }
  } },
  { $lookup: { from: "usuarios", localField: "_id", foreignField: "_id", as: "usuario" } },
  { $project: {
      _id: 0,
      usuario: { $first: "$usuario.nombre" },
      escuchas: 1,
      minutos: { $round: [{ $divide: ["$segundos", 60] }, 1] },
      pct_completas: { $round: [{ $multiply: [{ $divide: ["$completas", "$escuchas"] }, 100] }, 1] }
  } },
  { $sort: { minutos: -1 } }
]);
```

**Resultado esperado:**

| usuario | escuchas | minutos | pct_completas |
|---|---|---|---|
| Isabela | 5 | 19.4 | 80 |
| Tomás | 3 | 18 | 100 |
| Valentina | 5 | 15.7 | 80 |
| Mateo | 4 | 10.9 | 50 |
| Daniela | 2 | 6.5 | 100 |

**Por qué así.** El `$match` va primero para que el `$lookup` no trabaje con escuchas que se van a descartar. Hay dos `$lookup`: el primero por cada escucha (necesita la duración de la canción) y el segundo **después** del `$group`, cuando ya solo quedan 5 documentos, uno por usuario. `$cond` funciona como un `CASE` de SQL dentro de la suma. `$lookup` siempre devuelve un arreglo; `$first` (o `$unwind`) lo convierte en un valor.

## 2.4 Actividad diaria

**Enunciado.** Cuente las escuchas por día (en UTC) y cuántos usuarios distintos escucharon música ese día.

```javascript
db.escuchas.aggregate([
  { $group: {
      _id: { $dateToString: { format: "%Y-%m-%d", date: "$fecha" } },
      escuchas: { $sum: 1 },
      usuarios: { $addToSet: "$usuario_id" }
  } },
  { $project: { escuchas: 1, usuarios_distintos: { $size: "$usuarios" } } },
  { $sort: { _id: 1 } }
]);
```

**Resultado esperado:**

| _id | escuchas | usuarios_distintos |
|---|---|---|
| 2026-11-16 | 4 | 2 |
| 2026-11-17 | 5 | 2 |
| 2026-11-18 | 4 | 2 |
| 2026-11-19 | 4 | 2 |
| 2026-11-20 | 3 | 3 |

**Por qué así.** `$addToSet` junta los usuarios sin repetir y `$size` los cuenta: es el equivalente a `COUNT(DISTINCT usuario_id)`. Las fechas se guardan en UTC; para reportar en hora de Colombia se agrega `timezone: "America/Bogota"` a `$dateToString`, y entonces la escucha del `2026-11-20T00:15Z` pasaría al día 19.

## 2.5 Canciones por rango de duración con $bucket

**Enunciado.** Agrupe las canciones en rangos de duración: menos de 3 minutos, de 3 a 4, de 4 a 5 y 5 o más, con la cantidad y los títulos de cada rango.

```javascript
db.canciones.aggregate([
  { $bucket: {
      groupBy: "$duracion_seg",
      boundaries: [0, 180, 240, 300],
      default: "300+",
      output: { cantidad: { $sum: 1 }, titulos: { $push: "$titulo" } }
  } }
]);
```

**Resultado esperado:**

```javascript
{ _id: 0,      cantidad: 1, titulos: ["Brillo"] }
{ _id: 180,    cantidad: 5, titulos: ["Ciudad de ladrillo", "Pulso digital", "Noche de neón", "Mar de papel", "Tambor del río"] }
{ _id: 240,    cantidad: 3, titulos: ["Niebla en la sabana", "Raíces", "Marea electrónica"] }
{ _id: "300+", cantidad: 3, titulos: ["Fuego lento", "Blue Nébula", "Lluvia en Valparaíso"] }
```

**Por qué así.** Cada límite inferior se incluye y el superior no: 240 s cae en el rango `240` y no en el `180`. Los valores que no entran en ningún rango van al `default`; sin él, una canción de más de 300 s haría fallar la agregación.

## 2.6 Página de catálogo con $facet

**Enunciado.** Con una sola consulta, arme lo que necesita la página del género pop: las 2 canciones más reproducidas, el conteo por año (para un filtro lateral) y el total de canciones.

```javascript
db.canciones.aggregate([
  { $match: { generos: "pop" } },
  { $facet: {
      top: [
        { $sort: { reproducciones: -1 } },
        { $limit: 2 },
        { $project: { _id: 0, titulo: 1, reproducciones: 1 } }
      ],
      por_anio: [
        { $group: { _id: "$anio", canciones: { $sum: 1 } } },
        { $sort: { _id: 1 } }
      ],
      total: [ { $count: "canciones" } ]
  } }
]);
```

**Resultado esperado:**

```javascript
{
  top: [ { titulo: "Noche de neón", reproducciones: 31500 },
         { titulo: "Mar de papel",  reproducciones: 27300 } ],
  por_anio: [ { _id: 2022, canciones: 2 }, { _id: 2024, canciones: 1 } ],
  total: [ { canciones: 3 } ]
}
```

**Por qué así.** `$facet` ejecuta varios sub-pipelines sobre **los mismos documentos** y devuelve un único documento con un arreglo por cada uno. Ahorra tres viajes a la base de datos. El `$match` va antes del `$facet` para que el filtro se haga una sola vez (y pueda usar un índice).

## 2.7 Recomendaciones con $lookup de pipeline

**Enunciado.** Recomiende a Isabela (`u1`, le gustan pop y folk) las canciones de sus géneros que **todavía no ha escuchado**, de la más a la menos popular.

```javascript
db.canciones.aggregate([
  { $match: { generos: { $in: ["pop", "folk"] } } },
  { $lookup: {
      from: "escuchas",
      let: { id: "$_id" },
      pipeline: [
        { $match: { $expr: { $and: [
            { $eq: ["$cancion_id", "$$id"] },
            { $eq: ["$usuario_id", "u1"] }
        ] } } },
        { $limit: 1 }
      ],
      as: "mis_escuchas"
  } },
  { $match: { mis_escuchas: { $size: 0 } } },
  { $sort: { reproducciones: -1 } },
  { $project: { _id: 0, titulo: 1, "artista.nombre": 1, reproducciones: 1 } }
]);
```

**Resultado esperado:**

```javascript
{ titulo: "Noche de neón", artista: { nombre: "Neón Sur" }, reproducciones: 31500 }
{ titulo: "Brillo",        artista: { nombre: "Neón Sur" }, reproducciones: 12750 }
```

**Por qué así.** El `$lookup` con `let` y `pipeline` permite unir con condiciones que no son una simple igualdad de campos (aquí, la canción **y** el usuario). Las variables del documento externo se leen con `$$`. Es el equivalente a un `NOT EXISTS` de SQL: se buscan las escuchas propias y se quedan las canciones con el arreglo vacío. El `$limit: 1` dentro del sub-pipeline basta, porque solo importa si hay al menos una. *Raíces* y *Mar de papel* no aparecen porque Isabela ya las escuchó.

## 2.8 Guardar un resumen con $merge

**Enunciado.** Guarde en la colección `resumen_artistas` el total de reproducciones de cada artista, de forma que al volver a ejecutar se **actualicen** los documentos en lugar de duplicarse.

```javascript
db.canciones.aggregate([
  { $group: { _id: "$artista._id", artista: { $first: "$artista.nombre" },
              reproducciones: { $sum: "$reproducciones" } } },
  { $set: { actualizado: "$$NOW" } },
  { $merge: { into: "resumen_artistas", on: "_id",
              whenMatched: "replace", whenNotMatched: "insert" } }
]);

db.resumen_artistas.find().sort({ reproducciones: -1 });
```

**Por qué así.** `$out` reemplaza la colección destino completa; `$merge` combina documento por documento: si el artista ya existe lo reemplaza y si no, lo inserta. Sirve para mantener una vista materializada que se refresca periódicamente sin borrar lo que no cambió. `$$NOW` es la hora del servidor al ejecutar el pipeline.
