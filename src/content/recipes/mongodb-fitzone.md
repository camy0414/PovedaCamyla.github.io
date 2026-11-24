---
title: MongoDB en FitZone
description: Modelo documental para rutinas de entrenamiento y seguimiento de progreso físico.
date: 2026-11-12
---

En el proyecto final (**FitZone**, una cadena de gimnasios) la información se reparte entre dos bases de datos: lo transaccional va en **PostgreSQL** y lo flexible va en **MongoDB 8.0**, en la base `fitzone_nosql`.

## ¿Por qué estos datos van en MongoDB?

Cada miembro tiene rutinas y mediciones distintas, y crecen sin parar. Una rutina de fuerza tiene series, repeticiones y peso; una de cardio tiene duración y distancia. Esa forma variable no encaja bien en tablas.

## Colecciones

### rutinas_entrenamiento

Patrones **embebido** y **polimórfico**: los ejercicios van dentro de la rutina porque siempre se leen juntos, y cada tipo de ejercicio tiene sus propios campos (por eso casi todos son opcionales).

```javascript
{
  _id: ObjectId,
  id_miembro: Number,       // apunta a PostgreSQL
  id_empleado: Number,      // entrenador, en PostgreSQL
  id_sede: Number,          // en PostgreSQL
  nombre_rutina: String,
  objetivo: String,
  fecha_creacion: Date,
  activa: Boolean,
  notas_entrenador: String, // opcional
  ejercicios: [{
    nombre: String,
    tipo: String,           // fuerza, cardio o movilidad
    series: Number,         // fuerza y movilidad
    repeticiones: Number,   // fuerza
    peso_kg: Number,        // fuerza
    duracion_min: Number,   // cardio
    distancia_km: Number,   // cardio
    duracion_seg: Number,   // movilidad
    notas: String,
    video_url: String
  }]
}
```

### progreso_fisico

Patrón **referencia**: cada medición es un documento propio que apunta al miembro, porque un miembro acumula mediciones sin límite. Las medidas van embebidas.

```javascript
{
  _id: ObjectId,
  id_miembro: Number,       // apunta a PostgreSQL
  id_sede: Number,
  registrado_por: Number,   // empleado, en PostgreSQL
  fecha: Date,
  peso_kg: Number,
  grasa_corporal_pct: Number,
  medidas: { cintura_cm: Number, pecho_cm: Number, brazo_cm: Number, cadera_cm: Number },
  notas: String             // opcional
}
```

MongoDB solo guarda los ids de miembro, empleado y sede; los nombres se traen de PostgreSQL.

## Índices

| Colección | Índices |
|---|---|
| `rutinas_entrenamiento` | `{ id_miembro, activa }`, `id_sede`, `ejercicios.tipo` |
| `progreso_fisico` | `{ id_miembro, fecha }`, `id_sede` |

## Qué hace la aplicación con MongoDB

- CRUD de rutinas: crear, consultar, actualizar y desactivar.
- Registro de mediciones de progreso físico.
- Reporte de los ejercicios más asignados en rutinas activas.
- Reporte de rutinas activas e inactivas por entrenador (el nombre sale de PostgreSQL).

## Seguridad

La autenticación está activada. La aplicación usa su propio usuario con el rol `fitzone_app_rw`, que solo permite `find`, `insert`, `update` y `remove` sobre las dos colecciones: no puede borrar colecciones, crear otras ni ver usuarios.

Los scripts (`01.CreacionMG.js` y `02.InsercionMG.js`) están en la carpeta `ScriptsBasesDeDatos` del [repositorio del proyecto](https://github.com/camy0414/Project_FitZone).
