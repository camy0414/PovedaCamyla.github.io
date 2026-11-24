---
title: "Práctica PL/SQL 3: Excepciones"
description: Excepciones predefinidas, excepciones propias y RAISE_APPLICATION_ERROR en un procedimiento para prestar libros, sobre el caso Biblioteca.
date: 2026-11-23T12:03:00
categories: [PL/SQL, Prácticas]
tags: [Oracle, PL/SQL, Excepciones, Bases de Datos 2]
---

Práctica propia sobre el caso **Biblioteca**. Una **excepción** es un error que ocurre mientras se ejecuta el código; la sección `EXCEPTION` permite atraparlo y responder con un mensaje claro.

## 3.1 Excepciones predefinidas

**Enunciado.** Busque el socio 99, que no existe, y luego intente guardar en una variable el nombre de “el” docente, cuando hay dos. Atrape los dos errores.

```sql
DECLARE
  v_nombre socio.nombre%TYPE;
BEGIN
  BEGIN
    SELECT nombre INTO v_nombre FROM socio WHERE id_socio = 99;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      DBMS_OUTPUT.PUT_LINE('No existe el socio 99');
  END;

  BEGIN
    SELECT nombre INTO v_nombre FROM socio WHERE tipo = 'DOCENTE';
  EXCEPTION
    WHEN TOO_MANY_ROWS THEN
      DBMS_OUTPUT.PUT_LINE('La consulta devolvió más de un docente');
  END;
END;
/
```

**Salida esperada:**

```text
No existe el socio 99
La consulta devolvió más de un docente
```

**Explicación.** `SELECT ... INTO` exige exactamente una fila: si no hay ninguna lanza `NO_DATA_FOUND` y si hay varias, `TOO_MANY_ROWS`. Cada prueba va en su propio `BEGIN ... END` para que el primer error no detenga la segunda.

## 3.2 Procedimiento con excepciones propias

**Enunciado.** Cree un procedimiento que preste un ejemplar a un socio. Debe rechazar socios inactivos, ejemplares que no estén disponibles y datos que no existan, con mensajes claros.

```sql
CREATE OR REPLACE PROCEDURE sp_prestar_libro (
  p_id_socio    IN NUMBER,
  p_id_ejemplar IN NUMBER
) IS
  v_activo  socio.activo%TYPE;
  v_tipo    socio.tipo%TYPE;
  v_estado  ejemplar.estado%TYPE;
  v_dias    NUMBER;
  e_no_disponible EXCEPTION;
BEGIN
  SELECT activo, tipo INTO v_activo, v_tipo
  FROM   socio
  WHERE  id_socio = p_id_socio;

  IF v_activo = 'N' THEN
    RAISE_APPLICATION_ERROR(-20001, 'El socio está inactivo');
  END IF;

  SELECT estado INTO v_estado
  FROM   ejemplar
  WHERE  id_ejemplar = p_id_ejemplar;

  IF v_estado <> 'DISPONIBLE' THEN
    RAISE e_no_disponible;
  END IF;

  IF v_tipo = 'DOCENTE' THEN
    v_dias := 30;
  ELSIF v_tipo = 'EXTERNO' THEN
    v_dias := 7;
  ELSE
    v_dias := 14;
  END IF;

  INSERT INTO prestamo (id_prestamo, id_ejemplar, id_socio, fecha_prestamo, fecha_limite)
  VALUES (seq_prestamo.NEXTVAL, p_id_ejemplar, p_id_socio, TRUNC(SYSDATE), TRUNC(SYSDATE) + v_dias);

  UPDATE ejemplar SET estado = 'PRESTADO' WHERE id_ejemplar = p_id_ejemplar;

  DBMS_OUTPUT.PUT_LINE('Préstamo registrado');
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20002, 'El socio o el ejemplar no existe');
  WHEN e_no_disponible THEN
    RAISE_APPLICATION_ERROR(-20003, 'El ejemplar no está disponible');
END;
/
```

**Prueba:**

```sql
BEGIN
  BEGIN sp_prestar_libro(4, 1004); EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE(SQLERRM); END;
  BEGIN sp_prestar_libro(7, 1002); EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE(SQLERRM); END;
  BEGIN sp_prestar_libro(4, 1010); EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE(SQLERRM); END;
  BEGIN sp_prestar_libro(4, 9999); EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE(SQLERRM); END;
  ROLLBACK;
END;
/
```

**Salida esperada:**

```text
Préstamo registrado
ORA-20001: El socio está inactivo
ORA-20003: El ejemplar no está disponible
ORA-20002: El socio o el ejemplar no existe
```

**Explicación.**

- `NO_DATA_FOUND` es una excepción **predefinida** de Oracle.
- `e_no_disponible` es una excepción **propia**: se declara, se lanza con `RAISE` y se atrapa por su nombre.
- `RAISE_APPLICATION_ERROR` crea un error con un número entre -20000 y -20999 y un mensaje propio. Quien llama lo ve en `SQLERRM`.
- El socio 7 (Sofía) está inactivo y el ejemplar 1010 está dañado; el 9999 no existe.

## 3.3 WHEN OTHERS, SQLCODE y SQLERRM

**Enunciado.** Intente registrar un socio con un documento que ya existe y muestre el código y el mensaje del error.

```sql
BEGIN
  INSERT INTO socio (id_socio, documento, nombre, tipo, fecha_registro)
  VALUES (9, '79797979', 'Pedro Gómez', 'DOCENTE', SYSDATE);
EXCEPTION
  WHEN DUP_VAL_ON_INDEX THEN
    DBMS_OUTPUT.PUT_LINE('Ya existe un socio con ese documento');
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Error ' || SQLCODE || ': ' || SQLERRM);
END;
/
```

**Salida esperada:**

```text
Ya existe un socio con ese documento
```

**Explicación.** La columna `documento` es `UNIQUE`, así que repetirla lanza `DUP_VAL_ON_INDEX`. `WHEN OTHERS` atrapa cualquier otro error; `SQLCODE` da el número y `SQLERRM` el mensaje. `WHEN OTHERS` siempre va de último.
