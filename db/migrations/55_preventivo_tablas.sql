-- 55_preventivo_tablas.sql
-- Callers: docker exec MariaLocal; PreventivoRepositorio (vía SP 56-59)
-- API: tablas planpreventivo, planpreventivoejecucion; pantalla PREVENTIVOS + rolpermiso
-- Schema: planpreventivo (fcNombre, fiActivoId NULL, fiSucursalId, fiUbicacionId NULL, fiCategoriaId,
--   fiPrioridadId, fcDescripcion, fiFrecuenciaDias, fdProximaFecha, fiDiasAnticipacion, fiTecnicoId NULL,
--   fiProveedorId NULL, fbActivo, auditoria); planpreventivoejecucion (fiPlanId, fdFechaProgramada, fiTicketId, fdGenerado)
-- User instruction: "tabla planpreventivo ... y planpreventivoejecucion ... Pantalla nueva PREVENTIVOS ... permiso para ADMIN, MANTENIMIENTO, JEFATURA (INSERT IGNORE)."
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS planpreventivo (
  fiId INT NOT NULL AUTO_INCREMENT,
  fcNombre VARCHAR(150) NOT NULL,
  fiActivoId INT NULL,
  fiSucursalId INT NOT NULL,
  fiUbicacionId INT NULL,
  fiCategoriaId INT NOT NULL,
  fiPrioridadId INT NOT NULL,
  fcDescripcion TEXT NULL,
  fiFrecuenciaDias INT NOT NULL,
  fdProximaFecha DATE NOT NULL,
  fiDiasAnticipacion INT NOT NULL DEFAULT 7,
  fiTecnicoId INT NULL,
  fiProveedorId INT NULL,
  fdCreado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fiCreadoPor INT NULL,
  fdModificado DATETIME NULL,
  fiModificadoPor INT NULL,
  fbActivo TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (fiId),
  KEY ix_planprev_sucursal (fiSucursalId),
  KEY ix_planprev_activo (fiActivoId),
  KEY ix_planprev_ubicacion (fiUbicacionId),
  KEY ix_planprev_categoria (fiCategoriaId),
  KEY ix_planprev_prioridad (fiPrioridadId),
  KEY ix_planprev_proxima (fdProximaFecha),
  KEY ix_planprev_fbactivo (fbActivo),
  KEY ix_planprev_tecnico (fiTecnicoId),
  KEY ix_planprev_proveedor (fiProveedorId),
  CONSTRAINT fk_planprev_sucursal FOREIGN KEY (fiSucursalId) REFERENCES sucursal (fiId),
  CONSTRAINT fk_planprev_activo FOREIGN KEY (fiActivoId) REFERENCES activo (fiId),
  CONSTRAINT fk_planprev_ubicacion FOREIGN KEY (fiUbicacionId) REFERENCES ubicacion (fiId),
  CONSTRAINT fk_planprev_categoria FOREIGN KEY (fiCategoriaId) REFERENCES categoria (fiId),
  CONSTRAINT fk_planprev_prioridad FOREIGN KEY (fiPrioridadId) REFERENCES prioridad (fiId),
  CONSTRAINT fk_planprev_tecnico FOREIGN KEY (fiTecnicoId) REFERENCES tecnico (fiId),
  CONSTRAINT fk_planprev_proveedor FOREIGN KEY (fiProveedorId) REFERENCES proveedor (fiId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS planpreventivoejecucion (
  fiId INT NOT NULL AUTO_INCREMENT,
  fiPlanId INT NOT NULL,
  fdFechaProgramada DATE NOT NULL,
  fiTicketId INT NULL,
  fdGenerado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (fiId),
  UNIQUE KEY uk_planprev_ejec_plan_fecha (fiPlanId, fdFechaProgramada),
  KEY ix_planprev_ejec_ticket (fiTicketId),
  KEY ix_planprev_ejec_fecha (fdFechaProgramada),
  CONSTRAINT fk_planprev_ejec_plan FOREIGN KEY (fiPlanId) REFERENCES planpreventivo (fiId),
  CONSTRAINT fk_planprev_ejec_ticket FOREIGN KEY (fiTicketId) REFERENCES ticket (fiId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO pantalla (fcCodigo, fcNombre, fcDescripcion, fiOrden, fbActivo) VALUES
('PREVENTIVOS', 'Preventivos', 'Plan y calendario de mantenimiento preventivo', 55, 1);

INSERT IGNORE INTO rolpermiso (fiRolId, fiPantallaId, fiCreadoPor)
SELECT r.fiId, p.fiId, 1
FROM rol r
CROSS JOIN pantalla p
WHERE r.fcCodigo IN ('ADMIN', 'MANTENIMIENTO', 'JEFATURA')
  AND p.fcCodigo = 'PREVENTIVOS';
