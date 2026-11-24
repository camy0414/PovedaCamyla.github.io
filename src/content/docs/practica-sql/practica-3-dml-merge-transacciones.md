---
title: "Práctica 3: DML, MERGE y transacciones"
description: UPDATE correlacionado, MERGE, vistas y control de transacciones con SAVEPOINT sobre el caso Biblioteca.
pubDate: 2026-11-23
---

Tercer bloque: modificar datos de forma segura. Cada ejercicio termina con una consulta de verificación.

Esquema y datos: ver [Práctica SQL: caso Biblioteca](/PovedaCamyla.github.io/docs/practica-sql).

## 3.1 Vista de préstamos activos

**Enunciado.** Cree la vista `v_prestamos_activos` con el préstamo, el socio, el libro, la fecha límite y el estado (`AL DIA` o `VENCIDO`) respecto a la fecha de corte.

```sql
CREATE OR REPLACE VIEW v_prestamos_activos AS
SELECT p.id_prestamo,
       s.nombre AS socio,
       l.titulo,
       p.fecha_limite,
       CASE WHEN p.fecha_limite < DATE '2026-11-20' THEN 'VENCIDO'
            ELSE 'AL DIA' END AS estado
FROM   prestamo p
JOIN   socio s    ON s.id_socio    = p.id_socio
JOIN   ejemplar e ON e.id_ejemplar = p.id_ejemplar
JOIN   libro l    ON l.id_libro    = e.id_libro
WHERE  p.fecha_devolucion IS NULL;

SELECT * FROM v_prestamos_activos ORDER BY fecha_limite;
```

**Resultado esperado:**

| id_prestamo | socio | titulo | fecha_limite | estado |
|---|---|---|---|---|
| 16 | Paula Herrera | Código limpio | 2026-11-13 | VENCIDO |
| 13 | Laura Méndez | Fundamentos de bases de datos | 2026-11-17 | VENCIDO |
| 17 | Diego Castillo | Redes de computadoras | 2026-11-19 | VENCIDO |
| 14 | Andrés Rojas | Fundamentos de bases de datos | 2026-11-24 | AL DIA |
| 15 | Carlos Duarte | Sistemas de bases de datos | 2026-11-27 | AL DIA |
| 18 | Julián Vargas | Cien años de soledad | 2026-11-29 | AL DIA |

**Por qué así.** La vista guarda la consulta, no los datos: cada vez que se consulta se recalcula. Como une cuatro tablas, no es actualizable directamente (Oracle no sabría a qué tabla aplicar un `UPDATE` de `socio`); para eso haría falta un disparador `INSTEAD OF`, como en el taller.

## 3.2 UPDATE con subconsulta correlacionada

**Enunciado.** Desactive (`activo = 'N'`) a los socios activos que tengan deuda pendiente mayor a 10.000 por multas no pagadas. Verifique el resultado y deshaga el cambio.

```sql
UPDATE socio s
SET    s.activo = 'N'
WHERE  s.activo = 'S'
AND    (SELECT NVL(SUM(m.valor), 0)
        FROM   multa m
        JOIN   prestamo p ON p.id_prestamo = m.id_prestamo
        WHERE  p.id_socio = s.id_socio
        AND    m.pagada   = 'N') > 10000;

SELECT id_socio, nombre, activo FROM socio WHERE activo = 'N' ORDER BY id_socio;

ROLLBACK;
```

**Resultado esperado:**

| id_socio | nombre | activo |
|---|---|---|
| 2 | Andrés Rojas | N |
| 3 | Paula Herrera | N |
| 7 | Sofía Pineda | N |

**Por qué así.** La subconsulta se ejecuta por cada fila candidata usando su `id_socio` (por eso es *correlacionada*). `NVL(..., 0)` cubre a los socios sin multas, para los que `SUM` devolvería `NULL`. Quedan desactivados Andrés Rojas (12.000) y Paula Herrera (15.000); Sofía Pineda ya estaba inactiva.

## 3.3 MERGE para generar multas

**Enunciado.** Con una sola sentencia `MERGE`, mantenga la tabla `multa` al día: para todo préstamo con retraso (devuelto tarde o vencido a la fecha de corte) calcule 1.500 por día; si la multa ya existe y el valor cambió, actualícela; si no existe, insértela.

```sql
CREATE SEQUENCE seq_multa START WITH 5;

MERGE INTO multa m
USING (
  SELECT id_prestamo,
         (NVL(fecha_devolucion, DATE '2026-11-20') - fecha_limite) * 1500 AS valor
  FROM   prestamo
  WHERE  NVL(fecha_devolucion, DATE '2026-11-20') > fecha_limite
) src
ON (m.id_prestamo = src.id_prestamo)
WHEN MATCHED THEN
  UPDATE SET m.valor = src.valor
  WHERE  m.valor <> src.valor
WHEN NOT MATCHED THEN
  INSERT (id_multa, id_prestamo, valor, pagada)
  VALUES (seq_multa.NEXTVAL, src.id_prestamo, src.valor, 'N');

SELECT id_multa, id_prestamo, valor, pagada FROM multa ORDER BY id_multa;

ROLLBACK;
```

**Resultado esperado:**

| id_multa | id_prestamo | valor | pagada |
|---|---|---|---|
| 1 | 2 | 10500 | S |
| 2 | 5 | 15000 | N |
| 3 | 8 | 7500 | S |
| 4 | 12 | 12000 | N |
| 5 | 13 | 4500 | N |
| 6 | 17 | 1500 | N |
| 7 | 16 | 10500 | N |

**Por qué así.** `MERGE` evita el patrón “consultar si existe y luego decidir”, que bajo concurrencia puede insertar duplicados. Las cuatro multas existentes ya tenían el valor correcto, así que el `WHERE` del `UPDATE` no las toca (no genera *redo* inútil); se insertan las de los préstamos 13, 16 y 17, que están vencidos (el orden en que la secuencia les asigna `id_multa` puede variar entre ejecuciones). El `DDL` de la secuencia hace `COMMIT` implícito en Oracle, por eso se crea antes del `MERGE`.

## 3.4 Transacción con SAVEPOINT

**Enunciado.** Registre en una transacción el préstamo del ejemplar 1002 a Julián Vargas (insertar el préstamo y marcar el ejemplar como `PRESTADO`). Luego intente prestarle también el ejemplar 1010, que está dañado: esa segunda parte debe deshacerse sin perder la primera.

```sql
-- Parte 1: préstamo válido
INSERT INTO prestamo (id_prestamo, id_ejemplar, id_socio, fecha_prestamo, fecha_limite)
VALUES (19, 1002, 8, DATE '2026-11-20', DATE '2026-12-04');

UPDATE ejemplar SET estado = 'PRESTADO'
WHERE  id_ejemplar = 1002 AND estado = 'DISPONIBLE';   -- 1 fila

SAVEPOINT sp_primer_prestamo;

-- Parte 2: el ejemplar 1010 está DANADO
INSERT INTO prestamo (id_prestamo, id_ejemplar, id_socio, fecha_prestamo, fecha_limite)
VALUES (20, 1010, 8, DATE '2026-11-20', DATE '2026-12-04');

UPDATE ejemplar SET estado = 'PRESTADO'
WHERE  id_ejemplar = 1010 AND estado = 'DISPONIBLE';   -- 0 filas: no estaba disponible

-- Como el UPDATE no afectó filas, se revierte solo la segunda parte
ROLLBACK TO SAVEPOINT sp_primer_prestamo;

SELECT id_prestamo, id_ejemplar, id_socio FROM prestamo WHERE id_socio = 8 ORDER BY id_prestamo;
SELECT id_ejemplar, estado FROM ejemplar WHERE id_ejemplar IN (1002, 1010);

ROLLBACK;  -- en la práctica sería COMMIT; aquí se deja la base como estaba
```

**Resultado esperado:**

| id_prestamo | id_ejemplar | id_socio |
|---|---|---|
| 18 | 1012 | 8 |
| 19 | 1002 | 8 |

| id_ejemplar | estado |
|---|---|
| 1002 | PRESTADO |
| 1010 | DANADO |

**Por qué así.** El `AND estado = 'DISPONIBLE'` en el `UPDATE` es la validación: si otra sesión ya prestó el ejemplar, la sentencia afecta 0 filas y la aplicación (o el PL/SQL, con `SQL%ROWCOUNT`) sabe que debe deshacer. `ROLLBACK TO SAVEPOINT` revierte solo lo posterior al punto de guardado; la transacción sigue abierta y el primer préstamo se conserva.
