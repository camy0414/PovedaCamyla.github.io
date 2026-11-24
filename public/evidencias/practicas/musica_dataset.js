// Práctica MongoDB — plataforma de música (datos ficticios)
// Autora: Camyla Poveda — Bases de Datos 2, Universidad El Bosque
// Ejecutar en mongosh o en un Playground de VS Code.

use('musica_practica');

db.artistas.drop(); db.canciones.drop(); db.usuarios.drop();
db.playlists.drop(); db.escuchas.drop(); db.estadisticas_diarias.drop();

db.artistas.insertMany([
  { _id: "a1", nombre: "Los del Páramo", pais: "Colombia", generos: ["rock", "alternativo"] },
  { _id: "a2", nombre: "Neón Sur", pais: "Argentina", generos: ["electrónica", "pop"] },
  { _id: "a3", nombre: "Lucía Ríos", pais: "México", generos: ["pop", "folk"] },
  { _id: "a4", nombre: "Marea Alta", pais: "Colombia", generos: ["cumbia", "electrónica"] },
  { _id: "a5", nombre: "Cuarteto Nébula", pais: "Chile", generos: ["jazz"] }
]);

db.canciones.insertMany([
  { _id: 1, titulo: "Niebla en la sabana", artista: { _id: "a1", nombre: "Los del Páramo" }, anio: 2019, duracion_seg: 245, generos: ["rock"], reproducciones: 15200, explicito: false },
  { _id: 2, titulo: "Ciudad de ladrillo", artista: { _id: "a1", nombre: "Los del Páramo" }, anio: 2021, duracion_seg: 198, generos: ["rock", "alternativo"], reproducciones: 8900, explicito: false },
  { _id: 3, titulo: "Fuego lento", artista: { _id: "a1", nombre: "Los del Páramo" }, anio: 2023, duracion_seg: 312, generos: ["alternativo"], reproducciones: 4100, explicito: true },
  { _id: 4, titulo: "Pulso digital", artista: { _id: "a2", nombre: "Neón Sur" }, anio: 2020, duracion_seg: 221, generos: ["electrónica"], reproducciones: 22000, explicito: false },
  { _id: 5, titulo: "Noche de neón", artista: { _id: "a2", nombre: "Neón Sur" }, anio: 2022, duracion_seg: 187, generos: ["electrónica", "pop"], reproducciones: 31500, explicito: false },
  { _id: 6, titulo: "Brillo", artista: { _id: "a2", nombre: "Neón Sur" }, anio: 2024, duracion_seg: 165, generos: ["pop"], reproducciones: 12750, explicito: true },
  { _id: 7, titulo: "Raíces", artista: { _id: "a3", nombre: "Lucía Ríos" }, anio: 2018, duracion_seg: 276, generos: ["folk"], reproducciones: 9800, explicito: false },
  { _id: 8, titulo: "Mar de papel", artista: { _id: "a3", nombre: "Lucía Ríos" }, anio: 2022, duracion_seg: 203, generos: ["pop", "folk"], reproducciones: 27300, explicito: false },
  { _id: 9, titulo: "Tambor del río", artista: { _id: "a4", nombre: "Marea Alta" }, anio: 2021, duracion_seg: 234, generos: ["cumbia"], reproducciones: 18600, explicito: false },
  { _id: 10, titulo: "Marea electrónica", artista: { _id: "a4", nombre: "Marea Alta" }, anio: 2023, duracion_seg: 258, generos: ["cumbia", "electrónica"], reproducciones: 14400, explicito: false },
  { _id: 11, titulo: "Blue Nébula", artista: { _id: "a5", nombre: "Cuarteto Nébula" }, anio: 2017, duracion_seg: 402, generos: ["jazz"], reproducciones: 2300, explicito: false },
  { _id: 12, titulo: "Lluvia en Valparaíso", artista: { _id: "a5", nombre: "Cuarteto Nébula" }, anio: 2020, duracion_seg: 365, generos: ["jazz"], reproducciones: 3100, explicito: false }
]);

db.usuarios.insertMany([
  { _id: "u1", nombre: "Isabela", plan: "premium", pais: "Colombia", registro: ISODate("2025-03-10T00:00:00Z"), preferencias: { generos: ["pop", "folk"], idioma: "es" } },
  { _id: "u2", nombre: "Mateo", plan: "gratis", pais: "Colombia", registro: ISODate("2026-01-22T00:00:00Z"), preferencias: { generos: ["rock"], idioma: "es" } },
  { _id: "u3", nombre: "Valentina", plan: "premium", pais: "México", registro: ISODate("2024-11-05T00:00:00Z"), preferencias: { generos: ["electrónica", "cumbia"], idioma: "es" } },
  { _id: "u4", nombre: "Tomás", plan: "gratis", pais: "Argentina", registro: ISODate("2026-06-14T00:00:00Z"), preferencias: { generos: ["jazz", "rock"], idioma: "es" } },
  { _id: "u5", nombre: "Daniela", plan: "premium", pais: "Chile", registro: ISODate("2025-08-30T00:00:00Z"), preferencias: { generos: ["pop"], idioma: "en" } }
]);

db.playlists.insertMany([
  { _id: "pl1", nombre: "Para estudiar", usuario_id: "u1", publica: true, seguidores: 120, canciones: [{ cancion_id: 7, titulo: "Raíces", agregada: ISODate("2026-09-01T00:00:00Z") }, { cancion_id: 8, titulo: "Mar de papel", agregada: ISODate("2026-09-01T00:00:00Z") }, { cancion_id: 11, titulo: "Blue Nébula", agregada: ISODate("2026-10-03T00:00:00Z") }, { cancion_id: 12, titulo: "Lluvia en Valparaíso", agregada: ISODate("2026-10-03T00:00:00Z") }] },
  { _id: "pl2", nombre: "Rumba", usuario_id: "u3", publica: true, seguidores: 540, canciones: [{ cancion_id: 4, titulo: "Pulso digital", agregada: ISODate("2026-08-15T00:00:00Z") }, { cancion_id: 5, titulo: "Noche de neón", agregada: ISODate("2026-08-15T00:00:00Z") }, { cancion_id: 9, titulo: "Tambor del río", agregada: ISODate("2026-09-20T00:00:00Z") }, { cancion_id: 10, titulo: "Marea electrónica", agregada: ISODate("2026-09-20T00:00:00Z") }] },
  { _id: "pl3", nombre: "Rock de los domingos", usuario_id: "u2", publica: false, seguidores: 0, canciones: [{ cancion_id: 1, titulo: "Niebla en la sabana", agregada: ISODate("2026-10-10T00:00:00Z") }, { cancion_id: 2, titulo: "Ciudad de ladrillo", agregada: ISODate("2026-10-10T00:00:00Z") }] }
]);

db.escuchas.insertMany([
  { usuario_id: "u1", cancion_id: 8, fecha: ISODate("2026-11-16T08:10:00Z"), segundos: 203, dispositivo: "movil" },
  { usuario_id: "u1", cancion_id: 7, fecha: ISODate("2026-11-16T08:14:00Z"), segundos: 276, dispositivo: "movil" },
  { usuario_id: "u1", cancion_id: 11, fecha: ISODate("2026-11-16T21:30:00Z"), segundos: 120, dispositivo: "web" },
  { usuario_id: "u2", cancion_id: 1, fecha: ISODate("2026-11-16T19:00:00Z"), segundos: 245, dispositivo: "movil" },
  { usuario_id: "u2", cancion_id: 2, fecha: ISODate("2026-11-17T07:45:00Z"), segundos: 198, dispositivo: "movil" },
  { usuario_id: "u2", cancion_id: 1, fecha: ISODate("2026-11-17T18:20:00Z"), segundos: 60, dispositivo: "web" },
  { usuario_id: "u3", cancion_id: 5, fecha: ISODate("2026-11-17T22:05:00Z"), segundos: 187, dispositivo: "parlante" },
  { usuario_id: "u3", cancion_id: 4, fecha: ISODate("2026-11-17T22:09:00Z"), segundos: 221, dispositivo: "parlante" },
  { usuario_id: "u3", cancion_id: 10, fecha: ISODate("2026-11-17T22:13:00Z"), segundos: 258, dispositivo: "parlante" },
  { usuario_id: "u3", cancion_id: 9, fecha: ISODate("2026-11-18T23:40:00Z"), segundos: 90, dispositivo: "movil" },
  { usuario_id: "u4", cancion_id: 11, fecha: ISODate("2026-11-18T20:00:00Z"), segundos: 402, dispositivo: "web" },
  { usuario_id: "u4", cancion_id: 12, fecha: ISODate("2026-11-18T20:07:00Z"), segundos: 365, dispositivo: "web" },
  { usuario_id: "u4", cancion_id: 3, fecha: ISODate("2026-11-18T20:13:00Z"), segundos: 312, dispositivo: "web" },
  { usuario_id: "u5", cancion_id: 8, fecha: ISODate("2026-11-19T09:00:00Z"), segundos: 203, dispositivo: "movil" },
  { usuario_id: "u5", cancion_id: 6, fecha: ISODate("2026-11-19T09:04:00Z"), segundos: 30, dispositivo: "movil" },
  { usuario_id: "u5", cancion_id: 5, fecha: ISODate("2026-11-19T09:05:00Z"), segundos: 187, dispositivo: "movil" },
  { usuario_id: "u1", cancion_id: 8, fecha: ISODate("2026-11-19T13:00:00Z"), segundos: 203, dispositivo: "web" },
  { usuario_id: "u3", cancion_id: 5, fecha: ISODate("2026-11-20T00:15:00Z"), segundos: 187, dispositivo: "movil" },
  { usuario_id: "u2", cancion_id: 3, fecha: ISODate("2026-11-20T08:00:00Z"), segundos: 150, dispositivo: "movil" },
  { usuario_id: "u1", cancion_id: 12, fecha: ISODate("2026-11-20T10:30:00Z"), segundos: 365, dispositivo: "parlante" }
]);
