-- 33_sp_sla_alertas_listar.sql
-- Callers: SlaServicio.ListarAlertasAsync / ContarAlertasPendientesAsync (bandeja)
-- API: sp_sla_alertas_listar, sp_sla_alertas_contar
-- Schema: fila estándar + alertas con ticket/sucursal; contar → fiTotal
-- User instruction: "sp_sla_alertas_listar para mostrar avisos" + contador para bandeja
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_sla_alertas_listar;
DROP PROCEDURE IF EXISTS sp_sla_alertas_contar;

DELIMITER $$

CREATE PROCEDURE sp_sla_alertas_listar(
  IN p_fbSoloNoNotificadas TINYINT,
  IN p_fiLimite INT
)
BEGIN
  DECLARE v_lim INT;
  SET v_lim = IFNULL(NULLIF(p_fiLimite, 0), 100);

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;

  SELECT a.fiId, a.fiTicketId, a.fcTipo, a.fdFecha, a.fbNotificado, a.fcDetalle,
         t.fcNumero AS fcTicketNumero, e.fcCodigo AS fcEstadoCodigo, e.fcNombre AS fcEstadoNombre,
         t.fdLimiteRespuesta, t.fdLimiteSolucion, s.fcNombre AS fcSucursalNombre
  FROM slaalerta a
  JOIN ticket t ON t.fiId = a.fiTicketId
  JOIN estado e ON e.fiId = t.fiEstadoId
  LEFT JOIN sucursal s ON s.fiId = t.fiSucursalId
  WHERE (IFNULL(p_fbSoloNoNotificadas, 0) = 0 OR a.fbNotificado = 0)
  ORDER BY a.fdFecha DESC
  LIMIT v_lim;
END$$

CREATE PROCEDURE sp_sla_alertas_contar(IN p_fbSoloNoNotificadas TINYINT)
BEGIN
  DECLARE v_total INT DEFAULT 0;
  SELECT COUNT(*) INTO v_total
  FROM slaalerta a
  WHERE (IFNULL(p_fbSoloNoNotificadas, 0) = 0 OR a.fbNotificado = 0);

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces,
         CONCAT('{"total":', v_total, '}') AS fjData;
  SELECT v_total AS fiTotal;
END$$

DELIMITER ;
