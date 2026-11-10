-- 75_seguridad_debe_cambiar_correopendiente.sql
-- Callers: SeguridadServicio / CorreoPendienteServicio; migraciones 76-79 (SPs);
--   AccountController vía AutenticarAsync (fbDebeCambiarClave).
-- Schema: usuario.fbDebeCambiarClave TINYINT(1); correopendiente
--   (fiId, fcPara, fcAsunto, fcCuerpoCifrado, fcTipo, fbEnviado, fdCreado DATETIME,
--    fdEnviado DATETIME, fiIntentos, fiCreadoPor). Sin datos de producción.
-- User instruction: "columna fbDebeCambiarClave" + "crea tabla bandeja de salida
--   (ej. correopendiente: fiId, fcPara, fcAsunto, fcCuerpoCifrado, fcTipo, fbEnviado,
--    fdCreado, fdEnviado, fiIntentos)" + "Tu rango de migraciones: 75-79".
-- No existe 7x ni correopendiente/fbDebeCambiarClave (Glob/Grep).
SET NAMES utf8mb4;

SET @col := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'usuario' AND COLUMN_NAME = 'fbDebeCambiarClave'
);
SET @sql := IF(@col = 0,
  'ALTER TABLE usuario ADD COLUMN fbDebeCambiarClave TINYINT(1) NOT NULL DEFAULT 0 COMMENT ''1 = debe cambiar clave en el próximo ingreso local'' AFTER fcClaveHash',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS correopendiente (
  fiId INT NOT NULL AUTO_INCREMENT,
  fcPara VARCHAR(150) NOT NULL,
  fcAsunto VARCHAR(250) NOT NULL,
  fcCuerpoCifrado TEXT NOT NULL COMMENT 'Cuerpo (con clave) cifrado con Data Protection',
  fcTipo VARCHAR(40) NOT NULL DEFAULT 'BIENVENIDA',
  fbEnviado TINYINT(1) NOT NULL DEFAULT 0,
  fdCreado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fdEnviado DATETIME NULL,
  fiIntentos INT NOT NULL DEFAULT 0,
  fiCreadoPor INT NULL,
  PRIMARY KEY (fiId),
  KEY ix_correopendiente_enviado (fbEnviado),
  KEY ix_correopendiente_tipo (fcTipo),
  KEY ix_correopendiente_creado (fdCreado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
