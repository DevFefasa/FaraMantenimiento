-- 30_sla_alerta_tabla.sql
-- Callers: sp_sla_revisar_vencimientos; SlaRepositorio/SlaServicio; SlaTarea
-- API: tabla slaalerta
-- Schema: fiTicketId, fcTipo (POR_VENCER/VENCIDO_RESPUESTA/VENCIDO_SOLUCION), fdFecha, fdFechaDia, fbNotificado, fcDetalle
-- User instruction: "registra en una tabla slaalerta (fiTicketId, fcTipo POR_VENCER/VENCIDO_RESPUESTA/VENCIDO_SOLUCION, fdFecha, fbNotificado=0) sin duplicar"
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS slaalerta (
  fiId INT NOT NULL AUTO_INCREMENT,
  fiTicketId INT NOT NULL,
  fcTipo VARCHAR(30) NOT NULL COMMENT 'POR_VENCER, VENCIDO_RESPUESTA, VENCIDO_SOLUCION',
  fdFecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fdFechaDia DATE AS (DATE(fdFecha)) STORED,
  fbNotificado TINYINT(1) NOT NULL DEFAULT 0,
  fcDetalle VARCHAR(250) NULL,
  PRIMARY KEY (fiId),
  UNIQUE KEY uk_slaalerta_ticket_tipo_dia (fiTicketId, fcTipo, fdFechaDia),
  KEY ix_slaalerta_ticket (fiTicketId),
  KEY ix_slaalerta_tipo (fcTipo),
  KEY ix_slaalerta_notificado (fbNotificado),
  KEY ix_slaalerta_fecha (fdFecha),
  CONSTRAINT fk_slaalerta_ticket FOREIGN KEY (fiTicketId) REFERENCES ticket (fiId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
