-- 95_area_departamento_tablas.sql
-- Callers: applied via docker exec MariaLocal; schema used by SPs 96/97 and Catalogo/Seguridad/Ticket repos
-- Schema: area, departamento; usuario/ticket.fiAreaId + fiDepartamentoId + FK
-- Nota: sucursal fcTipo='AREA' (Oficina Central) NO se migra ni se borra.
-- User instruction: "1) Migración 95-96 (idempotente): tablas area y departamento, columnas usuario.fiAreaId/fiDepartamentoId y ticket.fiAreaId/fiDepartamentoId con FK"
-- Confirm: Glob db/migrations/95*.sql → 0 files

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS area (
  fiId INT NOT NULL AUTO_INCREMENT,
  fcCodigo VARCHAR(30) NOT NULL,
  fcNombre VARCHAR(100) NOT NULL,
  fdCreado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fiCreadoPor INT NULL,
  fdModificado DATETIME NULL,
  fiModificadoPor INT NULL,
  fbActivo TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (fiId),
  UNIQUE KEY uk_area_codigo (fcCodigo),
  KEY ix_area_activo (fbActivo),
  KEY ix_area_creadopor (fiCreadoPor),
  KEY ix_area_modificadopor (fiModificadoPor)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS departamento (
  fiId INT NOT NULL AUTO_INCREMENT,
  fcCodigo VARCHAR(30) NOT NULL,
  fcNombre VARCHAR(100) NOT NULL,
  fiAreaId INT NOT NULL,
  fdCreado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fiCreadoPor INT NULL,
  fdModificado DATETIME NULL,
  fiModificadoPor INT NULL,
  fbActivo TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (fiId),
  UNIQUE KEY uk_departamento_codigo (fcCodigo),
  KEY ix_departamento_area (fiAreaId),
  KEY ix_departamento_activo (fbActivo),
  KEY ix_departamento_creadopor (fiCreadoPor),
  KEY ix_departamento_modificadopor (fiModificadoPor),
  CONSTRAINT fk_departamento_area FOREIGN KEY (fiAreaId) REFERENCES area (fiId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET @col := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'usuario' AND COLUMN_NAME = 'fiAreaId'
);
SET @sql := IF(@col = 0,
  'ALTER TABLE usuario ADD COLUMN fiAreaId INT NULL AFTER fiSucursalId, ADD KEY ix_usuario_area (fiAreaId)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'usuario' AND CONSTRAINT_NAME = 'fk_usuario_area'
);
SET @sql := IF(@fk = 0,
  'ALTER TABLE usuario ADD CONSTRAINT fk_usuario_area FOREIGN KEY (fiAreaId) REFERENCES area (fiId)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'usuario' AND COLUMN_NAME = 'fiDepartamentoId'
);
SET @sql := IF(@col = 0,
  'ALTER TABLE usuario ADD COLUMN fiDepartamentoId INT NULL AFTER fiAreaId, ADD KEY ix_usuario_departamento (fiDepartamentoId)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'usuario' AND CONSTRAINT_NAME = 'fk_usuario_departamento'
);
SET @sql := IF(@fk = 0,
  'ALTER TABLE usuario ADD CONSTRAINT fk_usuario_departamento FOREIGN KEY (fiDepartamentoId) REFERENCES departamento (fiId)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ticket' AND COLUMN_NAME = 'fiAreaId'
);
SET @sql := IF(@col = 0,
  'ALTER TABLE ticket ADD COLUMN fiAreaId INT NULL AFTER fiSucursalId, ADD KEY ix_ticket_area (fiAreaId)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ticket' AND CONSTRAINT_NAME = 'fk_ticket_area'
);
SET @sql := IF(@fk = 0,
  'ALTER TABLE ticket ADD CONSTRAINT fk_ticket_area FOREIGN KEY (fiAreaId) REFERENCES area (fiId)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ticket' AND COLUMN_NAME = 'fiDepartamentoId'
);
SET @sql := IF(@col = 0,
  'ALTER TABLE ticket ADD COLUMN fiDepartamentoId INT NULL AFTER fiAreaId, ADD KEY ix_ticket_departamento (fiDepartamentoId)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ticket' AND CONSTRAINT_NAME = 'fk_ticket_departamento'
);
SET @sql := IF(@fk = 0,
  'ALTER TABLE ticket ADD CONSTRAINT fk_ticket_departamento FOREIGN KEY (fiDepartamentoId) REFERENCES departamento (fiId)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
