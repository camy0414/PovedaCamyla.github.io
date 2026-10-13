---
title: "Parte 1: Transacciones y concurrencia"
description: Actualización perdida, bloqueo pesimista y optimista, SKIP LOCKED, claves foráneas sin índice e interbloqueos.
pubDate: 2026-10-12
---

Esta parte se trabaja con **dos conexiones simultáneas** (sesión A y sesión B) para provocar y observar los problemas de concurrencia en vivo.

## Temas

- **Actualización perdida** (*lost update*): dos sesiones leen el mismo saldo, ambas lo modifican y la última en confirmar pisa el cambio de la primera.
- **Bloqueo pesimista**: `SELECT ... FOR UPDATE` toma el bloqueo de la fila antes de modificarla; la otra sesión espera.
- **Bloqueo optimista**: no se bloquea al leer; se agrega una columna de versión y el `UPDATE` solo procede si la versión no cambió.
- **`SKIP LOCKED`**: útil para colas de trabajo (como la cola de compensación interbancaria), porque cada proceso toma filas distintas sin esperar a los demás.
- **Claves foráneas sin índice**: en Oracle, una FK sin índice en la tabla hija puede generar bloqueos más amplios al actualizar o borrar en la tabla padre.
- **Interbloqueo** (*deadlock*): dos sesiones se esperan mutuamente (ORA-00060); se previene bloqueando siempre en el mismo orden.

## Evidencia

### Actualización perdida

```sql
-- Pega aquí el script de la sesión A y de la sesión B
```

### Bloqueo pesimista y optimista

```sql
-- Pega aquí tus consultas
```

### Interbloqueo

```sql
-- Pega aquí la secuencia que lo provoca y la corrección
```

## Aprendizajes

- Escribe aquí en 2 o 3 líneas qué te llevas de esta parte.
