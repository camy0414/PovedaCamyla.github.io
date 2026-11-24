--------------------------------------------------------------------------------
-- PRÁCTICAS PL/SQL — CASO BIBLIOTECA
-- Bases de Datos 2 — Universidad El Bosque — Camyla Poveda
-- Oracle Database. Requisito: ejecutar antes biblioteca_esquema.sql
--------------------------------------------------------------------------------

-- ============================================================================
-- PRÁCTICA PL/SQL 1: BLOQUES Y SENTENCIAS DE CONTROL
-- ============================================================================
SET SERVEROUTPUT ON

-- 1.1 Variables y SELECT INTO
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

-- 1.2 CASE dentro de un ciclo FOR
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

-- 1.3 Ciclos FOR y WHILE
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

-- ============================================================================
-- PRÁCTICA PL/SQL 2: FUNCIONES Y PROCEDIMIENTOS
-- ============================================================================
CREATE SEQUENCE seq_prestamo START WITH 19;
CREATE SEQUENCE seq_multa    START WITH 5;

-- 2.1 Función: días de retraso
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

-- 2.2 Función: total de préstamos de un socio
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

-- 2.3 Procedimiento: registrar una devolución
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

-- ============================================================================
-- PRÁCTICA PL/SQL 3: EXCEPCIONES
-- ============================================================================

-- 3.1 Excepciones predefinidas
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

-- 3.2 Procedimiento con excepciones propias
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

-- 3.2 Procedimiento con excepciones propias
BEGIN
  BEGIN sp_prestar_libro(4, 1004); EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE(SQLERRM); END;
  BEGIN sp_prestar_libro(7, 1002); EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE(SQLERRM); END;
  BEGIN sp_prestar_libro(4, 1010); EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE(SQLERRM); END;
  BEGIN sp_prestar_libro(4, 9999); EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE(SQLERRM); END;
  ROLLBACK;
END;
/

-- 3.3 WHEN OTHERS, SQLCODE y SQLERRM
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

-- ============================================================================
-- PRÁCTICA PL/SQL 4: CURSORES Y DISPARADORES
-- ============================================================================

-- 4.1 Cursor explícito
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

-- 4.2 Cursor con parámetro
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

-- 4.3 Trigger BEFORE: corregir el nombre
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

-- 4.4 Trigger AFTER: historial de cambios
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

-- ============================================================================
-- PRÁCTICA PL/SQL 5: PAQUETES
-- ============================================================================

-- 5.1 Especificación
CREATE OR REPLACE PACKAGE pkg_biblioteca IS
  c_valor_dia CONSTANT NUMBER := 1500;

  FUNCTION total_prestamos (p_id_socio NUMBER) RETURN NUMBER;
  FUNCTION calcular_multa (p_dias NUMBER) RETURN NUMBER;
  PROCEDURE mostrar_socio (p_id_socio NUMBER);
END pkg_biblioteca;
/

-- 5.2 Cuerpo
CREATE OR REPLACE PACKAGE BODY pkg_biblioteca IS

  FUNCTION total_prestamos (p_id_socio NUMBER) RETURN NUMBER IS
    v_total NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_total FROM prestamo WHERE id_socio = p_id_socio;
    RETURN v_total;
  END total_prestamos;

  FUNCTION calcular_multa (p_dias NUMBER) RETURN NUMBER IS
  BEGIN
    IF p_dias <= 0 THEN
      RETURN 0;
    END IF;
    RETURN p_dias * c_valor_dia;
  END calcular_multa;

  PROCEDURE mostrar_socio (p_id_socio NUMBER) IS
    v_nombre socio.nombre%TYPE;
    v_tipo   socio.tipo%TYPE;
  BEGIN
    SELECT nombre, tipo INTO v_nombre, v_tipo FROM socio WHERE id_socio = p_id_socio;
    DBMS_OUTPUT.PUT_LINE(v_nombre || ' (' || v_tipo || ') - '
                         || total_prestamos(p_id_socio) || ' préstamos');
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      DBMS_OUTPUT.PUT_LINE('No existe el socio ' || p_id_socio);
  END mostrar_socio;

END pkg_biblioteca;
/

-- 5.3 Uso del paquete
BEGIN
  pkg_biblioteca.mostrar_socio(1);
  pkg_biblioteca.mostrar_socio(99);
  DBMS_OUTPUT.PUT_LINE('Multa por 7 días: ' || pkg_biblioteca.calcular_multa(7));
  DBMS_OUTPUT.PUT_LINE('Valor por día: ' || pkg_biblioteca.c_valor_dia);
END;
/
