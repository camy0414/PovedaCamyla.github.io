---
title: "Práctica 1: Consultas y JOINs"
description: INNER y OUTER JOIN, agregación condicional, NOT EXISTS y cálculo con fechas sobre el caso Biblioteca.
pubDate: 2026-11-23
---

Primer bloque de práctica: recuperar información cruzando tablas. Todas las consultas usan como **fecha de corte** el `2026-11-20`, para que el resultado sea reproducible.

Esquema y datos: ver [Práctica SQL: caso Biblioteca](/PovedaCamyla.github.io/docs/practica-sql).

## 1.1 Catálogo con autores

**Enunciado.** Liste cada libro con su categoría y sus autores en una sola columna separados por coma, ordenado por categoría y título. Los libros sin autor también deben aparecer.

```sql
SELECT c.nombre AS categoria,
       l.titulo,
       LISTAGG(a.nombre, ', ') WITHIN GROUP (ORDER BY a.nombre) AS autores
FROM   libro l
JOIN   categoria_libro c ON c.id_categoria = l.id_categoria
LEFT JOIN libro_autor la ON la.id_libro = l.id_libro
LEFT JOIN autor a        ON a.id_autor  = la.id_autor
GROUP  BY c.nombre, l.titulo
ORDER  BY c.nombre, l.titulo;
```

**Resultado esperado:**

| categoria | titulo | autores |
|---|---|---|
| Bases de datos | Fundamentos de bases de datos | Abraham Silberschatz, Henry F. Korth |
| Bases de datos | Sistemas de bases de datos | Ramez Elmasri, Shamkant Navathe |
| Literatura | Cien años de soledad | Gabriel García Márquez |
| Literatura | El amor en los tiempos del cólera | Gabriel García Márquez |
| Matemáticas | Introducción al álgebra lineal | *(null)* |
| Matemáticas | Precálculo | James Stewart |
| Programación | Arquitectura limpia | Robert C. Martin |
| Programación | Código limpio | Robert C. Martin |
| Programación | Sistemas operativos modernos | Andrew S. Tanenbaum |
| Redes | Redes de computadoras | Andrew S. Tanenbaum |

**Por qué así.** La relación libro–autor es de muchos a muchos, así que un libro con dos autores produce dos filas; `LISTAGG` las vuelve a juntar en una. Los dos `LEFT JOIN` son necesarios: si el segundo fuera `INNER`, anularía el efecto del primero y el libro sin autor desaparecería.

## 1.2 Libros sin autor registrado

**Enunciado.** Encuentre los libros que no tienen ningún autor asociado (error de catalogación).

```sql
SELECT l.id_libro, l.titulo
FROM   libro l
LEFT JOIN libro_autor la ON la.id_libro = l.id_libro
WHERE  la.id_libro IS NULL;
```

**Resultado esperado:**

| id_libro | titulo |
|---|---|
| 110 | Introducción al álgebra lineal |

**Por qué así.** Patrón *anti-join*: el `LEFT JOIN` conserva todos los libros y los que no encontraron pareja traen `NULL` en las columnas de `libro_autor`. Se filtra por la columna de la clave, que nunca es nula cuando sí hay coincidencia.

## 1.3 Disponibilidad por libro

**Enunciado.** Para cada libro muestre el total de ejemplares y cuántos están disponibles, prestados y dañados. Ordene por los que tienen menos disponibles.

```sql
SELECT l.titulo,
       COUNT(e.id_ejemplar)                                   AS total,
       SUM(CASE WHEN e.estado = 'DISPONIBLE' THEN 1 ELSE 0 END) AS disponibles,
       SUM(CASE WHEN e.estado = 'PRESTADO'   THEN 1 ELSE 0 END) AS prestados,
       SUM(CASE WHEN e.estado = 'DANADO'     THEN 1 ELSE 0 END) AS danados
FROM   libro l
LEFT JOIN ejemplar e ON e.id_libro = l.id_libro
GROUP  BY l.titulo
ORDER  BY disponibles, l.titulo;
```

**Resultado esperado:**

| titulo | total | disponibles | prestados | danados |
|---|---|---|---|---|
| Introducción al álgebra lineal | 0 | 0 | 0 | 0 |
| Redes de computadoras | 2 | 0 | 1 | 1 |
| Arquitectura limpia | 1 | 1 | 0 | 0 |
| Cien años de soledad | 2 | 1 | 1 | 0 |
| Código limpio | 2 | 1 | 1 | 0 |
| El amor en los tiempos del cólera | 1 | 1 | 0 | 0 |
| Fundamentos de bases de datos | 3 | 1 | 2 | 0 |
| Sistemas de bases de datos | 2 | 1 | 1 | 0 |
| Sistemas operativos modernos | 1 | 1 | 0 | 0 |
| Precálculo | 2 | 2 | 0 | 0 |

**Por qué así.** *Agregación condicional*: un solo recorrido de la tabla produce varias columnas de conteo, en lugar de tres subconsultas. `COUNT(e.id_ejemplar)` cuenta solo filas reales, por eso el libro sin ejemplares (Introducción al álgebra lineal) da 0 y no 1.

## 1.4 Socios que nunca han pedido un libro

**Enunciado.** Liste los socios que no tienen ningún préstamo registrado, con su tipo y estado.

```sql
SELECT s.id_socio, s.nombre, s.tipo, s.activo
FROM   socio s
WHERE  NOT EXISTS (SELECT 1
                   FROM   prestamo p
                   WHERE  p.id_socio = s.id_socio);
```

**Resultado esperado:**

| id_socio | nombre | tipo | activo |
|---|---|---|---|
| 7 | Sofía Pineda | ESTUDIANTE | N |

**Por qué así.** Se prefirió `NOT EXISTS` sobre `NOT IN`: si la subconsulta de un `NOT IN` devuelve algún `NULL`, la condición nunca es verdadera y la consulta no trae nada. `NOT EXISTS` no tiene ese problema y además se detiene en la primera coincidencia.

## 1.5 Préstamos vencidos

**Enunciado.** Liste los préstamos sin devolver cuya fecha límite ya pasó, con el socio, el libro, los días de retraso y la multa que se generaría (1.500 por día).

```sql
SELECT p.id_prestamo,
       s.nombre                              AS socio,
       l.titulo,
       p.fecha_limite,
       DATE '2026-11-20' - p.fecha_limite   AS dias_retraso,
       (DATE '2026-11-20' - p.fecha_limite) * 1500 AS multa_estimada
FROM   prestamo p
JOIN   socio s    ON s.id_socio    = p.id_socio
JOIN   ejemplar e ON e.id_ejemplar = p.id_ejemplar
JOIN   libro l    ON l.id_libro    = e.id_libro
WHERE  p.fecha_devolucion IS NULL
AND    p.fecha_limite < DATE '2026-11-20'
ORDER  BY dias_retraso DESC;
```

**Resultado esperado:**

| id_prestamo | socio | titulo | fecha_limite | dias_retraso | multa_estimada |
|---|---|---|---|---|---|
| 16 | Paula Herrera | Código limpio | 2026-11-13 | 7 | 10500 |
| 13 | Laura Méndez | Fundamentos de bases de datos | 2026-11-17 | 3 | 4500 |
| 17 | Diego Castillo | Redes de computadoras | 2026-11-19 | 1 | 1500 |

**Por qué así.** En Oracle, restar dos `DATE` da el número de días (con decimales si hay horas). En producción se usaría `TRUNC(SYSDATE)` en lugar de la fecha fija; el `TRUNC` evita que la hora del día genere fracciones de día.
