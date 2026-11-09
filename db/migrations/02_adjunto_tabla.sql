-- 02_adjunto_tabla.sql
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS adjunto (
  fiId INT NOT NULL AUTO_INCREMENT,
  fcEntidad VARCHAR(50) NOT NULL COMMENT 'ticket, etc.',
  fiEntidadId INT NOT NULL,
  fcEtapa VARCHAR(20) NOT NULL COMMENT 'SOLICITUD, ANTES, DESPUES',
  fcNombreOriginal VARCHAR(255) NOT NULL,
  fcRuta VARCHAR(500) NOT NULL,
  fcTipoMime VARCHAR(100) NULL,
  fiTamanoBytes BIGINT NOT NULL DEFAULT 0,
  fdCreado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fiCreadoPor INT NULL,
  fdModificado DATETIME NULL,
  fiModificadoPor INT NULL,
  fbActivo TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (fiId),
  KEY ix_adjunto_entidad (fcEntidad, fiEntidadId),
  KEY ix_adjunto_etapa (fcEtapa),
  KEY ix_adjunto_activo (fbActivo),
  KEY ix_adjunto_creadopor (fiCreadoPor)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
