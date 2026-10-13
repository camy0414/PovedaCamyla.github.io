---
title: Taller PL/SQL - Inventario y ventas
description: Procedimientos, funciones, cursores, excepciones, disparadores y un caso integrador sobre una distribuidora ferretera en Oracle 19c.
date: 2026-10-12
categories: [PL/SQL]
tags: [Oracle, PL/SQL, Bases de Datos 2]
---

Taller de **Bases de Datos 2** (Universidad El Bosque) trabajado en grupos de 3 sobre **Oracle Database 19c**.

## El modelo

Una distribuidora ferretera con varias bodegas. Las tablas son `CATEGORIA`, `BODEGA`, `PRODUCTO`, `CLIENTE`, `EXISTENCIA`, `PEDIDO`, `DETALLE_PEDIDO`, `MOVIMIENTO_INVENTARIO`, `AUDITORIA_PRECIO` y `LOG_ERRORES`, además de la vista `V_STOCK_CONSOLIDADO`.

## Partes del taller

### 1. Procedimientos

```sql
-- Pega aquí tus procedimientos almacenados
```

### 2. Funciones

```sql
-- Pega aquí tus funciones
```

### 3. Cursores

```sql
-- Pega aquí tus bloques con cursores
```

### 4. Excepciones

```sql
-- Pega aquí el manejo de excepciones y el registro en LOG_ERRORES
```

### 5. Disparadores

```sql
-- Pega aquí tus triggers (por ejemplo, el de AUDITORIA_PRECIO)
```

### 6. Caso integrador

El cierre del taller integra todo lo anterior en `PKG_VENTAS.SP_FACTURAR_PEDIDO`: facturar un pedido descontando existencias, registrando el movimiento de inventario y manejando errores.

```sql
-- Pega aquí el paquete PKG_VENTAS
```

## Salida de ejecución

```text
-- Pega aquí la salida de DBMS_OUTPUT
```

## Aprendizajes

- Escribe aquí qué fue lo más útil de PL/SQL y qué te costó más.
