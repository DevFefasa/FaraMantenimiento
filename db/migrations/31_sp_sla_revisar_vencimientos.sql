-- 31_sp_sla_revisar_vencimientos.sql
-- Callers: SlaServicio.RevisarVencimientosAsync; SlaTarea (cada 5 min)
-- API: sp_sla_revisar_vencimientos(p_fdAhora)
-- Schema: UPDATE ticket.fbSla*Cumplido; INSERT slaalerta POR_VENCER/VENCIDO_RESPUESTA/VENCIDO_SOLUCION
-- User instruction: "sp_sla_revisar_vencimientos(p_fdAhora): marca fbSlaRespuestaCumplido=0 ... POR_VENCER cuando se consumio >=75%"
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_sla_revisar_vencimientos;

DELIMITER $$

CREATE PROCEDURE sp_sla_revisar_vencimientos(IN p_fdAhora DATETIME)
proc: BEGIN
  DECLARE v_ahora DATETIME;
  DECLARE v_resp INT DEFAULT 0;
  DECLARE v_sol INT DEFAULT 0;
  DECLARE v_alertas INT DEFAULT 0;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al revisar vencimientos SLA' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  SET v_ahora = IFNULL(p_fdAhora, NOW());
  START TRANSACTION;

  UPDATE ticket t
  JOIN estado e ON e.fiId = t.fiEstadoId
  SET t.fbSlaRespuestaCumplido = 0, t.fdModificado = v_ahora
  WHERE t.fbActivo = 1 AND IFNULL(e.fbFinal, 0) = 0
    AND t.fdPrimeraRespuesta IS NULL AND t.fdLimiteRespuesta IS NOT NULL
    AND v_ahora > t.fdLimiteRespuesta
    AND (t.fbSlaRespuestaCumplido IS NULL OR t.fbSlaRespuestaCumplido = 1);
  SET v_resp = ROW_COUNT();

  INSERT IGNORE INTO slaalerta (fiTicketId, fcTipo, fdFecha, fbNotificado, fcDetalle)
  SELECT t.fiId, 'VENCIDO_RESPUESTA', v_ahora, 0, CONCAT('Límite respuesta: ', t.fdLimiteRespuesta)
  FROM ticket t JOIN estado e ON e.fiId = t.fiEstadoId
  WHERE t.fbActivo = 1 AND IFNULL(e.fbFinal, 0) = 0
    AND t.fdPrimeraRespuesta IS NULL AND t.fdLimiteRespuesta IS NOT NULL AND v_ahora > t.fdLimiteRespuesta;
  SET v_alertas = v_alertas + ROW_COUNT();

  UPDATE ticket t
  JOIN estado e ON e.fiId = t.fiEstadoId
  SET t.fbSlaSolucionCumplido = 0, t.fdModificado = v_ahora
  WHERE t.fbActivo = 1 AND IFNULL(e.fbFinal, 0) = 0
    AND e.fcCodigo NOT IN ('RESUELTO', 'VALIDADO', 'CERRADO', 'RECHAZADO', 'EN_ESPERA')
    AND t.fdResuelto IS NULL AND t.fdLimiteSolucion IS NOT NULL AND v_ahora > t.fdLimiteSolucion
    AND (t.fbSlaSolucionCumplido IS NULL OR t.fbSlaSolucionCumplido = 1);
  SET v_sol = ROW_COUNT();

  INSERT IGNORE INTO slaalerta (fiTicketId, fcTipo, fdFecha, fbNotificado, fcDetalle)
  SELECT t.fiId, 'VENCIDO_SOLUCION', v_ahora, 0, CONCAT('Límite solución: ', t.fdLimiteSolucion)
  FROM ticket t JOIN estado e ON e.fiId = t.fiEstadoId
  WHERE t.fbActivo = 1 AND IFNULL(e.fbFinal, 0) = 0
    AND e.fcCodigo NOT IN ('RESUELTO', 'VALIDADO', 'CERRADO', 'RECHAZADO', 'EN_ESPERA')
    AND t.fdResuelto IS NULL AND t.fdLimiteSolucion IS NOT NULL AND v_ahora > t.fdLimiteSolucion;
  SET v_alertas = v_alertas + ROW_COUNT();

  INSERT IGNORE INTO slaalerta (fiTicketId, fcTipo, fdFecha, fbNotificado, fcDetalle)
  SELECT t.fiId, 'POR_VENCER', v_ahora, 0, 'Respuesta al 75% del SLA'
  FROM ticket t JOIN estado e ON e.fiId = t.fiEstadoId
  WHERE t.fbActivo = 1 AND IFNULL(e.fbFinal, 0) = 0
    AND t.fdPrimeraRespuesta IS NULL AND t.fdLimiteRespuesta IS NOT NULL
    AND v_ahora <= t.fdLimiteRespuesta
    AND TIMESTAMPDIFF(SECOND, t.fdFechaIngreso, t.fdLimiteRespuesta) > 0
    AND TIMESTAMPDIFF(SECOND, t.fdFechaIngreso, v_ahora)
        >= 0.75 * TIMESTAMPDIFF(SECOND, t.fdFechaIngreso, t.fdLimiteRespuesta);
  SET v_alertas = v_alertas + ROW_COUNT();

  INSERT IGNORE INTO slaalerta (fiTicketId, fcTipo, fdFecha, fbNotificado, fcDetalle)
  SELECT t.fiId, 'POR_VENCER', v_ahora, 0, 'Solución al 75% del SLA'
  FROM ticket t JOIN estado e ON e.fiId = t.fiEstadoId
  WHERE t.fbActivo = 1 AND IFNULL(e.fbFinal, 0) = 0
    AND e.fcCodigo NOT IN ('RESUELTO', 'VALIDADO', 'CERRADO', 'RECHAZADO', 'EN_ESPERA')
    AND t.fdResuelto IS NULL AND t.fdLimiteSolucion IS NOT NULL
    AND v_ahora <= t.fdLimiteSolucion
    AND TIMESTAMPDIFF(SECOND, t.fdFechaIngreso, t.fdLimiteSolucion) > 0
    AND TIMESTAMPDIFF(SECOND, t.fdFechaIngreso, v_ahora)
        >= 0.75 * TIMESTAMPDIFF(SECOND, t.fdFechaIngreso, t.fdLimiteSolucion);
  SET v_alertas = v_alertas + ROW_COUNT();

  COMMIT;
  SELECT 200 AS fiCodigo, 'Revisión SLA completada' AS fcMensaje, 1 AS fbSucces,
         CONCAT('{"respuestaVencida":', v_resp, ',"solucionVencida":', v_sol, ',"alertasNuevas":', v_alertas, '}') AS fjData;
END$$

DELIMITER ;
