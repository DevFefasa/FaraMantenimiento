-- 09_seguridad_indices_extra.sql
-- Índices auxiliares idempotentes para reportes de acceso
SET NAMES utf8mb4;

-- MariaDB 10.4: crear índice solo si no existe
SET @sql := (
  SELECT IF(
    EXISTS(SELECT 1 FROM information_schema.statistics WHERE table_schema = DATABASE() AND table_name = 'bitacoraacceso' AND index_name = 'ix_bitacoraacceso_usuario_fecha'),
    'SELECT 1',
    'CREATE INDEX ix_bitacoraacceso_usuario_fecha ON bitacoraacceso (fiUsuarioId, fdFecha)'
  )
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := (
  SELECT IF(
    EXISTS(SELECT 1 FROM information_schema.statistics WHERE table_schema = DATABASE() AND table_name = 'adjunto' AND index_name = 'ix_adjunto_entidad_etapa'),
    'SELECT 1',
    'CREATE INDEX ix_adjunto_entidad_etapa ON adjunto (fcEntidad, fiEntidadId, fcEtapa)'
  )
);
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
