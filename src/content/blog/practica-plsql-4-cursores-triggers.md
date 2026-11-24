---
title: "Práctica PL/SQL 4: Cursores y disparadores"
description: Cursor explícito, cursor con parámetro y dos disparadores (BEFORE y AFTER) sobre el caso Biblioteca.
date: 2026-11-23T12:02:00
categories: [PL/SQL, Prácticas]
tags: [Oracle, PL/SQL, Cursores, Triggers, Bases de Datos 2]
---

Práctica propia sobre el caso **Biblioteca**. Un **cursor** permite recorrer el resultado de una consulta fila por fila. Un **disparador** (*trigger*) es código que se ejecuta solo cuando pasa algo en una tabla.

## 4.1 Cursor explícito

**Enunciado.** Con un cursor explícito (`OPEN`, `FETCH`, `CLOSE`), liste los préstamos que no se han devuelto y al final muestre cuántos son.

```sql
DECLARE
  CURSOR c_activos IS
    SELECT p.id_prestamo, s.nombre, p.fecha_limite
    FROM   prestamo p
    JOIN   socio s ON s.id_socio = p.id_socio
    WHERE  p.fecha_devolucion IS NULL
    ORDER  BY p.fecha_limite;

  v_id      prestamo.id_prestamo%TYPE;
  v_nombre  socio.nombre%TYPE;
  v_limite  prestamo.fecha_limite%TYPE;
BEGIN
  OPEN c_activos;
  LOOP
    FETCH c_activos INTO v_id, v_nombre, v_limite;
    EXIT WHEN c_activos%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE(v_id || ' - ' || v_nombre || ' - ' || TO_CHAR(v_limite, 'YYYY-MM-DD'));
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('Total: ' || c_activos%ROWCOUNT);
  CLOSE c_activos;
END;
/
```

**Salida esperada:**

```text
16 - Paula Herrera - 2026-11-13
13 - Laura Méndez - 2026-11-17
17 - Diego Castillo - 2026-11-19
14 - Andrés Rojas - 2026-11-24
15 - Carlos Duarte - 2026-11-27
18 - Julián Vargas - 2026-11-29
Total: 6
```

**Explicación.** `OPEN` ejecuta la consulta, `FETCH` lee una fila, `%NOTFOUND` avisa cuando ya no hay más filas y `CLOSE` libera el cursor. `%ROWCOUNT` dice cuántas filas se han leído.

## 4.2 Cursor con parámetro

**Enunciado.** Cree un cursor que reciba una categoría y liste sus libros. Úselo con la categoría 1 (Bases de datos).

```sql
DECLARE
  CURSOR c_libros (p_categoria NUMBER) IS
    SELECT titulo, anio_publicacion
    FROM   libro
    WHERE  id_categoria = p_categoria
    ORDER  BY titulo;
BEGIN
  FOR r IN c_libros(1) LOOP
    DBMS_OUTPUT.PUT_LINE(r.titulo || ' (' || r.anio_publicacion || ')');
  END LOOP;
END;
/
```

**Salida esperada:**

```text
Fundamentos de bases de datos (2019)
Sistemas de bases de datos (2016)
```

**Explicación.** El parámetro permite usar el mismo cursor con distintas categorías. El `FOR` abre, recorre y cierra el cursor solo.

## 4.3 Trigger BEFORE: corregir el nombre

**Enunciado.** Cree un disparador que, antes de guardar un socio, quite los espacios sobrantes de su nombre y ponga la primera letra de cada palabra en mayúscula.

```sql
CREATE OR REPLACE TRIGGER trg_socio_nombre
BEFORE INSERT OR UPDATE ON socio
FOR EACH ROW
BEGIN
  :NEW.nombre := INITCAP(TRIM(:NEW.nombre));
END;
/

INSERT INTO socio (id_socio, documento, nombre, tipo, fecha_registro)
VALUES (9, '1090909090', '  ana torres  ', 'ESTUDIANTE', SYSDATE);

SELECT nombre FROM socio WHERE id_socio = 9;   -- Ana Torres

ROLLBACK;
```

**Explicación.** `:NEW` es la fila que se va a guardar. En un disparador `BEFORE` se puede cambiar `:NEW` antes de que llegue a la tabla.

## 4.4 Trigger AFTER: historial de cambios

**Enunciado.** Guarde en una tabla de historial cada vez que cambie el estado de un ejemplar.

```sql
CREATE TABLE hist_estado_ejemplar (
  id_ejemplar      NUMBER,
  estado_anterior  VARCHAR2(12),
  estado_nuevo     VARCHAR2(12),
  fecha            DATE
);

CREATE OR REPLACE TRIGGER trg_ejemplar_historial
AFTER UPDATE OF estado ON ejemplar
FOR EACH ROW
BEGIN
  INSERT INTO hist_estado_ejemplar (id_ejemplar, estado_anterior, estado_nuevo, fecha)
  VALUES (:OLD.id_ejemplar, :OLD.estado, :NEW.estado, SYSDATE);
END;
/

UPDATE ejemplar SET estado = 'PRESTADO' WHERE id_ejemplar = 1002;

SELECT id_ejemplar, estado_anterior, estado_nuevo FROM hist_estado_ejemplar;

ROLLBACK;
```

**Resultado esperado:**

| ID_EJEMPLAR | ESTADO_ANTERIOR | ESTADO_NUEVO |
|---|---|---|
| 1002 | DISPONIBLE | PRESTADO |

**Explicación.** `:OLD` tiene los valores antes del cambio y `:NEW` los nuevos. `AFTER UPDATE OF estado` hace que el disparador solo se active cuando se actualiza la columna `estado`.
