---
title: "Práctica PL/SQL 5: Paquetes"
description: Un paquete con especificación y cuerpo que agrupa funciones y procedimientos del caso Biblioteca.
date: 2026-11-23T12:01:00
categories: [PL/SQL, Prácticas]
tags: [Oracle, PL/SQL, Paquetes, Bases de Datos 2]
---

Práctica propia sobre el caso **Biblioteca**. Un **paquete** agrupa funciones, procedimientos y constantes relacionados. Tiene dos partes:

- **Especificación:** lo que se puede usar desde fuera (como un índice).
- **Cuerpo:** el código de cada función y procedimiento.

## 5.1 Especificación

```sql
CREATE OR REPLACE PACKAGE pkg_biblioteca IS
  c_valor_dia CONSTANT NUMBER := 1500;

  FUNCTION total_prestamos (p_id_socio NUMBER) RETURN NUMBER;
  FUNCTION calcular_multa (p_dias NUMBER) RETURN NUMBER;
  PROCEDURE mostrar_socio (p_id_socio NUMBER);
END pkg_biblioteca;
/
```

## 5.2 Cuerpo

```sql
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
```

## 5.3 Uso del paquete

```sql
BEGIN
  pkg_biblioteca.mostrar_socio(1);
  pkg_biblioteca.mostrar_socio(99);
  DBMS_OUTPUT.PUT_LINE('Multa por 7 días: ' || pkg_biblioteca.calcular_multa(7));
  DBMS_OUTPUT.PUT_LINE('Valor por día: ' || pkg_biblioteca.c_valor_dia);
END;
/
```

**Salida esperada:**

```text
Laura Méndez (ESTUDIANTE) - 5 préstamos
No existe el socio 99
Multa por 7 días: 10500
Valor por día: 1500
```

**Explicación.** Todo lo del paquete se llama con el nombre del paquete adelante: `pkg_biblioteca.mostrar_socio(1)`. La constante `c_valor_dia` está en un solo lugar: si la tarifa cambia, solo se cambia ahí. `mostrar_socio` usa `total_prestamos`, que está en el mismo paquete.
