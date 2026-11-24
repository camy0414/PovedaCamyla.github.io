---
title: "Práctica SQL: caso Biblioteca"
description: Ejercicios propios de práctica, distintos a los del taller, sobre una biblioteca universitaria con libros, ejemplares, socios, préstamos y multas.
---

Ejercicios que preparé por mi cuenta para repasar SQL en **Oracle 19c**, con un caso distinto al de los talleres: una **biblioteca universitaria**. El mismo esquema se reutiliza en las prácticas de PL/SQL.

## Modelo

| Tabla | Qué guarda |
|---|---|
| `categoria_libro` | Categorías del catálogo (Bases de datos, Programación, Redes…) |
| `autor` | Autores y su país |
| `libro` | Título, ISBN, año y categoría |
| `libro_autor` | Relación muchos a muchos entre libros y autores |
| `ejemplar` | Copias físicas de cada libro y su estado (`DISPONIBLE`, `PRESTADO`, `DANADO`) |
| `socio` | Estudiantes, docentes y externos inscritos |
| `prestamo` | Préstamo de un ejemplar a un socio, con fecha límite y fecha de devolución |
| `multa` | Multa de un préstamo devuelto tarde (1.500 por día de retraso) |

Los datos están armados para que haya casos interesantes: un libro sin autor, un socio sin préstamos, un ejemplar dañado, préstamos vencidos y multas pagadas y pendientes. Los ejercicios usan como **fecha de corte el 20 de noviembre de 2026**, para que los resultados sean reproducibles.

<a href="/PovedaCamyla.github.io/evidencias/practicas/biblioteca_esquema.sql" download>Descargar el script del esquema y los datos (biblioteca_esquema.sql)</a>

## Contenido

1. **Consultas y JOINs:** INNER y OUTER JOIN, anti-join, agregación condicional, `NOT EXISTS` y aritmética de fechas.
2. **Agregación, subconsultas y funciones analíticas:** `ROLLUP`, `HAVING` con subconsulta, `DENSE_RANK`, `LAG` y CTE.
3. **DML, MERGE y transacciones:** vistas, `UPDATE` correlacionado, `MERGE` y `SAVEPOINT`.
