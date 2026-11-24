---
title: FitZone - Fase 1, modelado y diseño
description: Problema, solución propuesta, modelo entidad-relación y modelo relacional normalizado a 3FN.
date: 2026-10-12
---

## El problema

FitZone es una cadena de gimnasios con varias sedes en la misma ciudad. Cada sede manejaba membresías, clases, entrenadores y pagos en hojas de cálculo separadas, lo que causaba:

- Datos de miembros duplicados e inconsistentes entre sedes.
- Errores en los cobros y ningún control de vencimientos ni mora.
- No saber en tiempo real cuánto cupo queda en cada clase.
- Ningún histórico central de rutinas ni de progreso físico.
- Ninguna trazabilidad del mantenimiento de los equipos.

## La solución

Un solo sistema web para toda la cadena, con las reglas del negocio dentro de la base de datos:

- **PostgreSQL:** sedes, miembros, membresías, pagos, clases y equipos, con reglas en procedimientos y triggers.
- **MongoDB:** rutinas de entrenamiento y progreso físico, datos que cambian de forma y crecen sin parar.
- **Aplicación web:** Angular y Spring Boot, con pantallas según el rol del empleado.

Trabajo en grupo con Sebastián Pérez Herrera y Jhonatan Camilo Lozano Buitrago.

## Modelo de datos

| Dato | Valor |
|---|---|
| Entidades | 14 |
| Relaciones | 15 |
| Normalización | Tercera forma normal |
| Entidades débiles | 3: Info médica, Sesión y Mantenimiento de equipo |

El modelo se hizo primero en notación **Peter Chen** y luego se pasó a modelo relacional en **Oracle Data Modeler**. Cumple los tres tipos de relación que pide el proyecto:

| Tipo | Dónde aparece |
|---|---|
| 1:1 | Miembro – Info médica (opcional, máximo una por miembro) |
| 1:N | Sede – Miembro, Rol – Empleado, Clase – Sesión, Equipo – Mantenimiento |
| N:M | Miembro – Sesión: la inscripción guarda la fecha y si el miembro asistió |

Dos decisiones de diseño importantes:

- El **entrenador** dejó de ser una entidad propia: ahora es un **empleado con rol de entrenador**, igual que el recepcionista o el gerente.
- Los valores de texto libre (tipo de equipo, plan, método de pago) se pasaron a **tablas catálogo**, para evitar valores repetidos o inconsistentes.
