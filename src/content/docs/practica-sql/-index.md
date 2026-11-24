---
title: "Práctica SQL: caso Biblioteca"
description: Ejercicios propios de práctica de SQL sobre una biblioteca universitaria con libros, ejemplares, socios, préstamos y multas.
---

Ejercicios que preparé para repasar SQL con un caso propio: una **biblioteca universitaria**. Son consultas sencillas que funcionan en **Oracle** y en **PostgreSQL**. El mismo esquema se usa en las prácticas de PL/SQL.

## Tablas

| Tabla | Qué guarda |
|---|---|
| `categoria_libro` | Categorías (Bases de datos, Programación, Redes…) |
| `autor` | Autores y su país |
| `libro` | Título, ISBN, año y categoría |
| `libro_autor` | Qué autor escribió cada libro (relación muchos a muchos) |
| `ejemplar` | Copias de cada libro y su estado (`DISPONIBLE`, `PRESTADO`, `DANADO`) |
| `socio` | Estudiantes, docentes y externos inscritos |
| `prestamo` | Qué ejemplar se prestó, a quién, la fecha límite y la fecha de devolución |
| `multa` | Multa por devolver tarde (1.500 por día) |

<a href="/PovedaCamyla.github.io/evidencias/practicas/biblioteca_esquema.sql" download>Descargar el script con las tablas y los datos (biblioteca_esquema.sql)</a>

## Contenido

1. **Consultas:** `WHERE`, `ORDER BY`, `LIKE`, `JOIN`, `LEFT JOIN`, `GROUP BY`, `HAVING` y subconsultas.
2. **Insertar, actualizar, borrar y vistas:** `INSERT`, `UPDATE`, `DELETE`, `COMMIT`, `ROLLBACK` y `CREATE VIEW`.
