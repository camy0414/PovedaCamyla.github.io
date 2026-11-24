---
title: "Práctica MongoDB 1: Consultas con find"
description: Consultas básicas sobre la base de ejemplo sample_restaurants de MongoDB Atlas.
date: 2026-11-23T12:03:00
---

Práctica propia en **MongoDB Atlas** con la base de ejemplo `sample_restaurants`, que trae restaurantes de Nueva York. Cada restaurante tiene nombre (`name`), barrio (`borough`), tipo de comida (`cuisine`), dirección (`address`) y sus calificaciones (`grades`).

### 1. Ver algunos restaurantes

```javascript
use('sample_restaurants');

db.restaurants.find().limit(5)
```

Muestra los primeros 5 restaurantes para conocer cómo son los documentos.

### 2. Buscar uno solo

```javascript
db.restaurants.findOne({ borough: "Queens" })
```

`findOne` devuelve solo el primer restaurante que cumple el filtro.

### 3. Filtrar por un campo

```javascript
db.restaurants.find({ cuisine: "Italian" })
```

Restaurantes de comida italiana.

### 4. Filtrar por dos campos

```javascript
db.restaurants.find({ cuisine: "Italian", borough: "Brooklyn" })
```

Restaurantes italianos que además están en Brooklyn. Separar las condiciones con coma equivale a un `AND`.

### 5. Mostrar solo algunos campos

```javascript
db.restaurants.find(
  { cuisine: "Italian", borough: "Brooklyn" },
  { _id: 0, name: 1, borough: 1 }
)
```

El segundo objeto es la **proyección**: `1` muestra el campo y `0` lo oculta.

### 6. Varios valores posibles con $in

```javascript
db.restaurants.find(
  { cuisine: { $in: ["Chinese", "Mexican"] } },
  { _id: 0, name: 1, cuisine: 1 }
)
```

Restaurantes de comida china **o** mexicana.

### 7. Distinto de con $ne

```javascript
db.restaurants.find(
  { borough: "Manhattan", cuisine: { $ne: "Pizza" } },
  { _id: 0, name: 1, cuisine: 1 }
)
```

Restaurantes de Manhattan que **no** son de pizza.

### 8. Ordenar y limitar

```javascript
db.restaurants.find(
  { borough: "Bronx" },
  { _id: 0, name: 1 }
).sort({ name: 1 }).limit(10)
```

Los 10 primeros restaurantes del Bronx en orden alfabético. `1` ordena de la A a la Z y `-1` al revés.

### 9. Contar

```javascript
db.restaurants.countDocuments({ borough: "Staten Island" })
```

Cuántos restaurantes hay en Staten Island.

### 10. Buscar dentro de un arreglo

```javascript
db.restaurants.find(
  { "grades.grade": "C" },
  { _id: 0, name: 1, grades: 1 }
).limit(5)
```

`grades` es un arreglo de calificaciones. Con `"grades.grade": "C"` se buscan los restaurantes que tengan **alguna** calificación C.

### 11. Buscar por parte del nombre

```javascript
db.restaurants.find(
  { name: /pizza/i },
  { _id: 0, name: 1 }
).limit(10)
```

Restaurantes cuyo nombre contiene la palabra "pizza". La `i` hace que no importen las mayúsculas.
