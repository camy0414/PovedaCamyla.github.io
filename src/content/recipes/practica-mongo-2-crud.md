---
title: "Práctica MongoDB 2: Insertar, actualizar y borrar"
description: Operaciones CRUD básicas en MongoDB Atlas sobre una colección propia.
date: 2026-11-23T12:02:00
---

Práctica propia en **MongoDB Atlas**. Para no modificar la base de ejemplo, se trabaja en una colección nueva llamada `mis_restaurantes`, dentro de `sample_restaurants`. MongoDB la crea sola con el primer insert.

### 1. Insertar un documento

```javascript
use('sample_restaurants');

db.mis_restaurantes.insertOne({
  nombre: "Sabor Bogotano",
  barrio: "Chapinero",
  tipo: "Colombiana",
  calificacion: 4
})
```

Devuelve `acknowledged: true` y el `_id` que MongoDB le asignó.

### 2. Insertar varios documentos

```javascript
db.mis_restaurantes.insertMany([
  { nombre: "La Arepa Feliz", barrio: "Usaquén",   tipo: "Colombiana", calificacion: 5 },
  { nombre: "Pizza Nostra",   barrio: "Chapinero", tipo: "Italiana",   calificacion: 3 },
  { nombre: "Dragón Rojo",    barrio: "Suba",      tipo: "China",      calificacion: 4 }
])
```

### 3. Consultar lo insertado

```javascript
db.mis_restaurantes.find()
db.mis_restaurantes.find({ tipo: "Colombiana" })
```

### 4. Actualizar uno con $set

```javascript
db.mis_restaurantes.updateOne(
  { nombre: "Pizza Nostra" },
  { $set: { calificacion: 4 } }
)
```

Cambia la calificación de un solo restaurante. Devuelve `matchedCount: 1` y `modifiedCount: 1`.

### 5. Actualizar varios con $inc

```javascript
db.mis_restaurantes.updateMany(
  { barrio: "Chapinero" },
  { $inc: { calificacion: 1 } }
)
```

Suma 1 a la calificación de todos los restaurantes de Chapinero.

### 6. Agregar un campo nuevo

```javascript
db.mis_restaurantes.updateMany(
  {},
  { $set: { activo: true } }
)
```

El filtro vacío `{}` aplica el cambio a todos los documentos.

### 7. Insertar o actualizar (upsert)

```javascript
db.mis_restaurantes.updateOne(
  { nombre: "Café del Parque" },
  { $set: { barrio: "Teusaquillo", tipo: "Café", calificacion: 4 } },
  { upsert: true }
)
```

Si el restaurante no existe, lo crea. Si ya existe, lo actualiza.

### 8. Borrar uno

```javascript
db.mis_restaurantes.deleteOne({ nombre: "Dragón Rojo" })
```

### 9. Borrar varios

```javascript
db.mis_restaurantes.deleteMany({ calificacion: { $lt: 4 } })
```

Borra los restaurantes con calificación menor a 4.

### 10. Limpieza

```javascript
db.mis_restaurantes.drop()
```

Elimina la colección de práctica completa.
