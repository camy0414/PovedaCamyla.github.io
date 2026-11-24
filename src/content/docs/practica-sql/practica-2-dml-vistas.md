---
title: "Práctica 2: Insertar, actualizar, borrar y vistas"
description: INSERT, UPDATE, DELETE, COMMIT y ROLLBACK, y una vista sobre el caso Biblioteca.
pubDate: 2026-11-23
---

Modificar datos sobre el caso **Biblioteca**. Al final de cada ejercicio se hace `ROLLBACK` para dejar los datos como estaban.

Esquema y datos: ver [Práctica SQL: caso Biblioteca](/PovedaCamyla.github.io/docs/practica-sql).

## 2.1 INSERT

**Enunciado.** Registre una nueva socia y verifique que quedó guardada.

```sql
INSERT INTO socio (id_socio, documento, nombre, tipo, fecha_registro, activo)
VALUES (9, '1090909090', 'Ana Torres', 'ESTUDIANTE', DATE '2026-11-20', 'S');

SELECT id_socio, nombre, tipo FROM socio WHERE id_socio = 9;

ROLLBACK;
```

**Resultado esperado:**

| id_socio | nombre | tipo |
|---|---|---|
| 9 | Ana Torres | ESTUDIANTE |

**Explicación.** Se indican las columnas y luego los valores en el mismo orden. Hasta hacer `COMMIT`, el cambio solo lo ve la sesión actual.

## 2.2 UPDATE

**Enunciado.** Marque como dañado el ejemplar 1007 y verifique el cambio.

```sql
UPDATE ejemplar
SET    estado = 'DANADO'
WHERE  id_ejemplar = 1007;

SELECT id_ejemplar, estado FROM ejemplar WHERE id_ejemplar = 1007;

ROLLBACK;
```

**Resultado esperado:**

| id_ejemplar | estado |
|---|---|
| 1007 | DANADO |

**Explicación.** El `WHERE` es fundamental: sin él, el `UPDATE` cambiaría todos los ejemplares.

## 2.3 DELETE

**Enunciado.** Borre las multas que ya están pagadas y cuente cuántas quedan.

```sql
DELETE FROM multa
WHERE  pagada = 'S';

SELECT COUNT(*) AS multas_restantes FROM multa;

ROLLBACK;
```

**Resultado esperado:**

| multas_restantes |
|---|
| 2 |

**Explicación.** Había 4 multas y 2 estaban pagadas, así que quedan 2. Igual que con `UPDATE`, sin `WHERE` se borrarían todas.

## 2.4 COMMIT y ROLLBACK

**Enunciado.** Registre un préstamo y marque el ejemplar como prestado. Luego deshaga todo con `ROLLBACK` y verifique que nada cambió.

```sql
INSERT INTO prestamo (id_prestamo, id_ejemplar, id_socio, fecha_prestamo, fecha_limite)
VALUES (19, 1002, 5, DATE '2026-11-20', DATE '2026-12-20');

UPDATE ejemplar SET estado = 'PRESTADO' WHERE id_ejemplar = 1002;

ROLLBACK;

SELECT COUNT(*) AS prestamos FROM prestamo;
SELECT estado FROM ejemplar WHERE id_ejemplar = 1002;
```

**Resultado esperado:**

| prestamos |
|---|
| 18 |

| estado |
|---|
| DISPONIBLE |

**Explicación.** Las dos sentencias forman una sola transacción: el préstamo y el cambio de estado van juntos. `ROLLBACK` deshace ambas, por eso siguen 18 préstamos y el ejemplar sigue `DISPONIBLE`. Con `COMMIT` habrían quedado guardadas.

## 2.5 Vista

**Enunciado.** Cree una vista con los préstamos que no se han devuelto, mostrando el socio y el título del libro.

```sql
CREATE OR REPLACE VIEW v_prestamos_activos AS
SELECT p.id_prestamo, s.nombre AS socio, l.titulo, p.fecha_limite
FROM   prestamo p
JOIN   socio s    ON s.id_socio    = p.id_socio
JOIN   ejemplar e ON e.id_ejemplar = p.id_ejemplar
JOIN   libro l    ON l.id_libro    = e.id_libro
WHERE  p.fecha_devolucion IS NULL;

SELECT * FROM v_prestamos_activos ORDER BY fecha_limite;
```

**Resultado esperado:**

| id_prestamo | socio | titulo | fecha_limite |
|---|---|---|---|
| 16 | Paula Herrera | Código limpio | 2026-11-13 |
| 13 | Laura Méndez | Fundamentos de bases de datos | 2026-11-17 |
| 17 | Diego Castillo | Redes de computadoras | 2026-11-19 |
| 14 | Andrés Rojas | Fundamentos de bases de datos | 2026-11-24 |
| 15 | Carlos Duarte | Sistemas de bases de datos | 2026-11-27 |
| 18 | Julián Vargas | Cien años de soledad | 2026-11-29 |

**Explicación.** Una vista guarda la consulta con un nombre. Después se consulta como si fuera una tabla, sin repetir los `JOIN`.
