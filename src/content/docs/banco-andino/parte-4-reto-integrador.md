---
title: "Parte 4: Reto integrador"
description: Corrección de una secuencia del core bancario con atomicidad, sin saldos negativos y sin interbloqueos.
pubDate: 2026-10-12
---

El reto consiste en revisar la secuencia de operaciones del core bancario, identificar **cuatro defectos** y reescribirla correctamente.

## Defectos a identificar

1. Un defecto de **concurrencia**.
2. Un defecto de **transaccionalidad**.
3. Un defecto que **oculta el problema**.
4. Un defecto de **rendimiento**.

## Requisitos de la versión corregida

- Escrita en **SQL puro**.
- **Atomicidad**: o se aplica todo o no se aplica nada.
- **Sin saldo negativo** en ninguna cuenta.
- **Bloqueo en orden determinista** para evitar interbloqueos.
- Consulta del tablero optimizada.
- Un párrafo para la Gerencia de Operaciones explicando el cambio en lenguaje no técnico.

## Evidencia

### Secuencia original y defectos encontrados

```sql
-- Pega aquí la secuencia original y señala cada defecto
```

### Secuencia corregida

```sql
-- Pega aquí tu versión final
```

### Mensaje para Gerencia de Operaciones

> Escribe aquí tu párrafo.
