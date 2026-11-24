---
title: "Práctica MongoDB 3: Agregaciones básicas"
description: Uso de aggregate con $match, $group, $sort, $limit, $project y $count sobre sample_restaurants de MongoDB Atlas.
date: 2026-11-23T12:01:00
---

Práctica propia en **MongoDB Atlas** con la base de ejemplo `sample_restaurants`. Una agregación es una lista de pasos: cada paso recibe el resultado del anterior.

| Paso | Para qué sirve | En SQL sería |
|---|---|---|
| `$match` | Filtrar | `WHERE` |
| `$group` | Agrupar y contar o sumar | `GROUP BY` |
| `$sort` | Ordenar | `ORDER BY` |
| `$limit` | Quedarse con los primeros | `FETCH FIRST` |
| `$project` | Escoger los campos a mostrar | `SELECT` |
| `$count` | Contar | `COUNT(*)` |

### 1. Contar con $match y $count

```javascript
use('sample_restaurants');

db.restaurants.aggregate([
  { $match: { cuisine: "Pizza" } },
  { $count: "total_pizzerias" }
])
```

Cuántas pizzerías hay en total.

### 2. Restaurantes por barrio

```javascript
db.restaurants.aggregate([
  { $group: { _id: "$borough", cantidad: { $sum: 1 } } }
])
```

Agrupa por barrio y cuenta cuántos restaurantes hay en cada uno. `$sum: 1` suma 1 por cada documento.

### 3. Agrupar y ordenar

```javascript
db.restaurants.aggregate([
  { $group: { _id: "$borough", cantidad: { $sum: 1 } } },
  { $sort: { cantidad: -1 } }
])
```

Lo mismo, pero del barrio con más restaurantes al que tiene menos.

### 4. Top 5 de tipos de comida

```javascript
db.restaurants.aggregate([
  { $group: { _id: "$cuisine", cantidad: { $sum: 1 } } },
  { $sort: { cantidad: -1 } },
  { $limit: 5 }
])
```

Los 5 tipos de comida con más restaurantes.

### 5. Filtrar antes de agrupar

```javascript
db.restaurants.aggregate([
  { $match: { borough: "Brooklyn" } },
  { $group: { _id: "$cuisine", cantidad: { $sum: 1 } } },
  { $sort: { cantidad: -1 } },
  { $limit: 5 }
])
```

Los 5 tipos de comida más comunes, pero solo en Brooklyn. El `$match` va primero para trabajar con menos datos.

### 6. Cambiar los nombres de los campos con $project

```javascript
db.restaurants.aggregate([
  { $group: { _id: "$borough", cantidad: { $sum: 1 } } },
  { $project: { _id: 0, barrio: "$_id", cantidad: 1 } }
])
```

El resultado muestra `barrio` en lugar de `_id`.

### 7. Promedio de puntaje por barrio

```javascript
db.restaurants.aggregate([
  { $unwind: "$grades" },
  { $group: { _id: "$borough", puntaje_promedio: { $avg: "$grades.score" } } },
  { $sort: { puntaje_promedio: 1 } }
])
```

`$unwind` separa el arreglo `grades` para tener una calificación por documento, y luego `$avg` calcula el promedio por barrio. En estas inspecciones, un puntaje más bajo es mejor.

### 8. Un índice para buscar más rápido

```javascript
db.restaurants.createIndex({ cuisine: 1 })

db.restaurants.find({ cuisine: "Italian" }).explain("executionStats")
```

Con el índice, el `explain` muestra `IXSCAN` (usa el índice) en lugar de `COLLSCAN` (revisa toda la colección). Al terminar se puede borrar:

```javascript
db.restaurants.dropIndex("cuisine_1")
```
