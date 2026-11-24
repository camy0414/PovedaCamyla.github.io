---
title: "Práctica PL/SQL 5: Paquete PKG_BIBLIOTECA"
description: Paquete con especificación y cuerpo, constantes y excepciones públicas, subprogramas privados, sobrecarga, estado de sesión y bloque de inicialización.
date: 2026-11-23T12:01:00
categories: [PL/SQL, Prácticas]
tags: [Oracle, PL/SQL, Paquetes, Bases de Datos 2]
---

Última práctica propia sobre el caso **Biblioteca**: reunir la operación de préstamos en un paquete. La **especificación** es el contrato (lo que otros pueden usar) y el **cuerpo** es la implementación (que se puede cambiar sin romper a quien llama).

| Elemento | Dónde | Visibilidad |
|---|---|---|
| `c_dias_*` (plazos) | Especificación | Pública |
| `e_no_puede_prestar`, `e_no_disponible` | Especificación | Pública |
| `prestar`, `devolver` | Especificación | Pública |
| `prestamos_activos` (dos versiones) | Especificación | Pública, sobrecargada |
| `dias_plazo` | Solo en el cuerpo | Privada |
| `g_operaciones` | Solo en el cuerpo | Privada, estado de sesión |

El paquete reutiliza `fn_puede_prestar` y `fn_calcular_multa` de la [práctica 1](/PovedaCamyla.github.io/blog/practica-plsql-1-control-funciones).

## 5.1 Especificación

```sql
CREATE OR REPLACE PACKAGE pkg_biblioteca IS

  -- Plazos de préstamo por tipo de socio (días)
  c_dias_estudiante  CONSTANT PLS_INTEGER := 14;
  c_dias_docente     CONSTANT PLS_INTEGER := 30;
  c_dias_externo     CONSTANT PLS_INTEGER := 7;

  -- Excepciones con número fijo: quien llama puede atraparlas por nombre
  e_no_puede_prestar  EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_no_puede_prestar, -20102);

  e_no_disponible     EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_no_disponible, -20104);

  PROCEDURE prestar (
    p_id_socio     IN  NUMBER,
    p_id_ejemplar  IN  NUMBER,
    p_fecha        IN  DATE DEFAULT TRUNC(SYSDATE),
    p_id_prestamo  OUT NUMBER
  );

  PROCEDURE devolver (
    p_id_prestamo  IN  NUMBER,
    p_fecha        IN  DATE DEFAULT TRUNC(SYSDATE),
    p_multa        OUT NUMBER
  );

  -- Sobrecarga: mismo nombre, distinto tipo de parámetro
  FUNCTION prestamos_activos (p_id_socio  IN NUMBER)   RETURN NUMBER;
  FUNCTION prestamos_activos (p_documento IN VARCHAR2) RETURN NUMBER;

  FUNCTION operaciones_sesion RETURN PLS_INTEGER;

END pkg_biblioteca;
/
```

## 5.2 Cuerpo

```sql
CREATE OR REPLACE PACKAGE BODY pkg_biblioteca IS

  -- Estado privado: vive mientras dure la sesión
  g_operaciones  PLS_INTEGER;

  -- Subprograma privado: no aparece en la especificación
  FUNCTION dias_plazo (p_tipo IN socio.tipo%TYPE) RETURN PLS_INTEGER IS
  BEGIN
    RETURN CASE p_tipo
             WHEN 'DOCENTE' THEN c_dias_docente
             WHEN 'EXTERNO' THEN c_dias_externo
             ELSE                c_dias_estudiante
           END;
  END dias_plazo;

  PROCEDURE prestar (
    p_id_socio     IN  NUMBER,
    p_id_ejemplar  IN  NUMBER,
    p_fecha        IN  DATE DEFAULT TRUNC(SYSDATE),
    p_id_prestamo  OUT NUMBER
  ) IS
    v_permiso  VARCHAR2(200);
    v_tipo     socio.tipo%TYPE;
    v_estado   ejemplar.estado%TYPE;
  BEGIN
    v_permiso := fn_puede_prestar(p_id_socio, p_fecha);
    IF v_permiso <> 'SI' THEN
      RAISE_APPLICATION_ERROR(-20102, 'Socio ' || p_id_socio || ': ' || v_permiso);
    END IF;

    SELECT tipo INTO v_tipo FROM socio WHERE id_socio = p_id_socio;

    BEGIN
      SELECT estado INTO v_estado
      FROM   ejemplar
      WHERE  id_ejemplar = p_id_ejemplar
      FOR UPDATE WAIT 5;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20103, 'El ejemplar ' || p_id_ejemplar || ' no existe');
    END;

    IF v_estado <> 'DISPONIBLE' THEN
      RAISE_APPLICATION_ERROR(-20104, 'El ejemplar ' || p_id_ejemplar
                                      || ' no está disponible (' || v_estado || ')');
    END IF;

    INSERT INTO prestamo (id_prestamo, id_ejemplar, id_socio, fecha_prestamo, fecha_limite)
    VALUES (seq_prestamo.NEXTVAL, p_id_ejemplar, p_id_socio, p_fecha, p_fecha + dias_plazo(v_tipo))
    RETURNING id_prestamo INTO p_id_prestamo;

    UPDATE ejemplar SET estado = 'PRESTADO' WHERE id_ejemplar = p_id_ejemplar;

    g_operaciones := g_operaciones + 1;
  END prestar;

  PROCEDURE devolver (
    p_id_prestamo  IN  NUMBER,
    p_fecha        IN  DATE DEFAULT TRUNC(SYSDATE),
    p_multa        OUT NUMBER
  ) IS
    v_ejemplar  prestamo.id_ejemplar%TYPE;
    v_limite    prestamo.fecha_limite%TYPE;
    v_devuelto  prestamo.fecha_devolucion%TYPE;
  BEGIN
    SELECT id_ejemplar, fecha_limite, fecha_devolucion
    INTO   v_ejemplar, v_limite, v_devuelto
    FROM   prestamo
    WHERE  id_prestamo = p_id_prestamo
    FOR UPDATE;

    IF v_devuelto IS NOT NULL THEN
      RAISE_APPLICATION_ERROR(-20106, 'El préstamo ' || p_id_prestamo || ' ya fue devuelto');
    END IF;

    UPDATE prestamo SET fecha_devolucion = p_fecha WHERE id_prestamo = p_id_prestamo;
    UPDATE ejemplar SET estado = 'DISPONIBLE'     WHERE id_ejemplar = v_ejemplar;

    p_multa := fn_calcular_multa(p_fecha - v_limite);
    IF p_multa > 0 THEN
      INSERT INTO multa (id_multa, id_prestamo, valor, pagada)
      VALUES (seq_multa.NEXTVAL, p_id_prestamo, p_multa, 'N');
    END IF;

    g_operaciones := g_operaciones + 1;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20107, 'El préstamo ' || p_id_prestamo || ' no existe');
  END devolver;

  FUNCTION prestamos_activos (p_id_socio IN NUMBER) RETURN NUMBER IS
    v_total NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_total
    FROM   prestamo
    WHERE  id_socio = p_id_socio
    AND    fecha_devolucion IS NULL;
    RETURN v_total;
  END prestamos_activos;

  FUNCTION prestamos_activos (p_documento IN VARCHAR2) RETURN NUMBER IS
    v_id socio.id_socio%TYPE;
  BEGIN
    SELECT id_socio INTO v_id FROM socio WHERE documento = p_documento;
    RETURN prestamos_activos(v_id);          -- reutiliza la otra versión
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20108, 'No hay socio con documento ' || p_documento);
  END prestamos_activos;

  FUNCTION operaciones_sesion RETURN PLS_INTEGER IS
  BEGIN
    RETURN g_operaciones;
  END operaciones_sesion;

-- Bloque de inicialización: corre una sola vez por sesión,
-- la primera vez que se usa el paquete
BEGIN
  g_operaciones := 0;
END pkg_biblioteca;
/
```

## 5.3 Prueba del paquete

```sql
DECLARE
  v_id     NUMBER;
  v_multa  NUMBER;
BEGIN
  -- Sobrecarga: Oracle elige la versión por el tipo del argumento
  DBMS_OUTPUT.PUT_LINE('Carlos por id:        ' || pkg_biblioteca.prestamos_activos(4));
  DBMS_OUTPUT.PUT_LINE('Carlos por documento: ' || pkg_biblioteca.prestamos_activos('79797979'));

  -- Notación por nombre
  pkg_biblioteca.prestar(p_id_socio    => 5,
                         p_id_ejemplar => 1004,
                         p_fecha       => DATE '2026-11-20',
                         p_id_prestamo => v_id);
  DBMS_OUTPUT.PUT_LINE('Marta presta el 1004. Activos de Marta: '
                       || pkg_biblioteca.prestamos_activos(5));

  -- Excepciones públicas atrapadas por nombre
  BEGIN
    pkg_biblioteca.prestar(1, 1007, DATE '2026-11-20', v_id);
  EXCEPTION
    WHEN pkg_biblioteca.e_no_puede_prestar THEN
      DBMS_OUTPUT.PUT_LINE('e_no_puede_prestar -> ' || SQLERRM);
  END;

  BEGIN
    pkg_biblioteca.prestar(4, 1004, DATE '2026-11-20', v_id);   -- ya lo tiene Marta
  EXCEPTION
    WHEN pkg_biblioteca.e_no_disponible THEN
      DBMS_OUTPUT.PUT_LINE('e_no_disponible    -> ' || SQLERRM);
  END;

  pkg_biblioteca.devolver(13, DATE '2026-11-20', v_multa);
  DBMS_OUTPUT.PUT_LINE('Laura devuelve el préstamo 13 con multa de ' || v_multa);

  DBMS_OUTPUT.PUT_LINE('Operaciones en la sesión: ' || pkg_biblioteca.operaciones_sesion);
  ROLLBACK;
  DBMS_OUTPUT.PUT_LINE('Después del ROLLBACK:     ' || pkg_biblioteca.operaciones_sesion);
END;
/
```

**Salida esperada** (en una sesión donde el paquete no se había usado):

```text
Carlos por id:        1
Carlos por documento: 1
Marta presta el 1004. Activos de Marta: 1
e_no_puede_prestar -> ORA-20102: Socio 1: NO: tiene 1 préstamo(s) vencido(s)
e_no_disponible    -> ORA-20104: El ejemplar 1004 no está disponible (PRESTADO)
Laura devuelve el préstamo 13 con multa de 4500
Operaciones en la sesión: 2
Después del ROLLBACK:     2
```

**Lo que muestra la prueba.**

- **Sobrecarga:** `prestamos_activos(4)` y `prestamos_activos('79797979')` llaman a funciones distintas con el mismo nombre. Funciona porque `NUMBER` y `VARCHAR2` son familias de tipos diferentes; dos versiones que solo difirieran entre `NUMBER` e `INTEGER` serían ambiguas.
- **Excepciones públicas:** quien llama escribe `WHEN pkg_biblioteca.e_no_disponible` en lugar de comparar `SQLCODE = -20104`. El número queda definido en un solo lugar.
- **Estado de sesión:** el contador sigue en 2 después del `ROLLBACK`. Las variables de paquete no son transaccionales y cada sesión tiene su propia copia; otra sesión vería 0.
- **Privado:** `dias_plazo` no se puede llamar desde fuera (`pkg_biblioteca.dias_plazo` daría PLS-00302). Se puede cambiar o eliminar sin afectar a nadie.
- Si se cambia solo el **cuerpo**, los programas que usan el paquete no se invalidan; si se cambia la **especificación**, sí.

## 5.4 El paquete en el diccionario

```sql
SELECT object_name, object_type, status
FROM   user_objects
WHERE  object_name = 'PKG_BIBLIOTECA';

SELECT procedure_name, overload
FROM   user_procedures
WHERE  object_name = 'PKG_BIBLIOTECA'
ORDER  BY procedure_name, overload;
```

La segunda consulta muestra `PRESTAMOS_ACTIVOS` dos veces, con `OVERLOAD` 1 y 2.
