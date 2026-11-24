--------------------------------------------------------------------------------
-- PRÁCTICA PERSONAL — BASES DE DATOS 2
-- Caso: Biblioteca universitaria
-- Autora: Camyla Poveda
-- Motor: Oracle Database 19c (SQL Developer)
--
-- Esquema y datos de práctica. Se usa en las prácticas de SQL y PL/SQL del
-- portafolio. Ejecutar completo antes de los ejercicios.
--------------------------------------------------------------------------------

-- Limpieza (ignorar errores la primera vez)
BEGIN
  FOR t IN (SELECT table_name FROM user_tables
            WHERE table_name IN ('MULTA','PRESTAMO','EJEMPLAR','LIBRO_AUTOR',
                                 'LIBRO','AUTOR','CATEGORIA_LIBRO','SOCIO',
                                 'LOG_BIBLIOTECA','HIST_ESTADO_EJEMPLAR')) LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS PURGE';
  END LOOP;
END;
/

CREATE TABLE categoria_libro (
  id_categoria  NUMBER(4)      PRIMARY KEY,
  nombre        VARCHAR2(60)   NOT NULL UNIQUE
);

CREATE TABLE autor (
  id_autor  NUMBER(6)     PRIMARY KEY,
  nombre    VARCHAR2(100) NOT NULL,
  pais      VARCHAR2(40)
);

CREATE TABLE libro (
  id_libro          NUMBER(6)     PRIMARY KEY,
  isbn              VARCHAR2(20)  NOT NULL UNIQUE,
  titulo            VARCHAR2(150) NOT NULL,
  anio_publicacion  NUMBER(4),
  id_categoria      NUMBER(4)     NOT NULL REFERENCES categoria_libro (id_categoria)
);

CREATE TABLE libro_autor (
  id_libro  NUMBER(6) REFERENCES libro (id_libro),
  id_autor  NUMBER(6) REFERENCES autor (id_autor),
  CONSTRAINT pk_libro_autor PRIMARY KEY (id_libro, id_autor)
);

CREATE TABLE ejemplar (
  id_ejemplar  NUMBER(8)    PRIMARY KEY,
  id_libro     NUMBER(6)    NOT NULL REFERENCES libro (id_libro),
  estado       VARCHAR2(12) DEFAULT 'DISPONIBLE' NOT NULL
               CONSTRAINT ck_ejemplar_estado
               CHECK (estado IN ('DISPONIBLE','PRESTADO','DANADO'))
);

CREATE TABLE socio (
  id_socio        NUMBER(6)     PRIMARY KEY,
  documento       VARCHAR2(15)  NOT NULL UNIQUE,
  nombre          VARCHAR2(100) NOT NULL,
  tipo            VARCHAR2(10)  NOT NULL
                  CONSTRAINT ck_socio_tipo CHECK (tipo IN ('ESTUDIANTE','DOCENTE','EXTERNO')),
  fecha_registro  DATE          NOT NULL,
  activo          CHAR(1)       DEFAULT 'S' NOT NULL CONSTRAINT ck_socio_activo CHECK (activo IN ('S','N'))
);

CREATE TABLE prestamo (
  id_prestamo       NUMBER(8)  PRIMARY KEY,
  id_ejemplar       NUMBER(8)  NOT NULL REFERENCES ejemplar (id_ejemplar),
  id_socio          NUMBER(6)  NOT NULL REFERENCES socio (id_socio),
  fecha_prestamo    DATE       NOT NULL,
  fecha_limite      DATE       NOT NULL,
  fecha_devolucion  DATE,
  CONSTRAINT ck_prestamo_fechas CHECK (fecha_limite >= fecha_prestamo)
);

CREATE TABLE multa (
  id_multa     NUMBER(8)     PRIMARY KEY,
  id_prestamo  NUMBER(8)     NOT NULL UNIQUE REFERENCES prestamo (id_prestamo),
  valor        NUMBER(10,2)  NOT NULL CHECK (valor > 0),
  pagada       CHAR(1)       DEFAULT 'N' NOT NULL CHECK (pagada IN ('S','N'))
);

-- Índices sobre las claves foráneas más consultadas
CREATE INDEX ix_prestamo_socio    ON prestamo (id_socio);
CREATE INDEX ix_prestamo_ejemplar ON prestamo (id_ejemplar);
CREATE INDEX ix_ejemplar_libro    ON ejemplar (id_libro);

--------------------------------------------------------------------------------
-- Datos
--------------------------------------------------------------------------------
INSERT INTO categoria_libro VALUES (1, 'Bases de datos');
INSERT INTO categoria_libro VALUES (2, 'Programación');
INSERT INTO categoria_libro VALUES (3, 'Redes');
INSERT INTO categoria_libro VALUES (4, 'Matemáticas');
INSERT INTO categoria_libro VALUES (5, 'Literatura');

INSERT INTO autor VALUES (1, 'Abraham Silberschatz', 'Estados Unidos');
INSERT INTO autor VALUES (2, 'Henry F. Korth',       'Estados Unidos');
INSERT INTO autor VALUES (3, 'Ramez Elmasri',        'Egipto');
INSERT INTO autor VALUES (4, 'Shamkant Navathe',     'India');
INSERT INTO autor VALUES (5, 'Robert C. Martin',     'Estados Unidos');
INSERT INTO autor VALUES (6, 'Andrew S. Tanenbaum',  'Estados Unidos');
INSERT INTO autor VALUES (7, 'Gabriel García Márquez','Colombia');
INSERT INTO autor VALUES (8, 'James Stewart',        'Canadá');

INSERT INTO libro VALUES (101, '978-0073523323', 'Fundamentos de bases de datos',       2019, 1);
INSERT INTO libro VALUES (102, '978-0133970777', 'Sistemas de bases de datos',          2016, 1);
INSERT INTO libro VALUES (103, '978-0132350884', 'Código limpio',                       2008, 2);
INSERT INTO libro VALUES (104, '978-0134494166', 'Arquitectura limpia',                 2017, 2);
INSERT INTO libro VALUES (105, '978-0132126953', 'Redes de computadoras',               2011, 3);
INSERT INTO libro VALUES (106, '978-0133591620', 'Sistemas operativos modernos',        2014, 2);
INSERT INTO libro VALUES (107, '978-0307474728', 'Cien años de soledad',                1967, 5);
INSERT INTO libro VALUES (108, '978-0307387264', 'El amor en los tiempos del cólera',   1985, 5);
INSERT INTO libro VALUES (109, '978-1285740621', 'Precálculo',                          2015, 4);
INSERT INTO libro VALUES (110, '978-0000000001', 'Introducción al álgebra lineal',      2020, 4);

INSERT INTO libro_autor VALUES (101, 1);
INSERT INTO libro_autor VALUES (101, 2);
INSERT INTO libro_autor VALUES (102, 3);
INSERT INTO libro_autor VALUES (102, 4);
INSERT INTO libro_autor VALUES (103, 5);
INSERT INTO libro_autor VALUES (104, 5);
INSERT INTO libro_autor VALUES (105, 6);
INSERT INTO libro_autor VALUES (106, 6);
INSERT INTO libro_autor VALUES (107, 7);
INSERT INTO libro_autor VALUES (108, 7);
INSERT INTO libro_autor VALUES (109, 8);
-- El libro 110 queda sin autor a propósito (sirve para los ejercicios de OUTER JOIN)

INSERT INTO ejemplar VALUES (1001, 101, 'PRESTADO');
INSERT INTO ejemplar VALUES (1002, 101, 'DISPONIBLE');
INSERT INTO ejemplar VALUES (1003, 101, 'PRESTADO');
INSERT INTO ejemplar VALUES (1004, 102, 'DISPONIBLE');
INSERT INTO ejemplar VALUES (1005, 102, 'PRESTADO');
INSERT INTO ejemplar VALUES (1006, 103, 'PRESTADO');
INSERT INTO ejemplar VALUES (1007, 103, 'DISPONIBLE');
INSERT INTO ejemplar VALUES (1008, 104, 'DISPONIBLE');
INSERT INTO ejemplar VALUES (1009, 105, 'PRESTADO');
INSERT INTO ejemplar VALUES (1010, 105, 'DANADO');
INSERT INTO ejemplar VALUES (1011, 106, 'DISPONIBLE');
INSERT INTO ejemplar VALUES (1012, 107, 'PRESTADO');
INSERT INTO ejemplar VALUES (1013, 107, 'DISPONIBLE');
INSERT INTO ejemplar VALUES (1014, 108, 'DISPONIBLE');
INSERT INTO ejemplar VALUES (1015, 109, 'DISPONIBLE');
INSERT INTO ejemplar VALUES (1016, 109, 'DISPONIBLE');

INSERT INTO socio VALUES (1, '1010101010', 'Laura Méndez',    'ESTUDIANTE', DATE '2025-02-03', 'S');
INSERT INTO socio VALUES (2, '1020202020', 'Andrés Rojas',    'ESTUDIANTE', DATE '2025-08-10', 'S');
INSERT INTO socio VALUES (3, '1030303030', 'Paula Herrera',   'ESTUDIANTE', DATE '2026-01-20', 'S');
INSERT INTO socio VALUES (4, '79797979',   'Carlos Duarte',   'DOCENTE',    DATE '2024-07-15', 'S');
INSERT INTO socio VALUES (5, '52525252',   'Marta Salazar',   'DOCENTE',    DATE '2025-01-12', 'S');
INSERT INTO socio VALUES (6, '1060606060', 'Diego Castillo',  'EXTERNO',    DATE '2026-03-05', 'S');
INSERT INTO socio VALUES (7, '1070707070', 'Sofía Pineda',    'ESTUDIANTE', DATE '2024-02-01', 'N');
INSERT INTO socio VALUES (8, '1080808080', 'Julián Vargas',   'ESTUDIANTE', DATE '2026-08-01', 'S');

-- Préstamos devueltos (histórico)
INSERT INTO prestamo VALUES (1,  1002, 1, DATE '2026-08-04', DATE '2026-08-18', DATE '2026-08-15');
INSERT INTO prestamo VALUES (2,  1004, 1, DATE '2026-08-20', DATE '2026-09-03', DATE '2026-09-10');
INSERT INTO prestamo VALUES (3,  1007, 2, DATE '2026-08-21', DATE '2026-09-04', DATE '2026-09-02');
INSERT INTO prestamo VALUES (4,  1011, 4, DATE '2026-08-25', DATE '2026-09-24', DATE '2026-09-20');
INSERT INTO prestamo VALUES (5,  1013, 3, DATE '2026-09-01', DATE '2026-09-15', DATE '2026-09-25');
INSERT INTO prestamo VALUES (6,  1002, 2, DATE '2026-09-07', DATE '2026-09-21', DATE '2026-09-21');
INSERT INTO prestamo VALUES (7,  1008, 5, DATE '2026-09-10', DATE '2026-10-10', DATE '2026-10-01');
INSERT INTO prestamo VALUES (8,  1015, 1, DATE '2026-09-15', DATE '2026-09-29', DATE '2026-10-04');
INSERT INTO prestamo VALUES (9,  1004, 6, DATE '2026-09-22', DATE '2026-09-29', DATE '2026-09-28');
INSERT INTO prestamo VALUES (10, 1014, 3, DATE '2026-10-01', DATE '2026-10-15', DATE '2026-10-14');
INSERT INTO prestamo VALUES (11, 1007, 1, DATE '2026-10-05', DATE '2026-10-19', DATE '2026-10-18');
INSERT INTO prestamo VALUES (12, 1016, 2, DATE '2026-10-08', DATE '2026-10-22', DATE '2026-10-30');
-- Préstamos activos (sin devolver) a la fecha de corte 2026-11-20
INSERT INTO prestamo VALUES (13, 1001, 1, DATE '2026-11-03', DATE '2026-11-17', NULL);
INSERT INTO prestamo VALUES (14, 1003, 2, DATE '2026-11-10', DATE '2026-11-24', NULL);
INSERT INTO prestamo VALUES (15, 1005, 4, DATE '2026-10-28', DATE '2026-11-27', NULL);
INSERT INTO prestamo VALUES (16, 1006, 3, DATE '2026-10-30', DATE '2026-11-13', NULL);
INSERT INTO prestamo VALUES (17, 1009, 6, DATE '2026-11-12', DATE '2026-11-19', NULL);
INSERT INTO prestamo VALUES (18, 1012, 8, DATE '2026-11-15', DATE '2026-11-29', NULL);

-- Multas: 1.500 por día de retraso
INSERT INTO multa VALUES (1, 2,  10500, 'S');
INSERT INTO multa VALUES (2, 5,  15000, 'N');
INSERT INTO multa VALUES (3, 8,   7500, 'S');
INSERT INTO multa VALUES (4, 12, 12000, 'N');

COMMIT;
