-- 67_sp_ticket_asignar_prioridad_lock.sql
-- Callers: TicketRepositorio asignar/prioridad
-- Corrige: M6 (FOR UPDATE), B9 (SLA en variables), B10 (auditoría, solo antes de RESUELTO, recalcular banderas)
SET NAMES utf8mb4;
DROP PROCEDURE IF EXISTS sp_ticket_asignar;
DROP PROCEDURE IF EXISTS sp_ticket_cambiar_prioridad;
DELIMITER $$

CREATE PROCEDURE sp_ticket_asignar(
  IN p_fiTicketId INT,
  IN p_fcTipoResponsable VARCHAR(20),
  IN p_fiTecnicoId INT,
  IN p_fiProveedorId INT,
  IN p_fdFechaProgramada DATETIME,
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_estadoId INT; DECLARE v_estadoCod VARCHAR(30); DECLARE v_tipo VARCHAR(20);
  DECLARE v_asignadoId INT; DECLARE v_histId INT; DECLARE v_antId INT;
  DECLARE v_priResp DATETIME; DECLARE v_limResp DATETIME;
  DECLARE v_nuevaPri DATETIME; DECLARE v_slaResp TINYINT;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; SELECT 500 AS fiCodigo, 'Ocurrió un error al asignar el ticket' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;

  IF p_fiTicketId IS NULL OR NOT EXISTS (SELECT 1 FROM ticket WHERE fiId = p_fiTicketId AND fbActivo = 1) THEN
    SELECT 404 AS fiCodigo, 'El ticket no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  SET v_tipo = UPPER(TRIM(IFNULL(p_fcTipoResponsable,'')));
  IF v_tipo NOT IN ('INTERNO','PROVEEDOR') THEN
    SELECT 400 AS fiCodigo, 'El tipo de responsable debe ser INTERNO o PROVEEDOR' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF v_tipo = 'INTERNO' AND (p_fiTecnicoId IS NULL OR p_fiTecnicoId <= 0 OR NOT EXISTS (SELECT 1 FROM tecnico WHERE fiId = p_fiTecnicoId AND fbActivo = 1)) THEN
    SELECT 400 AS fiCodigo, 'Debe indicar un técnico válido' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF v_tipo = 'PROVEEDOR' AND (p_fiProveedorId IS NULL OR p_fiProveedorId <= 0 OR NOT EXISTS (SELECT 1 FROM proveedor WHERE fiId = p_fiProveedorId AND fbActivo = 1)) THEN
    SELECT 400 AS fiCodigo, 'Debe indicar un proveedor válido' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  SELECT fiId INTO v_asignadoId FROM estado WHERE fcCodigo = 'ASIGNADO' AND fbActivo = 1 LIMIT 1;

  START TRANSACTION;

  SELECT t.fiEstadoId, e.fcCodigo, t.fdPrimeraRespuesta, t.fdLimiteRespuesta
  INTO v_estadoId, v_estadoCod, v_priResp, v_limResp
  FROM ticket t JOIN estado e ON e.fiId = t.fiEstadoId
  WHERE t.fiId = p_fiTicketId
  FOR UPDATE;

  IF v_estadoCod NOT IN ('APROBADO','ASIGNADO','EN_PROCESO') THEN
    ROLLBACK; SELECT 409 AS fiCodigo, 'El ticket no puede asignarse en su estado actual' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;

  IF v_priResp IS NULL AND v_estadoCod = 'APROBADO' THEN
    SET v_nuevaPri = NOW();
    SET v_slaResp = IF(NOW() <= IFNULL(v_limResp, NOW()), 1, 0);
  ELSE
    SET v_nuevaPri = v_priResp;
    SET v_slaResp = NULL;
  END IF;

  UPDATE ticket SET
    fcTipoResponsable = v_tipo,
    fiTecnicoId = IF(v_tipo = 'INTERNO', p_fiTecnicoId, NULL),
    fiProveedorId = IF(v_tipo = 'PROVEEDOR', p_fiProveedorId, NULL),
    fdFechaProgramada = p_fdFechaProgramada,
    fiEstadoId = IF(v_estadoCod = 'APROBADO', v_asignadoId, fiEstadoId),
    fdPrimeraRespuesta = IF(v_nuevaPri IS NOT NULL, v_nuevaPri, fdPrimeraRespuesta),
    fbSlaRespuestaCumplido = IF(v_slaResp IS NOT NULL, v_slaResp, fbSlaRespuestaCumplido),
    fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId
  WHERE fiId = p_fiTicketId;

  IF v_estadoCod = 'APROBADO' THEN
    SET v_antId = v_estadoId;
    INSERT INTO ticketestado (fiTicketId, fiEstadoAnteriorId, fiEstadoId, fcComentario, fiUsuarioId, fdFecha)
    VALUES (p_fiTicketId, v_antId, v_asignadoId, 'Ticket asignado', p_fiUsuarioId, NOW());
    SET v_histId = LAST_INSERT_ID();
  ELSE
    INSERT INTO ticketestado (fiTicketId, fiEstadoAnteriorId, fiEstadoId, fcComentario, fiUsuarioId, fdFecha)
    VALUES (p_fiTicketId, v_estadoId, v_estadoId, 'Responsable actualizado', p_fiUsuarioId, NOW());
    SET v_histId = LAST_INSERT_ID();
  END IF;
  COMMIT;
  SELECT 200 AS fiCodigo, 'Ticket asignado correctamente' AS fcMensaje, 1 AS fbSucces,
         JSON_OBJECT('ticket', p_fiTicketId, 'ticketestado', JSON_ARRAY(v_histId)) AS fjData;
END$$

CREATE PROCEDURE sp_ticket_cambiar_prioridad(
  IN p_fiTicketId INT,
  IN p_fiPrioridadId INT,
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_horasResp INT; DECLARE v_horasSol INT; DECLARE v_ingreso DATETIME; DECLARE v_minEsp INT;
  DECLARE v_estadoId INT; DECLARE v_estadoCod VARCHAR(30); DECLARE v_prioAnt INT; DECLARE v_histId INT;
  DECLARE v_limResp DATETIME; DECLARE v_limSol DATETIME;
  DECLARE v_priResp DATETIME; DECLARE v_resuelto DATETIME;
  DECLARE v_slaResp TINYINT; DECLARE v_slaSol TINYINT;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; SELECT 500 AS fiCodigo, 'Ocurrió un error al cambiar la prioridad' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;

  IF p_fiTicketId IS NULL OR NOT EXISTS (SELECT 1 FROM ticket WHERE fiId = p_fiTicketId AND fbActivo = 1) THEN
    SELECT 404 AS fiCodigo, 'El ticket no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF p_fiPrioridadId IS NULL OR NOT EXISTS (SELECT 1 FROM prioridad WHERE fiId = p_fiPrioridadId AND fbActivo = 1) THEN
    SELECT 400 AS fiCodigo, 'La prioridad no es válida' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;

  SELECT fiHorasRespuesta, fiHorasSolucion INTO v_horasResp, v_horasSol FROM prioridad WHERE fiId = p_fiPrioridadId;

  START TRANSACTION;

  SELECT t.fiEstadoId, e.fcCodigo, t.fiPrioridadId, t.fdFechaIngreso, IFNULL(t.fiMinutosEnEspera,0),
         t.fdPrimeraRespuesta, t.fdResuelto
  INTO v_estadoId, v_estadoCod, v_prioAnt, v_ingreso, v_minEsp, v_priResp, v_resuelto
  FROM ticket t JOIN estado e ON e.fiId = t.fiEstadoId
  WHERE t.fiId = p_fiTicketId
  FOR UPDATE;

  IF v_estadoCod IN ('RESUELTO','VALIDADO','CERRADO','RECHAZADO') OR EXISTS (
    SELECT 1 FROM estado e2 WHERE e2.fiId = v_estadoId AND e2.fbFinal = 1
  ) THEN
    ROLLBACK; SELECT 409 AS fiCodigo, 'No se puede cambiar la prioridad en el estado actual' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;

  SET v_limResp = DATE_ADD(DATE_ADD(v_ingreso, INTERVAL v_horasResp HOUR), INTERVAL v_minEsp MINUTE);
  SET v_limSol = DATE_ADD(DATE_ADD(v_ingreso, INTERVAL v_horasSol HOUR), INTERVAL v_minEsp MINUTE);

  IF v_priResp IS NOT NULL THEN
    SET v_slaResp = IF(v_priResp <= v_limResp, 1, 0);
  ELSE
    SET v_slaResp = NULL;
  END IF;
  IF v_resuelto IS NOT NULL THEN
    SET v_slaSol = IF(v_resuelto <= v_limSol, 1, 0);
  ELSE
    SET v_slaSol = NULL;
  END IF;

  UPDATE ticket SET
    fiPrioridadId = p_fiPrioridadId,
    fdLimiteRespuesta = v_limResp,
    fdLimiteSolucion = v_limSol,
    fbSlaRespuestaCumplido = IF(v_slaResp IS NOT NULL, v_slaResp, fbSlaRespuestaCumplido),
    fbSlaSolucionCumplido = IF(v_slaSol IS NOT NULL, v_slaSol, fbSlaSolucionCumplido),
    fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId
  WHERE fiId = p_fiTicketId;

  INSERT INTO ticketestado (fiTicketId, fiEstadoAnteriorId, fiEstadoId, fcComentario, fiUsuarioId, fdFecha)
  VALUES (p_fiTicketId, v_estadoId, v_estadoId,
          CONCAT('Cambio de prioridad (', IFNULL(v_prioAnt,0), ' → ', p_fiPrioridadId, ')'),
          p_fiUsuarioId, NOW());
  SET v_histId = LAST_INSERT_ID();
  COMMIT;
  SELECT 200 AS fiCodigo, 'Prioridad actualizada correctamente' AS fcMensaje, 1 AS fbSucces,
         JSON_OBJECT('ticket', p_fiTicketId, 'ticketestado', JSON_ARRAY(v_histId)) AS fjData;
END$$
DELIMITER ;
