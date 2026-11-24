--------------------------------------------------------------------------------
-- PRÁCTICAS PL/SQL — CASO BIBLIOTECA UNIVERSITARIA
-- Bases de Datos 2 — Universidad El Bosque
-- Autora: Camyla Poveda
-- Motor: Oracle Database 19c
--
-- Requisito: ejecutar antes biblioteca_esquema.sql
-- Ejecutar en SQL Developer con F5 (como script).
--------------------------------------------------------------------------------

--==============================================================================
-- PRÁCTICA PL/SQL 1: SENTENCIAS DE CONTROL Y FUNCIONES
--==============================================================================

-- Preparación
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

-- 1.1 Ciclos y CASE: tabla de multas
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

-- 1.2 FN_CALCULAR_MULTA
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

-- 1.3 FN_DIAS_RETRASO y uso desde SQL
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

-- 1.4 FN_PUEDE_PRESTAR
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

--==============================================================================
-- PRÁCTICA PL/SQL 2: PROCEDIMIENTOS Y EXCEPCIONES
--==============================================================================

-- 2.1 SP_LOG con transacción autónoma
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

-- 2.2 SP_REGISTRAR_PRESTAMO
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

-- 2.3 SP_DEVOLVER_PRESTAMO
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

-- 2.4 Prueba de los casos
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

--==============================================================================
-- PRÁCTICA PL/SQL 3: CURSORES Y PROCESAMIENTO MASIVO
--==============================================================================

-- 3.1 Inventario por categoría
DECLARE
  CURSOR c_categorias IS
    SELECT id_categoria, nombre
    FROM   categoria_libro
    ORDER  BY nombre;

  CURSOR c_libros (p_id_categoria categoria_libro.id_categoria%TYPE) IS
    SELECT l.titulo,
           COUNT(e.id_ejemplar)                                 AS total,
           COUNT(CASE WHEN e.estado = 'DISPONIBLE' THEN 1 END)  AS disponibles
    FROM   libro l
    LEFT JOIN ejemplar e ON e.id_libro = l.id_libro
    WHERE  l.id_categoria = p_id_categoria
    GROUP  BY l.titulo
    ORDER  BY l.titulo;

  r_cat  c_categorias%ROWTYPE;
BEGIN
  OPEN c_categorias;
  LOOP
    FETCH c_categorias INTO r_cat;
    EXIT WHEN c_categorias%NOTFOUND;

    DBMS_OUTPUT.PUT_LINE(UPPER(r_cat.nombre));
    FOR r_lib IN c_libros(r_cat.id_categoria) LOOP
      DBMS_OUTPUT.PUT_LINE('  - ' || r_lib.titulo || ': ' ||
        CASE WHEN r_lib.total = 0 THEN 'sin ejemplares'
             ELSE r_lib.disponibles || ' de ' || r_lib.total || ' disponibles'
        END);
    END LOOP;
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('Categorías recorridas: ' || c_categorias%ROWCOUNT);
  CLOSE c_categorias;
EXCEPTION
  WHEN OTHERS THEN
    IF c_categorias%ISOPEN THEN
      CLOSE c_categorias;
    END IF;
    RAISE;
END;
/

-- 3.2 Abono a multas con FOR UPDATE
CREATE OR REPLACE PROCEDURE sp_abonar_multas (
  p_id_socio  IN  socio.id_socio%TYPE,
  p_monto     IN  NUMBER,
  p_pagadas   OUT PLS_INTEGER,
  p_sobrante  OUT NUMBER
) IS
  CURSOR c_pendientes IS
    SELECT m.id_multa, m.valor
    FROM   multa m
    WHERE  m.pagada = 'N'
    AND    m.id_prestamo IN (SELECT p.id_prestamo
                             FROM   prestamo p
                             WHERE  p.id_socio = p_id_socio)
    ORDER  BY m.id_multa
    FOR UPDATE OF m.pagada;

  v_saldo    NUMBER      := p_monto;
  v_pagadas  PLS_INTEGER := 0;
BEGIN
  FOR r IN c_pendientes LOOP
    EXIT WHEN r.valor > v_saldo;

    UPDATE multa
    SET    pagada = 'S'
    WHERE  CURRENT OF c_pendientes;

    v_saldo   := v_saldo - r.valor;
    v_pagadas := v_pagadas + 1;
  END LOOP;

  p_pagadas  := v_pagadas;
  p_sobrante := v_saldo;
END sp_abonar_multas;
/

-- Prueba: Paula devuelve el préstamo 16 con retraso y luego abona 20.000
DECLARE
  v_multa     NUMBER;
  v_pagadas   PLS_INTEGER;
  v_sobrante  NUMBER;
BEGIN
  sp_devolver_prestamo(16, DATE '2026-11-20', v_multa);
  DBMS_OUTPUT.PUT_LINE('Multa por la devolución del préstamo 16: ' || v_multa);

  sp_abonar_multas(3, 20000, v_pagadas, v_sobrante);
  DBMS_OUTPUT.PUT_LINE('Multas pagadas: ' || v_pagadas || ' | Sobrante: ' || v_sobrante);

  FOR r IN (SELECT m.id_prestamo, m.valor, m.pagada
            FROM   multa m JOIN prestamo p ON p.id_prestamo = m.id_prestamo
            WHERE  p.id_socio = 3
            ORDER  BY m.id_multa) LOOP
    DBMS_OUTPUT.PUT_LINE('Préstamo ' || r.id_prestamo || ': ' || r.valor || ' pagada=' || r.pagada);
  END LOOP;

  ROLLBACK;
END;
/

-- 3.3 Historial de un socio con SYS_REFCURSOR
CREATE OR REPLACE FUNCTION fn_historial_socio (
  p_id_socio IN socio.id_socio%TYPE
) RETURN SYS_REFCURSOR
IS
  v_cur SYS_REFCURSOR;
BEGIN
  OPEN v_cur FOR
    SELECT p.id_prestamo, l.titulo, p.fecha_prestamo, p.fecha_limite, p.fecha_devolucion
    FROM   prestamo p
    JOIN   ejemplar e ON e.id_ejemplar = p.id_ejemplar
    JOIN   libro l    ON l.id_libro    = e.id_libro
    WHERE  p.id_socio = p_id_socio
    ORDER  BY p.fecha_prestamo;
  RETURN v_cur;
END fn_historial_socio;
/

DECLARE
  v_cur     SYS_REFCURSOR;
  v_id      prestamo.id_prestamo%TYPE;
  v_titulo  libro.titulo%TYPE;
  v_fp      DATE;
  v_fl      DATE;
  v_fd      DATE;
  v_estado  VARCHAR2(30);
BEGIN
  v_cur := fn_historial_socio(1);   -- Laura Méndez
  LOOP
    FETCH v_cur INTO v_id, v_titulo, v_fp, v_fl, v_fd;
    EXIT WHEN v_cur%NOTFOUND;

    v_estado := CASE
                  WHEN v_fd IS NULL AND v_fl < DATE '2026-11-20' THEN 'PENDIENTE (vencido)'
                  WHEN v_fd IS NULL                              THEN 'PENDIENTE'
                  WHEN v_fd > v_fl                               THEN 'devuelto tarde'
                  ELSE                                                'devuelto a tiempo'
                END;
    DBMS_OUTPUT.PUT_LINE(TO_CHAR(v_fp, 'YYYY-MM-DD') || ' | '
                         || RPAD(v_titulo, 30) || ' | ' || v_estado);
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('Préstamos: ' || v_cur%ROWCOUNT);
  CLOSE v_cur;
END;
/

-- 3.4 Generación masiva de multas con BULK COLLECT y FORALL
CREATE OR REPLACE PROCEDURE sp_generar_multas (
  p_fecha_corte  IN  DATE DEFAULT TRUNC(SYSDATE),
  p_generadas    OUT PLS_INTEGER
) IS
  CURSOR c_vencidos IS
    SELECT p.id_prestamo,
           fn_calcular_multa(p_fecha_corte - p.fecha_limite) AS valor
    FROM   prestamo p
    WHERE  p.fecha_devolucion IS NULL
    AND    p.fecha_limite < p_fecha_corte
    AND    NOT EXISTS (SELECT 1 FROM multa m WHERE m.id_prestamo = p.id_prestamo);

  TYPE t_ids     IS TABLE OF prestamo.id_prestamo%TYPE;
  TYPE t_valores IS TABLE OF multa.valor%TYPE;
  v_ids      t_ids;
  v_valores  t_valores;
  v_total    PLS_INTEGER := 0;

  e_errores_bulk EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_errores_bulk, -24381);
BEGIN
  OPEN c_vencidos;
  LOOP
    FETCH c_vencidos BULK COLLECT INTO v_ids, v_valores LIMIT 100;
    EXIT WHEN v_ids.COUNT = 0;

    BEGIN
      FORALL i IN 1 .. v_ids.COUNT SAVE EXCEPTIONS
        INSERT INTO multa (id_multa, id_prestamo, valor, pagada)
        VALUES (seq_multa.NEXTVAL, v_ids(i), v_valores(i), 'N');
      v_total := v_total + v_ids.COUNT;
    EXCEPTION
      WHEN e_errores_bulk THEN
        v_total := v_total + v_ids.COUNT - SQL%BULK_EXCEPTIONS.COUNT;
        FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
          sp_log('SP_GENERAR_MULTAS',
                 -SQL%BULK_EXCEPTIONS(j).ERROR_CODE,
                 'Préstamo ' || v_ids(SQL%BULK_EXCEPTIONS(j).ERROR_INDEX) || ': '
                 || SQLERRM(-SQL%BULK_EXCEPTIONS(j).ERROR_CODE));
        END LOOP;
    END;
  END LOOP;
  CLOSE c_vencidos;

  p_generadas := v_total;
EXCEPTION
  WHEN OTHERS THEN
    IF c_vencidos%ISOPEN THEN
      CLOSE c_vencidos;
    END IF;
    RAISE;
END sp_generar_multas;
/

DECLARE
  v_n PLS_INTEGER;
BEGIN
  sp_generar_multas(DATE '2026-11-20', v_n);
  DBMS_OUTPUT.PUT_LINE('Primera ejecución, multas generadas: ' || v_n);

  sp_generar_multas(DATE '2026-11-20', v_n);
  DBMS_OUTPUT.PUT_LINE('Segunda ejecución, multas generadas: ' || v_n);

  FOR r IN (SELECT id_prestamo, valor FROM multa
            WHERE  id_prestamo IN (13, 16, 17) ORDER BY id_prestamo) LOOP
    DBMS_OUTPUT.PUT_LINE('Préstamo ' || r.id_prestamo || ': ' || r.valor);
  END LOOP;

  ROLLBACK;
END;
/

--==============================================================================
-- PRÁCTICA PL/SQL 4: DISPARADORES
--==============================================================================

-- 4.1 Valores derivados al insertar un préstamo
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

-- 4.2 Historial de cambios de estado
CREATE OR REPLACE TRIGGER trg_ejemplar_au_estado
AFTER UPDATE OF estado ON ejemplar
FOR EACH ROW
WHEN (NEW.estado <> OLD.estado)
BEGIN
  INSERT INTO hist_estado_ejemplar (id_ejemplar, estado_anterior, estado_nuevo)
  VALUES (:OLD.id_ejemplar, :OLD.estado, :NEW.estado);
END trg_ejemplar_au_estado;
/

-- Primer intento (incorrecto)
-- (Ejemplo del error de tabla mutante: se deja comentado)
-- CREATE OR REPLACE TRIGGER trg_prestamo_limite_fila
-- AFTER INSERT ON prestamo
-- FOR EACH ROW
-- DECLARE
--   v_activos NUMBER;
-- BEGIN
--   SELECT COUNT(*) INTO v_activos
--   FROM   prestamo                       -- la misma tabla que se está modificando
--   WHERE  id_socio = :NEW.id_socio
--   AND    fecha_devolucion IS NULL;
-- END;
-- /

-- INSERT INTO prestamo (id_ejemplar, id_socio, fecha_prestamo)
-- SELECT id_ejemplar, 8, DATE '2026-11-20'
-- FROM   ejemplar
-- WHERE  id_ejemplar IN (1013, 1014);

-- Primer intento (incorrecto)
-- (Ejemplo del error de tabla mutante: se deja comentado)
-- DROP TRIGGER trg_prestamo_limite_fila;

-- Solución con disparador compuesto
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

-- 4.4 Prueba de los disparadores
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

-- Consultar los disparadores en el diccionario
SELECT trigger_name, trigger_type, triggering_event, table_name, status
FROM   user_triggers
WHERE  table_name IN ('PRESTAMO', 'EJEMPLAR')
ORDER  BY table_name, trigger_name;

--==============================================================================
-- PRÁCTICA PL/SQL 5: PAQUETE PKG_BIBLIOTECA
--==============================================================================

-- 5.1 Especificación
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

-- 5.2 Cuerpo
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

-- 5.3 Prueba del paquete
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

-- 5.4 El paquete en el diccionario
SELECT object_name, object_type, status
FROM   user_objects
WHERE  object_name = 'PKG_BIBLIOTECA';

SELECT procedure_name, overload
FROM   user_procedures
WHERE  object_name = 'PKG_BIBLIOTECA'
ORDER  BY procedure_name, overload;
