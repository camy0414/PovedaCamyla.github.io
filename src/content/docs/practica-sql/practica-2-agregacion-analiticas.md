---
title: "Práctica 2: Agregación, subconsultas y funciones analíticas"
description: ROLLUP, HAVING con subconsulta, DENSE_RANK, LAG y CTE sobre el caso Biblioteca.
pubDate: 2026-11-23
---

Segundo bloque: resumir y comparar. Aquí aparecen las funciones analíticas (`OVER`), que calculan sobre un grupo de filas **sin colapsarlas**, a diferencia de `GROUP BY`.

Esquema y datos: ver [Práctica SQL: caso Biblioteca](/PovedaCamyla.github.io/docs/practica-sql).

## 2.1 Préstamos por tipo de socio con subtotales

**Enunciado.** Cuente los préstamos por tipo de socio y por mes de préstamo, con subtotal por tipo y total general.

```sql
SELECT CASE WHEN GROUPING(s.tipo) = 1 THEN 'TOTAL' ELSE s.tipo END AS tipo,
       CASE WHEN GROUPING(s.tipo) = 1 THEN 'Todos'
            WHEN GROUPING(TO_CHAR(p.fecha_prestamo, 'YYYY-MM')) = 1 THEN 'Subtotal'
            ELSE TO_CHAR(p.fecha_prestamo, 'YYYY-MM') END AS mes,
       COUNT(*) AS prestamos
FROM   prestamo p
JOIN   socio s ON s.id_socio = p.id_socio
GROUP  BY ROLLUP (s.tipo, TO_CHAR(p.fecha_prestamo, 'YYYY-MM'))
ORDER  BY GROUPING(s.tipo), s.tipo, GROUPING(TO_CHAR(p.fecha_prestamo, 'YYYY-MM')), 2;
```

**Resultado esperado:**

| tipo | mes | prestamos |
|---|---|---|
| DOCENTE | 2026-08 | 1 |
| DOCENTE | 2026-09 | 1 |
| DOCENTE | 2026-10 | 1 |
| DOCENTE | Subtotal | 3 |
| ESTUDIANTE | 2026-08 | 3 |
| ESTUDIANTE | 2026-09 | 3 |
| ESTUDIANTE | 2026-10 | 4 |
| ESTUDIANTE | 2026-11 | 3 |
| ESTUDIANTE | Subtotal | 13 |
| EXTERNO | 2026-09 | 1 |
| EXTERNO | 2026-11 | 1 |
| EXTERNO | Subtotal | 2 |
| TOTAL | Todos | 18 |

**Por qué así.** `ROLLUP(a, b)` genera los grupos `(a, b)`, `(a)` y `()` en una sola consulta. `GROUPING()` devuelve 1 en las filas de subtotal, lo que permite etiquetarlas en vez de mostrar un `NULL` ambiguo.

## 2.2 Socios por encima del promedio

**Enunciado.** Muestre los socios que han hecho más préstamos que el promedio de préstamos por socio (contando solo socios con al menos un préstamo).

```sql
SELECT s.nombre, COUNT(*) AS prestamos
FROM   prestamo p
JOIN   socio s ON s.id_socio = p.id_socio
GROUP  BY s.nombre
HAVING COUNT(*) > (SELECT AVG(cantidad)
                   FROM  (SELECT COUNT(*) AS cantidad
                          FROM   prestamo
                          GROUP  BY id_socio))
ORDER  BY prestamos DESC;
```

**Resultado esperado:**

| nombre | prestamos |
|---|---|
| Laura Méndez | 5 |
| Andrés Rojas | 4 |
| Paula Herrera | 3 |

**Por qué así.** `WHERE` filtra filas antes de agrupar; `HAVING` filtra grupos después. El promedio se calcula sobre otra agregación (préstamos por socio), por eso necesita una subconsulta anidada: Oracle no permite `AVG(COUNT(*))` directamente en el `HAVING`. Aquí el promedio es 18 / 7 ≈ 2,57.

## 2.3 Ranking de libros más prestados por categoría

**Enunciado.** Para cada categoría, ordene sus libros por número de préstamos y muestre la posición. Si hay empate, comparten puesto.

```sql
SELECT categoria, titulo, prestamos, puesto
FROM (
  SELECT c.nombre AS categoria,
         l.titulo,
         COUNT(p.id_prestamo) AS prestamos,
         DENSE_RANK() OVER (PARTITION BY c.nombre
                            ORDER BY COUNT(p.id_prestamo) DESC) AS puesto
  FROM   libro l
  JOIN   categoria_libro c ON c.id_categoria = l.id_categoria
  LEFT JOIN ejemplar e     ON e.id_libro     = l.id_libro
  LEFT JOIN prestamo p     ON p.id_ejemplar  = e.id_ejemplar
  GROUP  BY c.nombre, l.titulo
)
ORDER BY categoria, puesto, titulo;
```

**Resultado esperado:**

| categoria | titulo | prestamos | puesto |
|---|---|---|---|
| Bases de datos | Fundamentos de bases de datos | 4 | 1 |
| Bases de datos | Sistemas de bases de datos | 3 | 2 |
| Literatura | Cien años de soledad | 2 | 1 |
| Literatura | El amor en los tiempos del cólera | 1 | 2 |
| Matemáticas | Precálculo | 2 | 1 |
| Matemáticas | Introducción al álgebra lineal | 0 | 2 |
| Programación | Código limpio | 3 | 1 |
| Programación | Arquitectura limpia | 1 | 2 |
| Programación | Sistemas operativos modernos | 1 | 2 |
| Redes | Redes de computadoras | 1 | 1 |

**Por qué así.** `PARTITION BY` reinicia el ranking en cada categoría. `DENSE_RANK` no deja huecos tras un empate (1, 1, 2); `RANK` daría (1, 1, 3) y `ROW_NUMBER` rompería el empate arbitrariamente. La función analítica se evalúa después del `GROUP BY`, por eso puede ordenar por `COUNT(...)`.

## 2.4 Frecuencia de uso de cada socio

**Enunciado.** Para cada préstamo de la socia Laura Méndez muestre la fecha, la fecha del préstamo anterior y cuántos días pasaron entre ambos.

```sql
SELECT p.id_prestamo,
       p.fecha_prestamo,
       LAG(p.fecha_prestamo) OVER (ORDER BY p.fecha_prestamo) AS prestamo_anterior,
       p.fecha_prestamo
         - LAG(p.fecha_prestamo) OVER (ORDER BY p.fecha_prestamo) AS dias_entre
FROM   prestamo p
JOIN   socio s ON s.id_socio = p.id_socio
WHERE  s.nombre = 'Laura Méndez'
ORDER  BY p.fecha_prestamo;
```

**Resultado esperado:**

| id_prestamo | fecha_prestamo | prestamo_anterior | dias_entre |
|---|---|---|---|
| 1 | 2026-08-04 | *(null)* | *(null)* |
| 2 | 2026-08-20 | 2026-08-04 | 16 |
| 8 | 2026-09-15 | 2026-08-20 | 26 |
| 11 | 2026-10-05 | 2026-09-15 | 20 |
| 13 | 2026-11-03 | 2026-10-05 | 29 |

**Por qué así.** `LAG` lee una columna de la fila anterior dentro de la ventana, sin necesidad de un *self join*. Para hacerlo para todos los socios a la vez bastaría con `OVER (PARTITION BY p.id_socio ORDER BY p.fecha_prestamo)`.

## 2.5 Reporte de cumplimiento con CTE

**Enunciado.** Usando expresiones de tabla común (`WITH`), calcule para cada socio con préstamos: total de préstamos, cuántos devolvió tarde, el porcentaje de retraso y la deuda pendiente por multas no pagadas.

```sql
WITH resumen AS (
  SELECT id_socio,
         COUNT(*) AS total,
         SUM(CASE WHEN fecha_devolucion > fecha_limite THEN 1 ELSE 0 END) AS tarde
  FROM   prestamo
  GROUP  BY id_socio
),
deuda AS (
  SELECT p.id_socio, SUM(m.valor) AS pendiente
  FROM   multa m
  JOIN   prestamo p ON p.id_prestamo = m.id_prestamo
  WHERE  m.pagada = 'N'
  GROUP  BY p.id_socio
)
SELECT s.nombre,
       r.total,
       r.tarde,
       ROUND(100 * r.tarde / r.total, 1) AS pct_retraso,
       COALESCE(d.pendiente, 0)          AS deuda
FROM   resumen r
JOIN   socio s     ON s.id_socio = r.id_socio
LEFT JOIN deuda d  ON d.id_socio = r.id_socio
ORDER  BY pct_retraso DESC, s.nombre;
```

**Resultado esperado:**

| nombre | total | tarde | pct_retraso | deuda |
|---|---|---|---|---|
| Laura Méndez | 5 | 2 | 40 | 0 |
| Paula Herrera | 3 | 1 | 33.3 | 15000 |
| Andrés Rojas | 4 | 1 | 25 | 12000 |
| Carlos Duarte | 2 | 0 | 0 | 0 |
| Diego Castillo | 2 | 0 | 0 | 0 |
| Julián Vargas | 1 | 0 | 0 | 0 |
| Marta Salazar | 1 | 0 | 0 | 0 |

**Por qué así.** Cada CTE resuelve una pregunta por separado y la consulta final solo las une. Si se juntaran préstamos y multas en un mismo `JOIN` antes de agrupar, cada multa repetiría filas y el conteo de préstamos saldría inflado (el clásico error de *fan-out*).
