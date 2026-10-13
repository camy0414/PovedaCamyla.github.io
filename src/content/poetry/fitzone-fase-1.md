---
title: FitZone - Fase 1, modelado y diseño
description: Propuesta, supuestos, modelos entidad-relación, modelo relacional, diccionario de datos y reportes SQL.
date: 2026-10-12
---

## El proyecto

Sistema de información web para una **cadena de gimnasios (FitZone)**: membresías, clases, entrenadores y pagos en una base de datos relacional, y rutinas de entrenamiento y progreso físico en MongoDB. Se desarrolla en un grupo de 3 estudiantes.

## Entregables de la Fase 1

- Documento de propuesta
- Documento de supuestos (una sección por entidad)
- Modelo entidad-relación (Peter Chen)
- Modelo entidad-relación y modelo relacional con notación Crow's Foot
- Diccionario de datos
- Documento de reportes SQL

## Modelo relacional final

El modelo quedó en **14 tablas**, normalizado hasta **tercera forma normal**:

`sede`, `miembro`, `info_medica`, `membresia`, `tipo_plan`, `pago`, `metodo_pago`, `entrenador`, `clase`, `sesion`, `inscribir`, `equipo`, `tipo_equipo` y `mantenimiento_equipo`.

Una decisión de diseño importante fue pasar los valores de texto libre (como el tipo de equipo, el plan o el método de pago) a **tablas catálogo**, para evitar valores repetidos o inconsistentes.

## Diagramas

<!-- Sube las imágenes a src/assets/proyecto/ y descomenta las líneas de abajo
![Modelo relacional en Crow's Foot](../../assets/proyecto/modelo-relacional.png)
-->

Agrega aquí las imágenes de tus diagramas.
