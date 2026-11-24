---
title: "Práctica PL/SQL 1: Sentencias de control y funciones"
description: Ejercicios propios sobre el caso Biblioteca, con IF, CASE, ciclos y funciones invocables desde SQL para calcular retrasos, multas escalonadas y permisos de préstamo.
date: 2026-11-23T12:05:00
categories: [PL/SQL, Prácticas]
tags: [Oracle, PL/SQL, Funciones, Bases de Datos 2]
---

Primera práctica de PL/SQL hecha por mi cuenta, con un caso distinto al del taller: la **biblioteca universitaria** de la [práctica de SQL](/PovedaCamyla.github.io/docs/practica-sql). La regla de negocio que se va construyendo es la de **multas escalonadas**:

| Días de retraso | Valor por día |
|---|---|
| 1 a 5 | 1.500 |
| 6 a 15 | 2.000 |
| más de 15 | 2.500 |

Todas las pruebas usan la **fecha de corte 2026-11-20** para que la salida sea reproducible.

<a href="/PovedaCamyla.github.io/evidencias/practicas/biblioteca_esquema.sql" download>Script del esquema</a> · <a href="/PovedaCamyla.github.io/evidencias/practicas/practicas_plsql_biblioteca.sql" download>Script completo de las prácticas PL/SQL</a>

## Preparación

Además del esquema de la biblioteca, las prácticas de PL/SQL usan unas secuencias y dos tablas de apoyo. El bloque inicial borra las secuencias si ya existen (por ejemplo, si se corrió la práctica de `MERGE`), para que los identificadores de la salida coincidan.

```sql
SET SERVEROUTPUT ON SIZE UNLIMITED

BEGIN
  FOR s IN (SELECT sequence_name FROM user_sequences
            WHERE sequence_name IN ('SEQ_PRESTAMO', 'SEQ_MULTA')) LOOP
    EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s.sequence_name;
  END LOOP;
END;
/

CREATE SEQUENCE seq_prestamo START WITH 19;
CREATE SEQUENCE seq_multa    START WITH 5;

CREATE TABLE log_biblioteca (
  id_log   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  fecha    TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
  origen   VARCHAR2(60)   NOT NULL,
  codigo   NUMBER,
  mensaje  VARCHAR2(4000)
);

CREATE TABLE hist_estado_ejemplar (
  id_hist          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  id_ejemplar      NUMBER(8)    NOT NULL,
  estado_anterior  VARCHAR2(12),
  estado_nuevo     VARCHAR2(12),
  usuario          VARCHAR2(128) DEFAULT USER NOT NULL,
  fecha            DATE          DEFAULT SYSDATE NOT NULL
);
```

## 1.1 Ciclos y CASE: tabla de multas

**Enunciado.** Con un bloque anónimo, imprima el valor acumulado de la multa para los días 1, 5, 10, 15 y 20 de retraso, indicando el tramo, calculándolo **día por día**. Luego, con un `WHILE`, encuentre el primer día en que la multa supera 20.000.

```sql
DECLARE
  v_acumulado  NUMBER := 0;
  v_tarifa     NUMBER;
  v_tramo      VARCHAR2(10);
  v_dia        PLS_INTEGER := 0;
BEGIN
  DBMS_OUTPUT.PUT_LINE('Día | Tramo  | Multa acumulada');
  FOR d IN 1 .. 20 LOOP
    -- CASE buscado: cada rama es una condición independiente
    CASE
      WHEN d <= 5  THEN v_tarifa := 1500; v_tramo := 'Tramo 1';
      WHEN d <= 15 THEN v_tarifa := 2000; v_tramo := 'Tramo 2';
      ELSE              v_tarifa := 2500; v_tramo := 'Tramo 3';
    END CASE;
    v_acumulado := v_acumulado + v_tarifa;

    CONTINUE WHEN MOD(d, 5) <> 0 AND d <> 1;   -- solo imprime 1, 5, 10, 15 y 20
    DBMS_OUTPUT.PUT_LINE(LPAD(d, 3) || ' | ' || v_tramo || ' | ' || v_acumulado);
  END LOOP;

  -- WHILE: no se sabe de antemano cuántas vueltas hacen falta
  v_acumulado := 0;
  WHILE v_acumulado <= 20000 LOOP
    v_dia := v_dia + 1;
    v_acumulado := v_acumulado + CASE WHEN v_dia <= 5  THEN 1500
                                      WHEN v_dia <= 15 THEN 2000
                                      ELSE 2500 END;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('La multa supera 20.000 el día ' || v_dia || ' (' || v_acumulado || ')');
END;
/
```

**Salida esperada:**

```text
Día | Tramo  | Multa acumulada
  1 | Tramo 1 | 1500
  5 | Tramo 1 | 7500
 10 | Tramo 2 | 17500
 15 | Tramo 2 | 27500
 20 | Tramo 3 | 40000
La multa supera 20.000 el día 12 (21500)
```

**Por qué así.** El `FOR` numérico se usa cuando el número de vueltas se conoce (20 días); el `WHILE`, cuando depende de una condición que se evalúa antes de cada vuelta. Dentro del ciclo se usa la **sentencia** `CASE` (ejecuta asignaciones) y en el `WHILE` la **expresión** `CASE` (devuelve un valor). El `CASE` sin `ELSE` lanzaría `CASE_NOT_FOUND` si ninguna rama aplicara; aquí el `ELSE` cubre el tramo 3.

## 1.2 FN_CALCULAR_MULTA

**Enunciado.** Cree una función que reciba los días de retraso y devuelva la multa escalonada con una **fórmula cerrada** (sin ciclos). Para cero días, negativos o `NULL` debe devolver 0. Compruebe que coincide con la tabla del punto anterior.

```sql
CREATE OR REPLACE FUNCTION fn_calcular_multa (
  p_dias IN NUMBER
) RETURN NUMBER
  DETERMINISTIC
IS
BEGIN
  RETURN CASE
           WHEN p_dias IS NULL OR p_dias <= 0 THEN 0
           WHEN p_dias <= 5  THEN 1500 * p_dias
           WHEN p_dias <= 15 THEN 7500 + 2000 * (p_dias - 5)
           ELSE                   27500 + 2500 * (p_dias - 15)
         END;
END fn_calcular_multa;
/

SELECT fn_calcular_multa(0)  AS d0,
       fn_calcular_multa(3)  AS d3,
       fn_calcular_multa(7)  AS d7,
       fn_calcular_multa(12) AS d12,
       fn_calcular_multa(20) AS d20
FROM   dual;
```

**Resultado esperado:**

| D0 | D3 | D7 | D12 | D20 |
|---|---|---|---|---|
| 0 | 4500 | 11500 | 21500 | 40000 |

**Por qué así.** Es una función y no un procedimiento porque *calcula* y no cambia datos; por eso se puede usar dentro de un `SELECT`. `DETERMINISTIC` le dice a Oracle que para la misma entrada siempre devuelve lo mismo, lo que le permite reutilizar resultados y usarla en un índice basado en función. Los valores 7.500 y 27.500 son el acumulado al terminar los tramos 1 y 2, y coinciden con la tabla del ejercicio 1.1.

## 1.3 FN_DIAS_RETRASO y uso desde SQL

**Enunciado.** Cree una función que reciba un préstamo y una fecha de corte (por defecto, hoy) y devuelva los días de retraso: si ya se devolvió, se cuenta hasta la devolución; si no, hasta la fecha de corte. Si el préstamo no existe, debe lanzar un error claro. Úsela en una consulta que compare la multa registrada con la que daría la regla escalonada.

```sql
CREATE OR REPLACE FUNCTION fn_dias_retraso (
  p_id_prestamo  IN prestamo.id_prestamo%TYPE,
  p_fecha_corte  IN DATE DEFAULT TRUNC(SYSDATE)
) RETURN NUMBER
IS
  v_limite      prestamo.fecha_limite%TYPE;
  v_devolucion  prestamo.fecha_devolucion%TYPE;
BEGIN
  SELECT fecha_limite, fecha_devolucion
  INTO   v_limite, v_devolucion
  FROM   prestamo
  WHERE  id_prestamo = p_id_prestamo;

  RETURN GREATEST(NVL(v_devolucion, p_fecha_corte) - v_limite, 0);
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20001, 'El préstamo ' || p_id_prestamo || ' no existe');
END fn_dias_retraso;
/

SELECT p.id_prestamo,
       fn_dias_retraso(p.id_prestamo, DATE '2026-11-20')                    AS dias,
       fn_calcular_multa(fn_dias_retraso(p.id_prestamo, DATE '2026-11-20')) AS multa_escalonada,
       m.valor                                                             AS multa_registrada
FROM   prestamo p
LEFT JOIN multa m ON m.id_prestamo = p.id_prestamo
WHERE  fn_dias_retraso(p.id_prestamo, DATE '2026-11-20') > 0
ORDER  BY p.id_prestamo;
```

**Resultado esperado:**

| ID_PRESTAMO | DIAS | MULTA_ESCALONADA | MULTA_REGISTRADA |
|---|---|---|---|
| 2 | 7 | 11500 | 10500 |
| 5 | 10 | 17500 | 15000 |
| 8 | 5 | 7500 | 7500 |
| 12 | 8 | 13500 | 12000 |
| 13 | 3 | 4500 | *(null)* |
| 16 | 7 | 11500 | *(null)* |
| 17 | 1 | 1500 | *(null)* |

**Por qué así.** La excepción `NO_DATA_FOUND` se traduce a un error de aplicación (-20001) con un mensaje que dice *qué* préstamo falló; el mensaje genérico de Oracle no lo diría. Una función se puede llamar desde SQL si solo recibe parámetros `IN`, devuelve un tipo SQL (no `BOOLEAN` en 19c) y no hace DML ni `COMMIT`; si lo hiciera, el `SELECT` fallaría con ORA-14551. Ojo con el costo: la consulta llama a la función por cada fila y en cada llamada hay un cambio de contexto entre SQL y PL/SQL; para tablas grandes conviene escribir el cálculo directamente en SQL.

La comparación muestra que con la regla nueva las multas de más de 5 días suben (la tabla tenía una tarifa plana de 1.500).

## 1.4 FN_PUEDE_PRESTAR

**Enunciado.** Cree una función que diga si un socio puede llevarse un libro, aplicando en orden estas reglas: el socio debe existir y estar activo, no debe tener multas sin pagar ni préstamos vencidos, y no puede superar su límite de préstamos activos (estudiante 3, docente 5, externo 1). Debe devolver `'SI'` o el motivo del rechazo, y poder usarse desde un `SELECT`.

```sql
CREATE OR REPLACE FUNCTION fn_puede_prestar (
  p_id_socio     IN socio.id_socio%TYPE,
  p_fecha_corte  IN DATE DEFAULT TRUNC(SYSDATE)
) RETURN VARCHAR2
IS
  v_tipo      socio.tipo%TYPE;
  v_activo    socio.activo%TYPE;
  v_deuda     NUMBER;
  v_vencidos  NUMBER;
  v_activos   NUMBER;
  v_limite    PLS_INTEGER;
BEGIN
  BEGIN
    SELECT tipo, activo INTO v_tipo, v_activo
    FROM   socio
    WHERE  id_socio = p_id_socio;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN 'NO: el socio no existe';
  END;

  IF v_activo = 'N' THEN
    RETURN 'NO: socio inactivo';
  END IF;

  SELECT NVL(SUM(m.valor), 0) INTO v_deuda
  FROM   multa m
  JOIN   prestamo p ON p.id_prestamo = m.id_prestamo
  WHERE  p.id_socio = p_id_socio
  AND    m.pagada   = 'N';

  SELECT COUNT(*),
         COUNT(CASE WHEN fecha_limite < p_fecha_corte THEN 1 END)
  INTO   v_activos, v_vencidos
  FROM   prestamo
  WHERE  id_socio = p_id_socio
  AND    fecha_devolucion IS NULL;

  -- CASE simple: compara un selector por igualdad
  v_limite := CASE v_tipo
                WHEN 'ESTUDIANTE' THEN 3
                WHEN 'DOCENTE'    THEN 5
                WHEN 'EXTERNO'    THEN 1
              END;

  IF v_deuda > 0 THEN
    RETURN 'NO: multas pendientes por ' || v_deuda;
  ELSIF v_vencidos > 0 THEN
    RETURN 'NO: tiene ' || v_vencidos || ' préstamo(s) vencido(s)';
  ELSIF v_activos >= v_limite THEN
    RETURN 'NO: alcanzó el límite de ' || v_limite || ' préstamos';
  END IF;

  RETURN 'SI';
END fn_puede_prestar;
/

SELECT id_socio, nombre, tipo,
       fn_puede_prestar(id_socio, DATE '2026-11-20') AS puede_prestar
FROM   socio
ORDER  BY id_socio;
```

**Resultado esperado:**

| ID_SOCIO | NOMBRE | TIPO | PUEDE_PRESTAR |
|---|---|---|---|
| 1 | Laura Méndez | ESTUDIANTE | NO: tiene 1 préstamo(s) vencido(s) |
| 2 | Andrés Rojas | ESTUDIANTE | NO: multas pendientes por 12000 |
| 3 | Paula Herrera | ESTUDIANTE | NO: multas pendientes por 15000 |
| 4 | Carlos Duarte | DOCENTE | SI |
| 5 | Marta Salazar | DOCENTE | SI |
| 6 | Diego Castillo | EXTERNO | NO: tiene 1 préstamo(s) vencido(s) |
| 7 | Sofía Pineda | ESTUDIANTE | NO: socio inactivo |
| 8 | Julián Vargas | ESTUDIANTE | SI |

**Por qué así.**

- Devuelve `VARCHAR2` y no `BOOLEAN` porque en Oracle 19c una función `BOOLEAN` no se puede usar en un `SELECT`, y además el texto le dice al usuario *por qué* no puede.
- La búsqueda del socio va en un **bloque anidado** con su propio `EXCEPTION`: así el `NO_DATA_FOUND` se convierte en una respuesta normal y no corta la consulta que llama a la función.
- Los conteos de activos y vencidos salen de **una sola consulta** con `COUNT(CASE ...)`, en vez de dos lecturas de `prestamo`.
- El orden de los `ELSIF` es el orden de las reglas: el primer motivo que aplica es el que se informa (Paula tiene una multa y también un préstamo vencido, pero se reporta la multa).
