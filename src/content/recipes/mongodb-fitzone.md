---
title: MongoDB en FitZone
description: Modelo documental para rutinas de entrenamiento y seguimiento de progreso físico.
---

En el proyecto final (sistema para una cadena de gimnasios llamada **FitZone**) la información se reparte entre dos bases de datos: lo transaccional va en **PostgreSQL** y lo flexible y cambiante va en **MongoDB**.

## ¿Por qué estos datos van en MongoDB?

Las rutinas de entrenamiento y las mediciones de progreso físico no tienen una estructura fija: cada rutina tiene un número distinto de ejercicios y cada miembro registra mediciones diferentes con el tiempo. Un documento anidado representa eso de forma natural, sin tablas intermedias ni columnas vacías.

## Colecciones

- `rutinas_entrenamiento`: rutinas asignadas a los miembros, con sus ejercicios.
- `progreso_fisico`: mediciones y avances de cada miembro a lo largo del tiempo.

Ambas se crean con validación de esquema (`$jsonSchema`).

## Creación de colecciones

```javascript
// Pega aquí el script de creación con $jsonSchema
```

## Inserción de datos

```javascript
// Pega aquí el script de inserción
```

## CRUD

```javascript
// Pega aquí los ejemplos de insertar, consultar, actualizar y eliminar
```

## Consultas complejas y agregaciones

```javascript
// Pega aquí los pipelines de agregación
```
