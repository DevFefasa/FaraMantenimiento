-- 85_correo_bandeja_columnas.sql
-- Módulo de correos: completa la bandeja correopendiente (creada en 75) y marca de correo en slaalerta.
--  - fcFormato: TEXTO (cuerpo cifrado en texto plano, p. ej. bienvenida) o JSON (cifrado {html,texto}).
--  - fiTicketId, fcError, fdUltimoIntento: trazabilidad y reintentos.
--  - slaalerta.fbCorreoEncolado: evita repetir el correo de SLA. No se usa fbNotificado porque
--    ese campo alimenta el contador de la campana del header.
SET NAMES utf8mb4;

ALTER TABLE correopendiente
  ADD COLUMN IF NOT EXISTS fcFormato VARCHAR(10) NOT NULL DEFAULT 'TEXTO' COMMENT 'TEXTO o JSON {html,texto}' AFTER fcTipo,
  ADD COLUMN IF NOT EXISTS fiTicketId INT NULL AFTER fcFormato,
  ADD COLUMN IF NOT EXISTS fcError VARCHAR(500) NULL AFTER fiIntentos,
  ADD COLUMN IF NOT EXISTS fdUltimoIntento DATETIME NULL AFTER fcError;

ALTER TABLE correopendiente
  ADD INDEX IF NOT EXISTS ix_correopendiente_ticket (fiTicketId),
  ADD INDEX IF NOT EXISTS ix_correopendiente_pend (fbEnviado, fiIntentos, fiId);

-- El cuerpo cifrado de un HTML completo puede superar 64 KB: MEDIUMTEXT (compatible con lo existente).
ALTER TABLE correopendiente MODIFY COLUMN fcCuerpoCifrado MEDIUMTEXT NOT NULL COMMENT 'Cuerpo cifrado con Data Protection (TEXTO o JSON {html,texto})';

ALTER TABLE slaalerta
  ADD COLUMN IF NOT EXISTS fbCorreoEncolado TINYINT(1) NOT NULL DEFAULT 0 COMMENT '1 = correo de SLA ya encolado' AFTER fbNotificado;
