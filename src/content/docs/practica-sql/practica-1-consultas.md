---
title: "Práctica 1: Consultas"
description: SELECT con WHERE, ORDER BY, LIKE, JOIN, LEFT JOIN, GROUP BY, HAVING y subconsultas sobre el caso Biblioteca.
pubDate: 2026-11-23
---

Consultas básicas sobre el caso **Biblioteca**.

Esquema y datos: ver [Práctica SQL: caso Biblioteca](/PovedaCamyla.github.io/docs/practica-sql).

## 1.1 Filtrar y ordenar

**Enunciado.** Liste los libros publicados desde 2015, del más antiguo al más reciente.

```sql
SELECT titulo, anio_publicacion
FROM   libro
WHERE  anio_publicacion >= 2015
ORDER  BY anio_publicacion;
```

**Resultado esperado:**

| titulo | anio_publicacion |
|---|---|
| Precálculo | 2015 |
| Sistemas de bases de datos | 2016 |
| Arquitectura limpia | 2017 |
| Fundamentos de bases de datos | 2019 |
| Introducción al álgebra lineal | 2020 |

**Explicación.** `WHERE` filtra las filas y `ORDER BY` las ordena (de menor a mayor por defecto).

## 1.2 Buscar texto con LIKE

**Enunciado.** Liste los libros que tengan la palabra “bases” en el título.

```sql
SELECT titulo
FROM   libro
WHERE  LOWER(titulo) LIKE '%bases%';
```

**Resultado esperado:**

| titulo |
|---|
| Fundamentos de bases de datos |
| Sistemas de bases de datos |

**Explicación.** `%` significa “cualquier texto”. `LOWER` pasa el título a minúsculas para que no importe cómo esté escrito.

## 1.3 JOIN entre dos tablas

**Enunciado.** Liste cada libro con el nombre de su categoría.

```sql
SELECT l.titulo, c.nombre AS categoria
FROM   libro l
JOIN   categoria_libro c ON c.id_categoria = l.id_categoria
ORDER  BY c.nombre, l.titulo;
```

**Resultado esperado:**

| titulo | categoria |
|---|---|
| Fundamentos de bases de datos | Bases de datos |
| Sistemas de bases de datos | Bases de datos |
| Cien años de soledad | Literatura |
| El amor en los tiempos del cólera | Literatura |
| Introducción al álgebra lineal | Matemáticas |
| Precálculo | Matemáticas |
| Arquitectura limpia | Programación |
| Código limpio | Programación |
| Sistemas operativos modernos | Programación |
| Redes de computadoras | Redes |

**Explicación.** El `JOIN` une cada libro con su categoría usando la llave foránea `id_categoria`.

## 1.4 LEFT JOIN

**Enunciado.** Liste todos los libros con sus autores, incluyendo los libros que no tienen autor registrado.

```sql
SELECT l.titulo, a.nombre AS autor
FROM   libro l
LEFT JOIN libro_autor la ON la.id_libro = l.id_libro
LEFT JOIN autor a        ON a.id_autor  = la.id_autor
ORDER  BY l.titulo, a.nombre;
```

**Resultado esperado:**

| titulo | autor |
|---|---|
| Arquitectura limpia | Robert C. Martin |
| Cien años de soledad | Gabriel García Márquez |
| Código limpio | Robert C. Martin |
| El amor en los tiempos del cólera | Gabriel García Márquez |
| Fundamentos de bases de datos | Abraham Silberschatz |
| Fundamentos de bases de datos | Henry F. Korth |
| Introducción al álgebra lineal | *(null)* |
| Precálculo | James Stewart |
| Redes de computadoras | Andrew S. Tanenbaum |
| Sistemas de bases de datos | Ramez Elmasri |
| Sistemas de bases de datos | Shamkant Navathe |
| Sistemas operativos modernos | Andrew S. Tanenbaum |

**Explicación.** Con `LEFT JOIN` aparecen todos los libros aunque no tengan autor; en ese caso la columna `autor` sale vacía (`NULL`).

## 1.5 Contar con GROUP BY

**Enunciado.** Cuente cuántos libros hay en cada categoría.

```sql
SELECT c.nombre AS categoria, COUNT(*) AS libros
FROM   libro l
JOIN   categoria_libro c ON c.id_categoria = l.id_categoria
GROUP  BY c.nombre
ORDER  BY libros DESC, c.nombre;
```

**Resultado esperado:**

| categoria | libros |
|---|---|
| Programación | 3 |
| Bases de datos | 2 |
| Literatura | 2 |
| Matemáticas | 2 |
| Redes | 1 |

**Explicación.** `GROUP BY` junta las filas de la misma categoría y `COUNT(*)` cuenta cuántas hay en cada grupo.

## 1.6 Filtrar grupos con HAVING

**Enunciado.** Muestre los socios que han hecho más de 2 préstamos.

```sql
SELECT s.nombre, COUNT(*) AS prestamos
FROM   prestamo p
JOIN   socio s ON s.id_socio = p.id_socio
GROUP  BY s.nombre
HAVING COUNT(*) > 2
ORDER  BY prestamos DESC;
```

**Resultado esperado:**

| nombre | prestamos |
|---|---|
| Laura Méndez | 5 |
| Andrés Rojas | 4 |
| Paula Herrera | 3 |

**Explicación.** `WHERE` filtra filas antes de agrupar; `HAVING` filtra los grupos después de contar.

## 1.7 Subconsulta

**Enunciado.** Liste los socios que nunca han pedido un libro.

```sql
SELECT id_socio, nombre
FROM   socio
WHERE  id_socio NOT IN (SELECT id_socio FROM prestamo);
```

**Resultado esperado:**

| id_socio | nombre |
|---|---|
| 7 | Sofía Pineda |

**Explicación.** La subconsulta trae los socios que sí tienen préstamos, y `NOT IN` se queda con los que no están en esa lista.

## 1.8 Valores nulos

**Enunciado.** Liste los préstamos que aún no se han devuelto, con el nombre del socio y la fecha límite.

```sql
SELECT p.id_prestamo, s.nombre, p.fecha_limite
FROM   prestamo p
JOIN   socio s ON s.id_socio = p.id_socio
WHERE  p.fecha_devolucion IS NULL
ORDER  BY p.fecha_limite;
```

**Resultado esperado:**

| id_prestamo | nombre | fecha_limite |
|---|---|---|
| 16 | Paula Herrera | 2026-11-13 |
| 13 | Laura Méndez | 2026-11-17 |
| 17 | Diego Castillo | 2026-11-19 |
| 14 | Andrés Rojas | 2026-11-24 |
| 15 | Carlos Duarte | 2026-11-27 |
| 18 | Julián Vargas | 2026-11-29 |

**Explicación.** Un préstamo sin devolver tiene `fecha_devolucion` vacía. Para preguntar por un valor vacío se usa `IS NULL`, no `= NULL`.
