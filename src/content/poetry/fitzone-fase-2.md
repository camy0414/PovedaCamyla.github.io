---
title: FitZone - Fase 2, implementación
description: PostgreSQL 16 sobre Ubuntu Server, scripts SQL y PL/pgSQL, MongoDB y aplicación web con Spring Boot.
date: 2026-10-12
---

## Decisiones técnicas

- **Sistema operativo:** Ubuntu Server 24.04 LTS.
- **Base de datos relacional:** PostgreSQL 16, elegida tras un análisis comparativo con matriz ponderada.
- **Base de datos documental:** MongoDB.
- **Aplicación web:** Java con Spring Boot, con acceso a la base de datos relacional por JDBC, sin JPA.

## Scripts SQL (PostgreSQL)

Tres scripts: creación de las 14 tablas, inserción de datos de ejemplo y un tercero con el resto de objetos.

### Lógica en la base de datos (PL/pgSQL)

- `fn_validar_inscripcion`: función de un trigger que valida que la membresía esté activa y que haya cupo en la sesión.
- `sp_renovar_membresia` y `sp_registrar_inscripcion`: procedimientos con control de transacciones y manejo de excepciones.
- `fn_porcentaje_asistencia`: función que calcula el porcentaje de asistencia de un miembro.

```sql
-- Pega aquí el trigger y las funciones
```

```sql
-- Pega aquí los procedimientos almacenados
```

## MongoDB

Ver la sección **No SQL** del portafolio.

## Aplicación web

La aplicación se conecta a PostgreSQL y a MongoDB. Incluye CRUD completo de sedes, restringido al rol administrador.

<!-- Agrega aquí capturas de pantalla de la aplicación -->

## Repositorio y video

- Repositorio: agrega aquí el enlace.
- Video demostrativo: agrega aquí el enlace.
