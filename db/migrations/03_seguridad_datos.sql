-- 03_seguridad_datos.sql
SET NAMES utf8mb4;

INSERT IGNORE INTO rol (fcCodigo, fcNombre, fcDescripcion, fbActivo) VALUES
  ('ADMIN', 'Administrador', 'Acceso total al sistema', 1),
  ('SOLICITANTE', 'Solicitante', 'Crear y consultar tickets propios', 1),
  ('MANTENIMIENTO', 'Mantenimiento', 'Evaluar, asignar, actualizar y cerrar tickets', 1),
  ('JEFATURA', 'Jefatura de Proyectos', 'Aprobar, priorizar y ver todos los tickets', 1),
  ('GERENCIA', 'Gerencia / Dirección', 'Consulta de reportes e indicadores', 1);

INSERT IGNORE INTO pantalla (fcCodigo, fcNombre, fcDescripcion, fiOrden, fbActivo) VALUES
  ('DASHBOARD', 'Tablero', 'Resumen e indicadores', 1, 1),
  ('TICKET_CREAR', 'Crear ticket', 'Registrar solicitud de mantenimiento', 2, 1),
  ('TICKET_MIOS', 'Mis tickets', 'Tickets del solicitante', 3, 1),
  ('TICKET_BANDEJA', 'Bandeja mantenimiento', 'Bandeja operativa de mantenimiento', 4, 1),
  ('TICKET_APROBACION', 'Aprobación', 'Bandeja de aprobación de jefatura', 5, 1),
  ('TICKET_TODOS', 'Todos los tickets', 'Consulta general de tickets', 6, 1),
  ('CATALOGOS', 'Catálogos', 'Administración de catálogos', 7, 1),
  ('REPORTES', 'Reportes', 'Reportes e exportación', 8, 1),
  ('SEGURIDAD', 'Seguridad', 'Usuarios, roles y permisos', 9, 1);

-- ADMIN: todas las pantallas
INSERT IGNORE INTO rolpermiso (fiRolId, fiPantallaId)
SELECT r.fiId, p.fiId FROM rol r CROSS JOIN pantalla p WHERE r.fcCodigo = 'ADMIN' AND p.fbActivo = 1;

-- SOLICITANTE
INSERT IGNORE INTO rolpermiso (fiRolId, fiPantallaId)
SELECT r.fiId, p.fiId FROM rol r JOIN pantalla p ON p.fcCodigo IN ('DASHBOARD','TICKET_CREAR','TICKET_MIOS')
WHERE r.fcCodigo = 'SOLICITANTE';

-- MANTENIMIENTO
INSERT IGNORE INTO rolpermiso (fiRolId, fiPantallaId)
SELECT r.fiId, p.fiId FROM rol r JOIN pantalla p ON p.fcCodigo IN ('DASHBOARD','TICKET_BANDEJA','TICKET_TODOS','TICKET_MIOS')
WHERE r.fcCodigo = 'MANTENIMIENTO';

-- JEFATURA
INSERT IGNORE INTO rolpermiso (fiRolId, fiPantallaId)
SELECT r.fiId, p.fiId FROM rol r JOIN pantalla p ON p.fcCodigo IN ('DASHBOARD','TICKET_APROBACION','TICKET_TODOS','TICKET_BANDEJA','CATALOGOS')
WHERE r.fcCodigo = 'JEFATURA';

-- GERENCIA
INSERT IGNORE INTO rolpermiso (fiRolId, fiPantallaId)
SELECT r.fiId, p.fiId FROM rol r JOIN pantalla p ON p.fcCodigo IN ('DASHBOARD','REPORTES','TICKET_TODOS')
WHERE r.fcCodigo = 'GERENCIA';

-- Usuario local admin (sin hash: usa Auth:LocalPassword en la app)
INSERT IGNORE INTO usuario (fcUsuario, fcNombre, fcCargo, fcCorreo, fiRolId, fbEsLocal, fcClaveHash, fbActivo)
SELECT 'admin', 'Administrador', 'Administrador del sistema', NULL, r.fiId, 1, NULL, 1
FROM rol r
WHERE r.fcCodigo = 'ADMIN'
  AND NOT EXISTS (SELECT 1 FROM usuario u WHERE u.fcUsuario = 'admin');
