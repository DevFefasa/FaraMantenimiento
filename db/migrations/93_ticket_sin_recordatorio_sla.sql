-- 93_ticket_sin_recordatorio_sla.sql
-- Opción por ticket para dejar de enviar el recordatorio diario de SLA vencido.
--  - ticket.fbSinRecordatorioSla (+ quién y cuándo fue el último cambio).
--  - sp_ticket_recordatorio_sla_obtener / sp_ticket_recordatorio_sla_cambiar (ADMIN, JEFATURA, MANTENIMIENTO);
--    el cambio queda como comentario interno en ticketcomentario.
--  - sp_sla_revisar_vencimientos (versión de 69) con el recordatorio apagado solo crea la PRIMERA alerta
--    VENCIDO_* del ticket (que sí se envía); no crea una por día. Sin alerta nueva no hay correo nuevo.
--    El valor se conserva en cambios de estado; en estados finales/RESUELTO ya no se generan alertas.
SET NAMES utf8mb4;

ALTER TABLE ticket
  ADD COLUMN IF NOT EXISTS fbSinRecordatorioSla TINYINT(1) NOT NULL DEFAULT 0 COMMENT '1 = no enviar recordatorio diario de SLA vencido',
  ADD COLUMN IF NOT EXISTS fiSinRecordatorioSlaPor INT NULL COMMENT 'Usuario del último cambio de fbSinRecordatorioSla',
  ADD COLUMN IF NOT EXISTS fdSinRecordatorioSla DATETIME NULL COMMENT 'Fecha del último cambio de fbSinRecordatorioSla';

DROP PROCEDURE IF EXISTS sp_ticket_recordatorio_sla_obtener;
DROP PROCEDURE IF EXISTS sp_ticket_recordatorio_sla_cambiar;

DELIMITER $$

-- Estado del recordatorio para la pantalla de detalle.
-- fbVencido: algún límite (respuesta o solución) superado; fbAplica: el ticket no está resuelto ni cerrado.
CREATE PROCEDURE sp_ticket_recordatorio_sla_obtener(IN p_fiTicketId INT)
proc: BEGIN
  IF NOT EXISTS (SELECT 1 FROM ticket WHERE fiId = p_fiTicketId AND fbActivo = 1) THEN
    SELECT 404 AS fiCodigo, 'El ticket no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('ticket', p_fiTicketId) AS fjData;
  SELECT t.fiId AS fiTicketId, t.fbSinRecordatorioSla, t.fdSinRecordatorioSla, u.fcNombre AS fcSinRecordatorioSlaPor,
         IF((t.fdPrimeraRespuesta IS NULL AND t.fdLimiteRespuesta IS NOT NULL AND NOW() > t.fdLimiteRespuesta)
            OR (t.fdResuelto IS NULL AND t.fdLimiteSolucion IS NOT NULL AND NOW() > t.fdLimiteSolucion)
            OR t.fbSlaRespuestaCumplido = 0 OR t.fbSlaSolucionCumplido = 0, 1, 0) AS fbVencido,
         IF(IFNULL(e.fbFinal, 0) = 0 AND e.fcCodigo <> 'RESUELTO', 1, 0) AS fbAplica
  FROM ticket t
  JOIN estado e ON e.fiId = t.fiEstadoId
  LEFT JOIN usuario u ON u.fiId = t.fiSinRecordatorioSlaPor
  WHERE t.fiId = p_fiTicketId;
END$$

-- Activa (p_fbSinRecordatorio = 0) o desactiva (= 1) el recordatorio diario. Solo ADMIN, JEFATURA, MANTENIMIENTO.
CREATE PROCEDURE sp_ticket_recordatorio_sla_cambiar(IN p_fiTicketId INT, IN p_fbSinRecordatorio TINYINT, IN p_fiUsuarioId INT)
proc: BEGIN
  DECLARE v_rol VARCHAR(30) DEFAULT NULL;
  DECLARE v_estado VARCHAR(30) DEFAULT NULL;
  DECLARE v_final TINYINT DEFAULT 0;
  DECLARE v_actual TINYINT DEFAULT 0;
  DECLARE v_nuevo TINYINT;
  DECLARE v_texto VARCHAR(100);
  DECLARE v_comId INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al cambiar los recordatorios de SLA' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  SET v_nuevo = IF(IFNULL(p_fbSinRecordatorio, 0) = 1, 1, 0);

  SELECT r.fcCodigo INTO v_rol
  FROM usuario u JOIN rol r ON r.fiId = u.fiRolId AND r.fbActivo = 1
  WHERE u.fiId = p_fiUsuarioId AND u.fbActivo = 1
  LIMIT 1;
  IF v_rol IS NULL OR v_rol NOT IN ('ADMIN', 'JEFATURA', 'MANTENIMIENTO') THEN
    SELECT 403 AS fiCodigo, 'No tiene permiso para cambiar los recordatorios de SLA' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;

  START TRANSACTION;
  SELECT e.fcCodigo, IFNULL(e.fbFinal, 0), t.fbSinRecordatorioSla INTO v_estado, v_final, v_actual
  FROM ticket t JOIN estado e ON e.fiId = t.fiEstadoId
  WHERE t.fiId = p_fiTicketId AND t.fbActivo = 1
  FOR UPDATE;

  IF v_estado IS NULL THEN
    ROLLBACK;
    SELECT 404 AS fiCodigo, 'El ticket no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF v_final = 1 OR v_estado = 'RESUELTO' THEN
    ROLLBACK;
    SELECT 409 AS fiCodigo, 'El ticket está resuelto o cerrado; los recordatorios de SLA ya no aplican' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF v_actual = v_nuevo THEN
    ROLLBACK;
    SELECT 200 AS fiCodigo, IF(v_nuevo = 1, 'Los recordatorios de SLA ya estaban desactivados', 'Los recordatorios de SLA ya estaban activados') AS fcMensaje,
           1 AS fbSucces, JSON_OBJECT('ticket', p_fiTicketId, 'fbSinRecordatorioSla', v_nuevo) AS fjData;
    LEAVE proc;
  END IF;

  SET v_texto = IF(v_nuevo = 1, 'Recordatorios de SLA desactivados', 'Recordatorios de SLA activados');
  UPDATE ticket
     SET fbSinRecordatorioSla = v_nuevo, fiSinRecordatorioSlaPor = p_fiUsuarioId, fdSinRecordatorioSla = NOW(),
         fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId
   WHERE fiId = p_fiTicketId;
  INSERT INTO ticketcomentario (fiTicketId, fcComentario, fbInterno, fiUsuarioId, fdFecha, fbActivo)
  VALUES (p_fiTicketId, v_texto, 1, p_fiUsuarioId, NOW(), 1);
  SET v_comId = LAST_INSERT_ID();
  COMMIT;

  SELECT 200 AS fiCodigo, v_texto AS fcMensaje, 1 AS fbSucces,
         JSON_OBJECT('ticket', p_fiTicketId, 'ticketcomentario', v_comId, 'fbSinRecordatorioSla', v_nuevo) AS fjData;
END$$

DELIMITER ;

-- sp_sla_revisar_vencimientos: igual a la versión de 69 + regla de recordatorio apagado.
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
    AND t.fdPrimeraRespuesta IS NULL AND t.fdLimiteRespuesta IS NOT NULL AND v_ahora > t.fdLimiteRespuesta
    -- Recordatorio apagado: solo la primera alerta de vencimiento (no una por día).
    AND (IFNULL(t.fbSinRecordatorioSla, 0) = 0
         OR NOT EXISTS (SELECT 1 FROM slaalerta x WHERE x.fiTicketId = t.fiId AND x.fcTipo = 'VENCIDO_RESPUESTA'));
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
    AND t.fdResuelto IS NULL AND t.fdLimiteSolucion IS NOT NULL AND v_ahora > t.fdLimiteSolucion
    AND (IFNULL(t.fbSinRecordatorioSla, 0) = 0
         OR NOT EXISTS (SELECT 1 FROM slaalerta x WHERE x.fiTicketId = t.fiId AND x.fcTipo = 'VENCIDO_SOLUCION'));
  SET v_alertas = v_alertas + ROW_COUNT();

  INSERT IGNORE INTO slaalerta (fiTicketId, fcTipo, fdFecha, fbNotificado, fcDetalle)
  SELECT t.fiId, 'POR_VENCER_RESPUESTA', v_ahora, 0, 'Respuesta al 75% del SLA'
  FROM ticket t JOIN estado e ON e.fiId = t.fiEstadoId
  WHERE t.fbActivo = 1 AND IFNULL(e.fbFinal, 0) = 0
    AND t.fdPrimeraRespuesta IS NULL AND t.fdLimiteRespuesta IS NOT NULL
    AND v_ahora <= t.fdLimiteRespuesta
    AND TIMESTAMPDIFF(SECOND, t.fdFechaIngreso, t.fdLimiteRespuesta) > 0
    AND GREATEST(0, TIMESTAMPDIFF(SECOND, t.fdFechaIngreso, v_ahora) - IFNULL(t.fiMinutosEnEspera,0) * 60)
        >= 0.75 * TIMESTAMPDIFF(SECOND, t.fdFechaIngreso, t.fdLimiteRespuesta);
  SET v_alertas = v_alertas + ROW_COUNT();

  INSERT IGNORE INTO slaalerta (fiTicketId, fcTipo, fdFecha, fbNotificado, fcDetalle)
  SELECT t.fiId, 'POR_VENCER_SOLUCION', v_ahora, 0, 'Solución al 75% del SLA'
  FROM ticket t JOIN estado e ON e.fiId = t.fiEstadoId
  WHERE t.fbActivo = 1 AND IFNULL(e.fbFinal, 0) = 0
    AND e.fcCodigo NOT IN ('RESUELTO', 'VALIDADO', 'CERRADO', 'RECHAZADO', 'EN_ESPERA')
    AND t.fdResuelto IS NULL AND t.fdLimiteSolucion IS NOT NULL
    AND v_ahora <= t.fdLimiteSolucion
    AND TIMESTAMPDIFF(SECOND, t.fdFechaIngreso, t.fdLimiteSolucion) > 0
    AND GREATEST(0, TIMESTAMPDIFF(SECOND, t.fdFechaIngreso, v_ahora) - IFNULL(t.fiMinutosEnEspera,0) * 60)
        >= 0.75 * TIMESTAMPDIFF(SECOND, t.fdFechaIngreso, t.fdLimiteSolucion);
  SET v_alertas = v_alertas + ROW_COUNT();

  COMMIT;
  SELECT 200 AS fiCodigo, 'Revisión SLA completada' AS fcMensaje, 1 AS fbSucces,
         JSON_OBJECT('respuestaVencida', v_resp, 'solucionVencida', v_sol, 'alertasNuevas', v_alertas) AS fjData;
END$$

DELIMITER ;
