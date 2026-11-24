---
title: "Práctica PL/SQL 4: Disparadores"
description: Disparadores BEFORE y AFTER de fila, cláusula WHEN, historial de cambios, el error de tabla mutante (ORA-04091) y su solución con un disparador compuesto.
date: 2026-11-23T12:02:00
categories: [PL/SQL, Prácticas]
tags: [Oracle, PL/SQL, Triggers, Bases de Datos 2]
---

Cuarta práctica propia sobre el caso **Biblioteca**. Antes de escribir cada disparador me hice la pregunta de la clase: *¿esto se puede resolver de forma declarativa?* (`DEFAULT`, `CHECK`, `UNIQUE`, columna virtual). Solo si la respuesta es no, va un disparador.

| Disparador | Momento | Por qué no basta algo declarativo |
|---|---|---|
| `trg_prestamo_bi` | `BEFORE INSERT`, fila | La fecha límite depende del tipo de socio, que está en otra tabla |
| `trg_ejemplar_au_estado` | `AFTER UPDATE`, fila | Hay que escribir en otra tabla (historial) |
| `trg_prestamo_limite` | Compuesto | La regla mira otras filas de la misma tabla |

## 4.1 Valores derivados al insertar un préstamo

**Enunciado.** Cree un disparador que, al insertar un préstamo, asigne el id desde `seq_prestamo` si viene vacío, ponga la fecha de hoy si no se indicó fecha de préstamo y calcule la fecha límite según el tipo de socio si no se indicó.

```sql
CREATE OR REPLACE TRIGGER trg_prestamo_bi
BEFORE INSERT ON prestamo
FOR EACH ROW
DECLARE
  v_tipo socio.tipo%TYPE;
BEGIN
  IF :NEW.id_prestamo IS NULL THEN
    :NEW.id_prestamo := seq_prestamo.NEXTVAL;
  END IF;

  :NEW.fecha_prestamo := NVL(:NEW.fecha_prestamo, TRUNC(SYSDATE));

  IF :NEW.fecha_limite IS NULL THEN
    SELECT tipo INTO v_tipo FROM socio WHERE id_socio = :NEW.id_socio;
    :NEW.fecha_limite := :NEW.fecha_prestamo
                         + CASE v_tipo WHEN 'DOCENTE' THEN 30
                                       WHEN 'EXTERNO' THEN 7
                                       ELSE 14 END;
  END IF;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20201, 'No existe el socio ' || :NEW.id_socio);
END trg_prestamo_bi;
/
```

**Por qué así.** Modificar `:NEW` solo tiene efecto en un disparador `BEFORE` de fila: en un `AFTER` la fila ya se escribió. Las restricciones `NOT NULL` se verifican **después** de los disparadores `BEFORE`, por eso el disparador alcanza a llenar `fecha_prestamo` y `fecha_limite` antes de que Oracle las rechace. Si el valor llega desde la aplicación (como lo hace `sp_registrar_prestamo`), se respeta. La fecha límite no puede ser un `DEFAULT` porque un `DEFAULT` no puede consultar otra tabla.

## 4.2 Historial de cambios de estado

**Enunciado.** Registre en `hist_estado_ejemplar` cada cambio de estado de un ejemplar, pero solo cuando el estado realmente cambie, resolviendo esa condición **fuera** del cuerpo del disparador.

```sql
CREATE OR REPLACE TRIGGER trg_ejemplar_au_estado
AFTER UPDATE OF estado ON ejemplar
FOR EACH ROW
WHEN (NEW.estado <> OLD.estado)
BEGIN
  INSERT INTO hist_estado_ejemplar (id_ejemplar, estado_anterior, estado_nuevo)
  VALUES (:OLD.id_ejemplar, :OLD.estado, :NEW.estado);
END trg_ejemplar_au_estado;
/
```

**Por qué así.** Con `WHEN`, Oracle evalúa la condición antes de ejecutar el cuerpo; si no se cumple, el disparador ni siquiera corre. Con un `IF` adentro, el cuerpo se ejecutaría siempre. En la cláusula `WHEN` se escribe `NEW` y `OLD` **sin dos puntos**; en el cuerpo, con dos puntos. `UPDATE OF estado` hace que el disparador no se active si se actualizan otras columnas. Las columnas `usuario` y `fecha` se llenan con sus `DEFAULT`.

## 4.3 Límite de préstamos: el problema de la tabla mutante

**Enunciado.** Un socio no puede tener más préstamos activos que su límite (estudiante 3, docente 5, externo 1), sin importar por dónde se inserte el préstamo. Primero intente resolverlo con un disparador de fila y observe el error; luego resuélvalo con un disparador compuesto.

### Primer intento (incorrecto)

```sql
CREATE OR REPLACE TRIGGER trg_prestamo_limite_fila
AFTER INSERT ON prestamo
FOR EACH ROW
DECLARE
  v_activos NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_activos
  FROM   prestamo                       -- la misma tabla que se está modificando
  WHERE  id_socio = :NEW.id_socio
  AND    fecha_devolucion IS NULL;
END;
/

INSERT INTO prestamo (id_ejemplar, id_socio, fecha_prestamo)
SELECT id_ejemplar, 8, DATE '2026-11-20'
FROM   ejemplar
WHERE  id_ejemplar IN (1013, 1014);
```

```text
ORA-04091: la tabla <ESQUEMA>.PRESTAMO está mutando, puede que el disparador/la función no puedan verla
ORA-06512: en "<ESQUEMA>.TRG_PRESTAMO_LIMITE_FILA", línea <n>
ORA-04088: error durante la ejecución del disparador '<ESQUEMA>.TRG_PRESTAMO_LIMITE_FILA'
```

```sql
DROP TRIGGER trg_prestamo_limite_fila;
```

Un disparador de fila no puede consultar la tabla que la sentencia está modificando: a mitad de la sentencia, la tabla está en un estado intermedio (algunas filas insertadas, otras no) y el conteo no sería confiable. Por eso se prueba con un `INSERT ... SELECT` de varias filas, que es donde el problema se ve siempre.

### Solución con disparador compuesto

```sql
CREATE OR REPLACE TRIGGER trg_prestamo_limite
FOR INSERT ON prestamo
COMPOUND TRIGGER

  TYPE t_socios IS TABLE OF BOOLEAN INDEX BY PLS_INTEGER;
  g_socios t_socios;

  BEFORE STATEMENT IS
  BEGIN
    g_socios.DELETE;
  END BEFORE STATEMENT;

  AFTER EACH ROW IS
  BEGIN
    g_socios(:NEW.id_socio) := TRUE;      -- solo anota qué socios revisar
  END AFTER EACH ROW;

  AFTER STATEMENT IS
    v_id       PLS_INTEGER;
    v_tipo     socio.tipo%TYPE;
    v_activos  NUMBER;
    v_limite   PLS_INTEGER;
  BEGIN
    v_id := g_socios.FIRST;
    WHILE v_id IS NOT NULL LOOP
      SELECT s.tipo, COUNT(p.id_prestamo)
      INTO   v_tipo, v_activos
      FROM   socio s
      LEFT JOIN prestamo p
             ON p.id_socio = s.id_socio
            AND p.fecha_devolucion IS NULL
      WHERE  s.id_socio = v_id
      GROUP  BY s.tipo;

      v_limite := CASE v_tipo WHEN 'DOCENTE' THEN 5 WHEN 'EXTERNO' THEN 1 ELSE 3 END;

      IF v_activos > v_limite THEN
        RAISE_APPLICATION_ERROR(-20202, 'El socio ' || v_id || ' quedaría con '
                                || v_activos || ' préstamos activos y su límite es ' || v_limite);
      END IF;

      v_id := g_socios.NEXT(v_id);
    END LOOP;
  END AFTER STATEMENT;

END trg_prestamo_limite;
/
```

**Por qué así.** El disparador compuesto tiene varias secciones que comparten variables durante **una misma sentencia**. En `AFTER EACH ROW` no se consulta `prestamo`, solo se anota el socio en una colección indexada por su id (si el mismo socio aparece en varias filas, queda una sola vez). En `AFTER STATEMENT` la sentencia ya terminó, la tabla dejó de estar mutando y se puede contar. Si un socio se pasa del límite, el error deshace **toda** la sentencia. `BEFORE STATEMENT` limpia la colección por si quedó algo de una sentencia anterior que falló.

Este disparador repite una regla que ya valida `fn_puede_prestar`. No sobra: el procedimiento protege el camino normal, y el disparador protege la tabla de cualquier `INSERT` que no pase por el procedimiento.

## 4.4 Prueba de los disparadores

```sql
DECLARE
  v_lim DATE;
BEGIN
  -- A) Inserción mínima: el disparador completa id, fecha y fecha límite
  INSERT INTO prestamo (id_ejemplar, id_socio, fecha_prestamo)
  VALUES (1008, 5, DATE '2026-11-20')
  RETURNING fecha_limite INTO v_lim;
  DBMS_OUTPUT.PUT_LINE('A) Marta (docente), fecha límite: ' || TO_CHAR(v_lim, 'YYYY-MM-DD'));

  -- Historial: un cambio real y una actualización al mismo valor
  UPDATE ejemplar SET estado = 'PRESTADO' WHERE id_ejemplar = 1008;
  UPDATE ejemplar SET estado = 'PRESTADO' WHERE id_ejemplar = 1009;   -- ya estaba PRESTADO
  FOR h IN (SELECT id_ejemplar, estado_anterior, estado_nuevo FROM hist_estado_ejemplar) LOOP
    DBMS_OUTPUT.PUT_LINE('   historial: ' || h.id_ejemplar || ' '
                         || h.estado_anterior || ' -> ' || h.estado_nuevo);
  END LOOP;

  -- B) Julián (estudiante, 1 activo) recibe 2 más en una sola sentencia: queda en 3
  INSERT INTO prestamo (id_ejemplar, id_socio, fecha_prestamo)
  SELECT id_ejemplar, 8, DATE '2026-11-20'
  FROM   ejemplar WHERE id_ejemplar IN (1013, 1014);
  DBMS_OUTPUT.PUT_LINE('B) Julián: ' || SQL%ROWCOUNT || ' préstamos insertados');

  -- C) Un cuarto préstamo para Julián
  BEGIN
    INSERT INTO prestamo (id_ejemplar, id_socio, fecha_prestamo)
    VALUES (1016, 8, DATE '2026-11-20');
  EXCEPTION
    WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('C) ' || SQLERRM);
  END;

  -- D) Diego (externo) ya tiene 1 préstamo
  BEGIN
    INSERT INTO prestamo (id_ejemplar, id_socio, fecha_prestamo)
    VALUES (1015, 6, DATE '2026-11-20');
  EXCEPTION
    WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('D) ' || SQLERRM);
  END;

  ROLLBACK;
END;
/
```

**Salida esperada** (con `hist_estado_ejemplar` vacía al empezar):

```text
A) Marta (docente), fecha límite: 2026-12-20
   historial: 1008 DISPONIBLE -> PRESTADO
B) Julián: 2 préstamos insertados
C) ORA-20202: El socio 8 quedaría con 4 préstamos activos y su límite es 3
D) ORA-20202: El socio 6 quedaría con 2 préstamos activos y su límite es 1
```

La actualización del ejemplar 1009 no deja historial porque el estado no cambió, y los casos C y D no insertan nada: el error en `AFTER STATEMENT` deshace la sentencia completa, mientras lo hecho en A y B sigue en la transacción hasta el `ROLLBACK` final.

## Consultar los disparadores en el diccionario

```sql
SELECT trigger_name, trigger_type, triggering_event, table_name, status
FROM   user_triggers
WHERE  table_name IN ('PRESTAMO', 'EJEMPLAR')
ORDER  BY table_name, trigger_name;
```
