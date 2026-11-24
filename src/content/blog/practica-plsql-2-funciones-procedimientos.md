---
title: "Práctica PL/SQL 2: Funciones y procedimientos"
description: Funciones que se usan desde un SELECT y un procedimiento que registra la devolución de un libro, sobre el caso Biblioteca.
date: 2026-11-23T12:04:00
categories: [PL/SQL, Prácticas]
tags: [Oracle, PL/SQL, Funciones, Procedimientos, Bases de Datos 2]
---

Práctica propia sobre el caso **Biblioteca**. Una **función** calcula y devuelve un valor; un **procedimiento** ejecuta una acción sobre los datos.

Antes de empezar se crean las secuencias que usan esta práctica y las siguientes:

```sql
CREATE SEQUENCE seq_prestamo START WITH 19;
CREATE SEQUENCE seq_multa    START WITH 5;
```

## 2.1 Función: días de retraso

**Enunciado.** Cree una función que reciba un préstamo y una fecha, y devuelva cuántos días de retraso tiene (0 si no tiene retraso).

```sql
CREATE OR REPLACE FUNCTION fn_dias_retraso (
  p_id_prestamo IN NUMBER,
  p_fecha       IN DATE
) RETURN NUMBER
IS
  v_limite      DATE;
  v_devolucion  DATE;
  v_dias        NUMBER;
BEGIN
  SELECT fecha_limite, fecha_devolucion
  INTO   v_limite, v_devolucion
  FROM   prestamo
  WHERE  id_prestamo = p_id_prestamo;

  IF v_devolucion IS NULL THEN
    v_dias := p_fecha - v_limite;        -- aún no lo devuelve
  ELSE
    v_dias := v_devolucion - v_limite;   -- ya lo devolvió
  END IF;

  IF v_dias < 0 THEN
    v_dias := 0;
  END IF;

  RETURN v_dias;
END;
/

SELECT id_prestamo, fn_dias_retraso(id_prestamo, DATE '2026-11-20') AS dias_retraso
FROM   prestamo
WHERE  id_prestamo IN (2, 13, 14, 16, 17);
```

**Resultado esperado:**

| ID_PRESTAMO | DIAS_RETRASO |
|---|---|
| 2 | 7 |
| 13 | 3 |
| 14 | 0 |
| 16 | 7 |
| 17 | 1 |

**Explicación.** En Oracle, restar dos fechas da el número de días entre ellas. Como la función no modifica datos, se puede usar dentro de un `SELECT`.

## 2.2 Función: total de préstamos de un socio

**Enunciado.** Cree una función que devuelva cuántos préstamos ha hecho un socio y úsela para listar a todos los socios.

```sql
CREATE OR REPLACE FUNCTION fn_total_prestamos (
  p_id_socio IN NUMBER
) RETURN NUMBER
IS
  v_total NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_total
  FROM   prestamo
  WHERE  id_socio = p_id_socio;

  RETURN v_total;
END;
/

SELECT nombre, fn_total_prestamos(id_socio) AS prestamos
FROM   socio
ORDER  BY id_socio;
```

**Resultado esperado:**

| NOMBRE | PRESTAMOS |
|---|---|
| Laura Méndez | 5 |
| Andrés Rojas | 4 |
| Paula Herrera | 3 |
| Carlos Duarte | 2 |
| Marta Salazar | 1 |
| Diego Castillo | 2 |
| Sofía Pineda | 0 |
| Julián Vargas | 1 |

## 2.3 Procedimiento: registrar una devolución

**Enunciado.** Cree un procedimiento que registre la devolución de un préstamo en una fecha: guarde la fecha de devolución, deje el ejemplar `DISPONIBLE` y, si hubo retraso, cree una multa de 1.500 por día.

```sql
CREATE OR REPLACE PROCEDURE sp_registrar_devolucion (
  p_id_prestamo IN NUMBER,
  p_fecha       IN DATE
) IS
  v_ejemplar  NUMBER;
  v_dias      NUMBER;
  v_multa     NUMBER;
BEGIN
  SELECT id_ejemplar INTO v_ejemplar
  FROM   prestamo
  WHERE  id_prestamo = p_id_prestamo;

  UPDATE prestamo SET fecha_devolucion = p_fecha WHERE id_prestamo = p_id_prestamo;
  UPDATE ejemplar SET estado = 'DISPONIBLE'     WHERE id_ejemplar = v_ejemplar;

  v_dias  := fn_dias_retraso(p_id_prestamo, p_fecha);
  v_multa := v_dias * 1500;

  IF v_multa > 0 THEN
    INSERT INTO multa (id_multa, id_prestamo, valor, pagada)
    VALUES (seq_multa.NEXTVAL, p_id_prestamo, v_multa, 'N');
    DBMS_OUTPUT.PUT_LINE('Préstamo ' || p_id_prestamo || ': ' || v_dias
                         || ' días de retraso, multa de ' || v_multa);
  ELSE
    DBMS_OUTPUT.PUT_LINE('Préstamo ' || p_id_prestamo || ': devuelto a tiempo');
  END IF;
END;
/

BEGIN
  sp_registrar_devolucion(16, DATE '2026-11-20');
  sp_registrar_devolucion(14, DATE '2026-11-20');
  ROLLBACK;   -- para dejar los datos como estaban
END;
/
```

**Salida esperada:**

```text
Préstamo 16: 7 días de retraso, multa de 10500
Préstamo 14: devuelto a tiempo
```

**Explicación.** El procedimiento reutiliza la función del ejercicio 2.1. No hace `COMMIT`: quien lo llama decide si guarda o deshace los cambios.
