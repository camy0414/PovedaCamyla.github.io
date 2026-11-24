---
title: "Práctica PL/SQL 1: Bloques y sentencias de control"
description: Bloques anónimos con variables, SELECT INTO, IF, CASE y ciclos sobre el caso Biblioteca.
date: 2026-11-23T12:05:00
categories: [PL/SQL, Prácticas]
tags: [Oracle, PL/SQL, Bases de Datos 2]
---

Práctica propia de PL/SQL en **Oracle** sobre el caso **Biblioteca** de la [práctica de SQL](/PovedaCamyla.github.io/docs/practica-sql). Antes de empezar hay que ejecutar el <a href="/PovedaCamyla.github.io/evidencias/practicas/biblioteca_esquema.sql" download>script de la biblioteca</a> y activar la salida en pantalla:

```sql
SET SERVEROUTPUT ON
```

## 1.1 Variables y SELECT INTO

**Enunciado.** Lea el nombre y el tipo del socio 1 y, según el tipo, muestre cuántos días puede tener un libro: estudiante 14, docente 30, externo 7.

```sql
DECLARE
  v_nombre  socio.nombre%TYPE;
  v_tipo    socio.tipo%TYPE;
  v_dias    NUMBER;
BEGIN
  SELECT nombre, tipo
  INTO   v_nombre, v_tipo
  FROM   socio
  WHERE  id_socio = 1;

  IF v_tipo = 'DOCENTE' THEN
    v_dias := 30;
  ELSIF v_tipo = 'EXTERNO' THEN
    v_dias := 7;
  ELSE
    v_dias := 14;
  END IF;

  DBMS_OUTPUT.PUT_LINE('Socio: ' || v_nombre || ' (' || v_tipo || ')');
  DBMS_OUTPUT.PUT_LINE('Días de préstamo: ' || v_dias);
END;
/
```

**Salida esperada:**

```text
Socio: Laura Méndez (ESTUDIANTE)
Días de préstamo: 14
```

**Explicación.** `%TYPE` hace que la variable tenga el mismo tipo que la columna. `SELECT ... INTO` guarda el resultado de la consulta en las variables (debe devolver exactamente una fila).

## 1.2 CASE dentro de un ciclo FOR

**Enunciado.** Recorra todos los libros y clasifíquelos según el año: antes de 2000 “Clásico”, desde 2020 “Reciente” y los demás “Actual”.

```sql
DECLARE
  v_tipo VARCHAR2(20);
BEGIN
  FOR r IN (SELECT titulo, anio_publicacion FROM libro ORDER BY anio_publicacion) LOOP
    v_tipo := CASE
                WHEN r.anio_publicacion < 2000  THEN 'Clásico'
                WHEN r.anio_publicacion >= 2020 THEN 'Reciente'
                ELSE 'Actual'
              END;
    DBMS_OUTPUT.PUT_LINE(r.anio_publicacion || ' - ' || r.titulo || ': ' || v_tipo);
  END LOOP;
END;
/
```

**Salida esperada:**

```text
1967 - Cien años de soledad: Clásico
1985 - El amor en los tiempos del cólera: Clásico
2008 - Código limpio: Actual
2011 - Redes de computadoras: Actual
2014 - Sistemas operativos modernos: Actual
2015 - Precálculo: Actual
2016 - Sistemas de bases de datos: Actual
2017 - Arquitectura limpia: Actual
2019 - Fundamentos de bases de datos: Actual
2020 - Introducción al álgebra lineal: Reciente
```

**Explicación.** El `FOR r IN (SELECT ...)` recorre las filas de la consulta una por una, y `r` tiene las columnas de cada fila. El `CASE` devuelve un valor según la primera condición que se cumpla.

## 1.3 Ciclos FOR y WHILE

**Enunciado.** La multa es de 1.500 por día de retraso. Muestre la multa para 1 a 5 días con un `FOR` y luego, con un `WHILE`, encuentre desde qué día la multa llega a 10.000.

```sql
DECLARE
  v_dia   NUMBER := 0;
  v_multa NUMBER := 0;
BEGIN
  FOR i IN 1 .. 5 LOOP
    DBMS_OUTPUT.PUT_LINE('Día ' || i || ': ' || (i * 1500));
  END LOOP;

  WHILE v_multa < 10000 LOOP
    v_dia   := v_dia + 1;
    v_multa := v_dia * 1500;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('La multa llega a 10.000 el día ' || v_dia || ' (' || v_multa || ')');
END;
/
```

**Salida esperada:**

```text
Día 1: 1500
Día 2: 3000
Día 3: 4500
Día 4: 6000
Día 5: 7500
La multa llega a 10.000 el día 7 (10500)
```

**Explicación.** El `FOR` se usa cuando se sabe cuántas vueltas dar. El `WHILE` repite mientras la condición sea verdadera, así que sirve cuando no se sabe de antemano cuántas vueltas hacen falta.
