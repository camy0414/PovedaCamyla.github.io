---
title: "Parte 2: Índices y optimización"
description: Planes de ejecución antes y después, índice compuesto, funciones en el predicado e índice cubriente.
pubDate: 2026-10-12
---

En esta parte cada intervención se documenta con el **plan de ejecución antes y después**, señalando el costo estimado y los bloques leídos.

## Temas

- **Índice compuesto**: el orden de las columnas importa; la columna usada con igualdad va primero.
- **Función en el predicado**: algo como `WHERE TRUNC(fecha) = ...` o `UPPER(nombre) = ...` impide usar un índice normal sobre esa columna; se resuelve reescribiendo la condición o con un índice basado en función.
- **Casos donde el optimizador no usa un índice existente**: por baja selectividad, estadísticas desactualizadas o conversiones implícitas de tipo.
- **Índice cubriente**: contiene todas las columnas que la consulta necesita, así que no hace falta leer la tabla.
- **Lista definitiva de índices**: `TRANSFERENCIA` tiene dos claves foráneas hacia `CUENTA` (origen y destino), por lo que ambas deben considerarse.

## Evidencia

### Plan de ejecución antes

```sql
-- Pega aquí la consulta y la captura del plan
```

### Plan de ejecución después

```sql
-- Pega aquí el índice creado y la captura del nuevo plan
```

### Lista definitiva de índices

```sql
-- Pega aquí los CREATE INDEX finales
```

## Aprendizajes

- Escribe aquí qué cambió entre el plan antes y el plan después.
