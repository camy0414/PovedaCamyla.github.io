---
title: "Práctica PL/SQL 3: Cursores y procesamiento masivo"
description: Cursores explícitos y parametrizados, FOR UPDATE con WHERE CURRENT OF, SYS_REFCURSOR y BULK COLLECT con FORALL y SAVE EXCEPTIONS sobre el caso Biblioteca.
date: 2026-11-23T12:03:00
categories: [PL/SQL, Prácticas]
tags: [Oracle, PL/SQL, Cursores, Bases de Datos 2]
---

Tercera práctica propia sobre el caso **Biblioteca**. Reutiliza `fn_calcular_multa` ([práctica 1](/PovedaCamyla.github.io/blog/practica-plsql-1-control-funciones)) y `sp_devolver_prestamo` y `sp_log` ([práctica 2](/PovedaCamyla.github.io/blog/practica-plsql-2-procedimientos-excepciones)).

| Ejercicio | Tipo de cursor | Para qué sirve |
|---|---|---|
| 3.1 | Explícito + parametrizado | Reporte jerárquico categoría → libros |
| 3.2 | `FOR UPDATE` + `WHERE CURRENT OF` | Modificar las filas que se van leyendo |
| 3.3 | `SYS_REFCURSOR` | Devolver un resultado a otro programa |
| 3.4 | `BULK COLLECT` + `FORALL` | Procesar muchas filas con pocos cambios de contexto |

## 3.1 Inventario por categoría

**Enunciado.** Imprima, para cada categoría, sus libros con cuántos ejemplares están disponibles. Recorra las categorías con un cursor **explícito** (`OPEN`, `FETCH`, `CLOSE`) y los libros con un cursor **parametrizado** que reciba la categoría. Al final, muestre cuántas categorías se recorrieron.

```sql
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
```

**Salida esperada:**

```text
BASES DE DATOS
  - Fundamentos de bases de datos: 1 de 3 disponibles
  - Sistemas de bases de datos: 1 de 2 disponibles
LITERATURA
  - Cien años de soledad: 1 de 2 disponibles
  - El amor en los tiempos del cólera: 1 de 1 disponibles
MATEMÁTICAS
  - Introducción al álgebra lineal: sin ejemplares
  - Precálculo: 2 de 2 disponibles
PROGRAMACIÓN
  - Arquitectura limpia: 1 de 1 disponibles
  - Código limpio: 1 de 2 disponibles
  - Sistemas operativos modernos: 1 de 1 disponibles
REDES
  - Redes de computadoras: 0 de 2 disponibles
Categorías recorridas: 5
```

**Por qué así.** El cursor externo es explícito porque se necesita `%ROWCOUNT` al final, y ese atributo solo existe mientras el cursor está abierto. El interno usa `FOR ... IN cursor(parámetro)`, que abre, recorre y cierra solo; al ser parametrizado, la misma consulta se reutiliza para cada categoría sin concatenar valores. El `EXCEPTION` cierra el cursor si algo falla a mitad del recorrido y relanza el error. El `LEFT JOIN` hace que aparezca el libro sin ejemplares.

## 3.2 Abono a multas con FOR UPDATE

**Enunciado.** Cree un procedimiento que reciba un socio y un monto abonado, y marque como pagadas sus multas pendientes **en orden de antigüedad** mientras el dinero alcance (sin saltarse ninguna). Debe devolver cuántas multas pagó y el sobrante.

```sql
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
```

**Salida esperada:**

```text
Multa por la devolución del préstamo 16: 11500
Multas pagadas: 1 | Sobrante: 5000
Préstamo 5: 15000 pagada=S
Préstamo 16: 11500 pagada=N
```

**Por qué así.** `FOR UPDATE` bloquea las multas desde que se abre el cursor, así nadie puede pagarlas o cambiarlas mientras se procesa el abono. `WHERE CURRENT OF` actualiza exactamente la fila que el cursor acaba de leer, sin volver a buscarla por su clave. `FOR UPDATE OF m.pagada` deja claro qué tabla se bloquea. Se trabaja con variables locales (`v_saldo`, `v_pagadas`) y se asignan a los parámetros `OUT` al final, para que quien llama no vea valores a medio calcular si hay un error. Ojo: un `COMMIT` dentro del ciclo liberaría los bloqueos y el siguiente `FETCH` fallaría con ORA-01002.

## 3.3 Historial de un socio con SYS_REFCURSOR

**Enunciado.** Cree una función que devuelva el historial de préstamos de un socio como cursor de referencia, y consúmala desde un bloque anónimo que clasifique cada préstamo como devuelto a tiempo, devuelto tarde o pendiente.

```sql
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
```

**Salida esperada:**

```text
2026-08-04 | Fundamentos de bases de datos  | devuelto a tiempo
2026-08-20 | Sistemas de bases de datos     | devuelto tarde
2026-09-15 | Precálculo                     | devuelto tarde
2026-10-05 | Código limpio                  | devuelto a tiempo
2026-11-03 | Fundamentos de bases de datos  | PENDIENTE (vencido)
Préstamos: 5
```

**Por qué así.** Un cursor normal solo vive dentro del bloque que lo declara; un `SYS_REFCURSOR` es un *puntero* a un resultado que se puede devolver a otro programa: otro bloque PL/SQL, o una aplicación Java que lo recibe como `ResultSet` por JDBC. La función abre el cursor y quien lo consume es responsable de cerrarlo; si no lo cierra, el cursor queda abierto en la sesión hasta agotar `OPEN_CURSORS`.

## 3.4 Generación masiva de multas con BULK COLLECT y FORALL

**Enunciado.** Cree un procedimiento que genere, para una fecha de corte, la multa de todos los préstamos vencidos que aún no tengan una. Debe leer en lotes con `BULK COLLECT ... LIMIT`, insertar con `FORALL`, no detenerse si una fila falla (`SAVE EXCEPTIONS`) y registrar esas filas en el log.

```sql
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
```

**Salida esperada:**

```text
Primera ejecución, multas generadas: 3
Segunda ejecución, multas generadas: 0
Préstamo 13: 4500
Préstamo 16: 11500
Préstamo 17: 1500
```

**Por qué así.**

- En un ciclo fila a fila, cada `INSERT` es un viaje de PL/SQL al motor SQL. `BULK COLLECT` trae un lote completo en un viaje y `FORALL` envía todos los `INSERT` del lote en otro.
- `LIMIT 100` evita cargar millones de filas en memoria de una vez. Con `LIMIT`, la salida del ciclo se controla con `v_ids.COUNT = 0` y no con `%NOTFOUND`, que se activa en el último lote incompleto y haría perder esas filas.
- Sin `SAVE EXCEPTIONS`, la primera fila con error detiene el `FORALL`. Con él, las demás se insertan y al final se lanza ORA-24381 con la lista de fallos en `SQL%BULK_EXCEPTIONS`. Por ejemplo, si otra sesión generara la multa de un préstamo entre la lectura y la inserción, la restricción `UNIQUE` sobre `multa.id_prestamo` rechazaría solo esa fila.
- La segunda ejecución genera 0 porque el `NOT EXISTS` excluye los préstamos que ya tienen multa: el procedimiento se puede correr varias veces sin duplicar (es idempotente).
