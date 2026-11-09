-- 29_ticket_indices_extra.sql
SET NAMES utf8mb4;
SET @sql := (SELECT IF(EXISTS(SELECT 1 FROM information_schema.statistics WHERE table_schema=DATABASE() AND table_name='ticket' AND index_name='ix_ticket_solicitante_estado'),
  'SELECT 1','CREATE INDEX ix_ticket_solicitante_estado ON ticket (fiSolicitanteId, fiEstadoId)'));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := (SELECT IF(EXISTS(SELECT 1 FROM information_schema.statistics WHERE table_schema=DATABASE() AND table_name='ticket' AND index_name='ix_ticket_numero_pref'),
  'SELECT 1','CREATE INDEX ix_ticket_numero_pref ON ticket (fcNumero)'));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
