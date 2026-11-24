---
title: FitZone - Fase 2, implementación
description: Dos máquinas virtuales con Ubuntu Server, PostgreSQL 16 con lógica en PL/pgSQL, MongoDB 8.0 y aplicación web con Spring Boot y Angular.
date: 2026-11-12
---

## Arquitectura

Tres capas en dos máquinas virtuales:

| Capa | Tecnología |
|---|---|
| Frontend | Angular, con pantallas por rol |
| Backend | Spring Boot: API REST con JWT y JDBC directo, sin ORM |
| VM 1 · 192.168.56.13 | PostgreSQL 16, datos del negocio y lógica en PL/pgSQL |
| VM 2 · 192.168.56.14 | MongoDB 8.0, rutinas y progreso físico |

## Decisiones técnicas

| Componente | Elección | Por qué |
|---|---|---|
| Sistema operativo | Ubuntu Server 24.04 LTS | Soporta MongoDB 8, trae PostgreSQL 16 en su repositorio y tiene seguridad hasta 2029 |
| Motor relacional | PostgreSQL 16 | Primero en la matriz de decisión: gratis, licencia permisiva, PL/pgSQL y soporte hasta 2028 |
| Motor NoSQL | MongoDB 8.0 | Modelo documental flexible para datos de estructura variable |
| Aplicación | Spring Boot + Angular | Sin ORM: el backend llama procedimientos y vistas de la base |

## Máquinas virtuales

Las dos VMs se crearon en **VirtualBox 7** con 2 vCPU, 2 GB de RAM y 20 GB de disco cada una. Tienen dos adaptadores de red: NAT para descargar paquetes y una red **solo-anfitrión** con IP fija, para que las bases no queden expuestas a la red de la universidad.

- Cortafuegos **UFW**: solo se abren SSH (22) y el puerto del motor (5432 o 27017), este último solo para la red solo-anfitrión.
- Zona horaria **America/Bogota**, porque los triggers usan la fecha actual para validar sesiones, inscripciones y mantenimientos.
- Al final, las dos VMs se exportaron juntas a un archivo **OVA** y se importaron en otro equipo como clones idénticos.

## PostgreSQL (VM 1)

| Script | Qué crea |
|---|---|
| `01_creacion.sql` | Tablas, secuencias, índices, el usuario `fitzone_app`, los 4 roles de cargo y sus permisos |
| `02_insercion_datos.sql` | Datos de prueba: sedes, empleados, miembros, membresías, pagos, clases, sesiones y equipos |
| `03_logica_negocio.sql` | Tabla de auditoría, funciones, triggers, procedimientos almacenados y vistas |
| `04_pruebas_logica.sql` | Pruebas de la lógica de negocio; todo se deshace con `ROLLBACK` |

Lógica principal en PL/pgSQL:

- `fn_validar_inscripcion`: función de un trigger que valida que la membresía esté activa y que haya cupo en la sesión.
- `sp_renovar_membresia` y `sp_registrar_inscripcion`: procedimientos con control de transacciones y manejo de excepciones.
- `fn_porcentaje_asistencia`: calcula el porcentaje de asistencia de un miembro.

**Seguridad por cargo:** la aplicación se conecta con `fitzone_app`, que no tiene permisos propios, y activa uno de cuatro roles con `SET ROLE` (`rol_admin_sistema`, `rol_gerente_sede`, `rol_recepcionista_sede` o `rol_entrenador_sede`). Así cada operación queda limitada a lo que permite ese cargo.

## MongoDB (VM 2)

Base `fitzone_nosql` con las colecciones `rutinas_entrenamiento` y `progreso_fisico`, con autenticación activada y un rol de la aplicación (`fitzone_app_rw`) que solo puede consultar, insertar, actualizar y borrar documentos en esas dos colecciones. El modelo está en la sección **No SQL** del portafolio.

## Aplicación web

- Inicio de sesión con roles distintos.
- Registro de miembros y renovación de membresía con pago.
- Inscripción a sesiones con control de cupo: la base rechaza a un miembro sin membresía vigente o una sesión llena.
- Creación de rutinas en MongoDB y reportes.
- Consulta de la auditoría como administrador.

## Repositorio

[github.com/camy0414/Project_FitZone](https://github.com/camy0414/Project_FitZone): carpetas `BACKEND`, `FRONTEND` y `ScriptsBasesDeDatos`.
