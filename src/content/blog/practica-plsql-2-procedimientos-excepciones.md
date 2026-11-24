---
title: "Práctica PL/SQL 2: Procedimientos y excepciones"
description: Procedimientos para prestar y devolver libros con validaciones, excepciones de usuario, PRAGMA EXCEPTION_INIT, RAISE_APPLICATION_ERROR y un log con transacción autónoma.
date: 2026-11-23T12:04:00
categories: [PL/SQL, Prácticas]
tags: [Oracle, PL/SQL, Procedimientos, Excepciones, Bases de Datos 2]
---

Segunda práctica propia sobre el caso **Biblioteca**. Usa las funciones de la [práctica 1](/PovedaCamyla.github.io/blog/practica-plsql-1-control-funciones) (`fn_puede_prestar`, `fn_dias_retraso` y `fn_calcular_multa`).

Catálogo de errores de esta práctica:

| Código | Significado |
|---|---|
| -20102 | El socio no puede llevar libros (motivo de `fn_puede_prestar`) |
| -20103 | El ejemplar no existe |
| -20104 | El ejemplar no está disponible |
| -20105 | Otra sesión tiene bloqueado el ejemplar |
| -20106 | El préstamo ya fue devuelto |
| -20107 | El préstamo no existe |

## 2.1 SP_LOG con transacción autónoma

**Enunciado.** Cree un procedimiento que registre un error en `log_biblioteca` y que el registro **se conserve aunque quien lo llamó haga `ROLLBACK`**.

```sql
CREATE OR REPLACE PROCEDURE sp_log (
  p_origen   IN VARCHAR2,
  p_codigo   IN NUMBER,
  p_mensaje  IN VARCHAR2
) IS
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  INSERT INTO log_biblioteca (origen, codigo, mensaje)
  VALUES (p_origen, p_codigo, SUBSTR(p_mensaje, 1, 4000));
  COMMIT;   -- confirma solo la transacción autónoma
END sp_log;
/
```

**Por qué así.** `PRAGMA AUTONOMOUS_TRANSACTION` abre una transacción independiente: su `COMMIT` guarda el registro del log sin confirmar el trabajo pendiente de quien llama. Sin ella, el `ROLLBACK` que sigue a un error borraría también la evidencia del error. Es el único procedimiento de la práctica que hace `COMMIT`, y debe hacerlo: una transacción autónoma que termina con cambios sin confirmar lanza ORA-06519.

## 2.2 SP_REGISTRAR_PRESTAMO

**Enunciado.** Cree un procedimiento que preste un ejemplar a un socio. Debe validar al socio con `fn_puede_prestar`, verificar que el ejemplar exista y esté `DISPONIBLE`, no quedarse esperando si otra sesión lo tiene bloqueado, calcular la fecha límite según el tipo de socio (estudiante 14 días, docente 30, externo 7), marcar el ejemplar como `PRESTADO` y devolver el id del préstamo. No debe hacer `COMMIT`.

```sql
CREATE OR REPLACE PROCEDURE sp_registrar_prestamo (
  p_id_socio     IN  socio.id_socio%TYPE,
  p_id_ejemplar  IN  ejemplar.id_ejemplar%TYPE,
  p_fecha        IN  DATE DEFAULT TRUNC(SYSDATE),
  p_id_prestamo  OUT prestamo.id_prestamo%TYPE
) IS
  e_no_disponible      EXCEPTION;
  e_ejemplar_ocupado   EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_ejemplar_ocupado, -54);   -- ORA-00054: recurso ocupado (NOWAIT)

  v_permiso  VARCHAR2(200);
  v_tipo     socio.tipo%TYPE;
  v_estado   ejemplar.estado%TYPE;
  v_dias     PLS_INTEGER;
BEGIN
  p_id_prestamo := NULL;

  v_permiso := fn_puede_prestar(p_id_socio, p_fecha);
  IF v_permiso <> 'SI' THEN
    RAISE_APPLICATION_ERROR(-20102, 'Socio ' || p_id_socio || ': ' || v_permiso);
  END IF;

  SELECT tipo INTO v_tipo FROM socio WHERE id_socio = p_id_socio;

  -- Bloquea el ejemplar; si otra sesión lo tiene, falla de inmediato
  SELECT estado INTO v_estado
  FROM   ejemplar
  WHERE  id_ejemplar = p_id_ejemplar
  FOR UPDATE NOWAIT;

  IF v_estado <> 'DISPONIBLE' THEN
    RAISE e_no_disponible;
  END IF;

  v_dias := CASE v_tipo WHEN 'DOCENTE' THEN 30 WHEN 'EXTERNO' THEN 7 ELSE 14 END;

  INSERT INTO prestamo (id_prestamo, id_ejemplar, id_socio, fecha_prestamo, fecha_limite)
  VALUES (seq_prestamo.NEXTVAL, p_id_ejemplar, p_id_socio, p_fecha, p_fecha + v_dias)
  RETURNING id_prestamo INTO p_id_prestamo;

  UPDATE ejemplar SET estado = 'PRESTADO' WHERE id_ejemplar = p_id_ejemplar;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    sp_log('SP_REGISTRAR_PRESTAMO', -20103, 'Ejemplar inexistente: ' || p_id_ejemplar);
    RAISE_APPLICATION_ERROR(-20103, 'El ejemplar ' || p_id_ejemplar || ' no existe');
  WHEN e_no_disponible THEN
    sp_log('SP_REGISTRAR_PRESTAMO', -20104, 'Ejemplar ' || p_id_ejemplar || ' en estado ' || v_estado);
    RAISE_APPLICATION_ERROR(-20104, 'El ejemplar ' || p_id_ejemplar
                                    || ' no está disponible (' || v_estado || ')');
  WHEN e_ejemplar_ocupado THEN
    sp_log('SP_REGISTRAR_PRESTAMO', -20105, 'Ejemplar bloqueado: ' || p_id_ejemplar);
    RAISE_APPLICATION_ERROR(-20105, 'Otra sesión está prestando el ejemplar ' || p_id_ejemplar
                                    || '. Intente de nuevo.');
  WHEN OTHERS THEN
    sp_log('SP_REGISTRAR_PRESTAMO', SQLCODE,
           SQLERRM || ' | ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
    RAISE;
END sp_registrar_prestamo;
/
```

**Por qué así.**

- Las validaciones del socio van **antes** del `NEXTVAL`: una secuencia no se devuelve con `ROLLBACK`, así que cada rechazo después de pedirla gastaría un número.
- `FOR UPDATE NOWAIT` resuelve la concurrencia: si dos bibliotecarios intentan prestar el mismo ejemplar, el segundo no queda colgado esperando, sino que recibe ORA-00054, que con `PRAGMA EXCEPTION_INIT` tiene nombre propio (`e_ejemplar_ocupado`) y se traduce a un mensaje entendible. Sin el bloqueo, ambos podrían leer `DISPONIBLE` y prestar el mismo libro.
- Hay tres familias de excepciones: **predefinida** (`NO_DATA_FOUND`), **de usuario** (`e_no_disponible`, lanzada con `RAISE`) y **asociada a un error de Oracle** (`e_ejemplar_ocupado`).
- El `-20102` lanzado en el cuerpo no tiene manejador propio, así que cae en `WHEN OTHERS`, que lo registra y lo **relanza** con `RAISE`. Un `WHEN OTHERS` que no relanza escondería el error.
- `DBMS_UTILITY.FORMAT_ERROR_BACKTRACE` guarda la línea donde ocurrió el error, que `SQLERRM` no trae.
- No hay `COMMIT`: quien llama decide si confirma el préstamo junto con otras operaciones.

## 2.3 SP_DEVOLVER_PRESTAMO

**Enunciado.** Cree un procedimiento que registre la devolución de un préstamo en una fecha dada, libere el ejemplar y, si hubo retraso, genere la multa escalonada. Debe devolver el valor de la multa (0 si no hubo) y rechazar préstamos inexistentes o ya devueltos.

```sql
CREATE OR REPLACE PROCEDURE sp_devolver_prestamo (
  p_id_prestamo  IN  prestamo.id_prestamo%TYPE,
  p_fecha        IN  DATE DEFAULT TRUNC(SYSDATE),
  p_multa        OUT NUMBER
) IS
  v_ejemplar  prestamo.id_ejemplar%TYPE;
  v_devuelto  prestamo.fecha_devolucion%TYPE;
BEGIN
  p_multa := 0;

  SELECT id_ejemplar, fecha_devolucion
  INTO   v_ejemplar, v_devuelto
  FROM   prestamo
  WHERE  id_prestamo = p_id_prestamo
  FOR UPDATE;

  IF v_devuelto IS NOT NULL THEN
    RAISE_APPLICATION_ERROR(-20106, 'El préstamo ' || p_id_prestamo
                            || ' ya fue devuelto el ' || TO_CHAR(v_devuelto, 'YYYY-MM-DD'));
  END IF;

  UPDATE prestamo SET fecha_devolucion = p_fecha WHERE id_prestamo = p_id_prestamo;
  UPDATE ejemplar SET estado = 'DISPONIBLE'     WHERE id_ejemplar = v_ejemplar;

  p_multa := fn_calcular_multa(fn_dias_retraso(p_id_prestamo, p_fecha));

  IF p_multa > 0 THEN
    INSERT INTO multa (id_multa, id_prestamo, valor, pagada)
    VALUES (seq_multa.NEXTVAL, p_id_prestamo, p_multa, 'N');
  END IF;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RAISE_APPLICATION_ERROR(-20107, 'El préstamo ' || p_id_prestamo || ' no existe');
END sp_devolver_prestamo;
/
```

**Por qué así.** El `SELECT ... FOR UPDATE` bloquea el préstamo desde la lectura: si dos personas registran la misma devolución a la vez, la segunda espera y luego ve que ya tiene fecha de devolución, en lugar de generar dos multas. La multa se calcula **después** del `UPDATE`, así `fn_dias_retraso` cuenta hasta la fecha real de devolución. Ninguna regla se repite: los días y el valor salen de las funciones de la práctica 1.

## 2.4 Prueba de los casos

**Enunciado.** En un bloque anónimo pruebe un préstamo válido, los tres tipos de rechazo, una devolución con multa y una devolución repetida. Cada caso va en su propio sub-bloque para que un error no detenga los siguientes. Al final muestre el log y deshaga todo.

```sql
DECLARE
  c_corte  CONSTANT DATE := DATE '2026-11-20';
  v_id     prestamo.id_prestamo%TYPE;
  v_multa  NUMBER;

  PROCEDURE probar_prestamo (p_caso VARCHAR2, p_socio NUMBER, p_ejemplar NUMBER) IS
  BEGIN
    sp_registrar_prestamo(p_socio, p_ejemplar, c_corte, v_id);
    DBMS_OUTPUT.PUT_LINE(p_caso || ' OK: préstamo ' || v_id);
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE(p_caso || ' ' || SQLERRM);
  END;
BEGIN
  probar_prestamo('A) Carlos, ejemplar 1004:', 4, 1004);
  probar_prestamo('B) Laura, ejemplar 1007: ', 1, 1007);
  probar_prestamo('C) Marta, ejemplar 1010: ', 5, 1010);
  probar_prestamo('D) Marta, ejemplar 9999: ', 5, 9999);

  sp_devolver_prestamo(16, c_corte, v_multa);
  DBMS_OUTPUT.PUT_LINE('E) Devolución préstamo 16: multa ' || v_multa);

  BEGIN
    sp_devolver_prestamo(16, c_corte, v_multa);
  EXCEPTION
    WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('F) ' || SQLERRM);
  END;

  ROLLBACK;

  DBMS_OUTPUT.PUT_LINE('--- log (sobrevive al ROLLBACK) ---');
  FOR r IN (SELECT codigo, mensaje FROM log_biblioteca ORDER BY id_log) LOOP
    DBMS_OUTPUT.PUT_LINE(r.codigo || ' ' || r.mensaje);
  END LOOP;
END;
/
```

**Salida esperada** (la primera vez que se ejecuta, con el log vacío):

```text
A) Carlos, ejemplar 1004: OK: préstamo 19
B) Laura, ejemplar 1007:  ORA-20102: Socio 1: NO: tiene 1 préstamo(s) vencido(s)
C) Marta, ejemplar 1010:  ORA-20104: El ejemplar 1010 no está disponible (DANADO)
D) Marta, ejemplar 9999:  ORA-20103: El ejemplar 9999 no existe
E) Devolución préstamo 16: multa 11500
F) ORA-20106: El préstamo 16 ya fue devuelto el 2026-11-20
--- log (sobrevive al ROLLBACK) ---
-20102 ORA-20102: Socio 1: NO: tiene 1 préstamo(s) vencido(s) | ORA-06512: en "<ESQUEMA>.SP_REGISTRAR_PRESTAMO", línea <n>
-20104 Ejemplar 1010 en estado DANADO
-20103 Ejemplar inexistente: 9999
```

*(El esquema, el número de línea y el idioma del backtrace dependen de la sesión.)*

**Lo que muestra la prueba.**

- Tras el `ROLLBACK` no queda ni el préstamo 19 ni la multa del préstamo 16, pero **el log sí**, porque se escribió en transacciones autónomas.
- La secuencia `seq_prestamo` ya avanzó a 20 aunque el préstamo 19 se deshizo: las secuencias no participan de la transacción.
- El procedimiento local `probar_prestamo` (declarado dentro del `DECLARE`) evita repetir el mismo `BEGIN ... EXCEPTION ... END` cuatro veces.
