-- 23_sp_ticket_asignar_prioridad.sql
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

  SELECT t.fiEstadoId, e.fcCodigo INTO v_estadoId, v_estadoCod
  FROM ticket t JOIN estado e ON e.fiId = t.fiEstadoId WHERE t.fiId = p_fiTicketId;
  IF v_estadoCod NOT IN ('APROBADO','ASIGNADO','EN_PROCESO') THEN
    SELECT 409 AS fiCodigo, 'El ticket no puede asignarse en su estado actual' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  SELECT fiId INTO v_asignadoId FROM estado WHERE fcCodigo = 'ASIGNADO' AND fbActivo = 1 LIMIT 1;

  START TRANSACTION;
  UPDATE ticket SET
    fcTipoResponsable = v_tipo,
    fiTecnicoId = IF(v_tipo = 'INTERNO', p_fiTecnicoId, NULL),
    fiProveedorId = IF(v_tipo = 'PROVEEDOR', p_fiProveedorId, NULL),
    fdFechaProgramada = p_fdFechaProgramada,
    fiEstadoId = IF(v_estadoCod = 'APROBADO', v_asignadoId, fiEstadoId),
    fdPrimeraRespuesta = IF(fdPrimeraRespuesta IS NULL AND v_estadoCod = 'APROBADO', NOW(), fdPrimeraRespuesta),
    fbSlaRespuestaCumplido = IF(fdPrimeraRespuesta IS NULL AND v_estadoCod = 'APROBADO', IF(NOW() <= IFNULL(fdLimiteRespuesta, NOW()), 1, 0), fbSlaRespuestaCumplido),
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
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; SELECT 500 AS fiCodigo, 'Ocurrió un error al cambiar la prioridad' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;

  IF p_fiTicketId IS NULL OR NOT EXISTS (SELECT 1 FROM ticket WHERE fiId = p_fiTicketId AND fbActivo = 1) THEN
    SELECT 404 AS fiCodigo, 'El ticket no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF p_fiPrioridadId IS NULL OR NOT EXISTS (SELECT 1 FROM prioridad WHERE fiId = p_fiPrioridadId AND fbActivo = 1) THEN
    SELECT 400 AS fiCodigo, 'La prioridad no es válida' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF EXISTS (SELECT 1 FROM ticket t JOIN estado e ON e.fiId = t.fiEstadoId WHERE t.fiId = p_fiTicketId AND e.fbFinal = 1) THEN
    SELECT 409 AS fiCodigo, 'No se puede cambiar la prioridad de un ticket cerrado' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;

  SELECT fiHorasRespuesta, fiHorasSolucion INTO v_horasResp, v_horasSol FROM prioridad WHERE fiId = p_fiPrioridadId;
  SELECT fdFechaIngreso, IFNULL(fiMinutosEnEspera,0) INTO v_ingreso, v_minEsp FROM ticket WHERE fiId = p_fiTicketId;

  START TRANSACTION;
  UPDATE ticket SET
    fiPrioridadId = p_fiPrioridadId,
    fdLimiteRespuesta = DATE_ADD(DATE_ADD(v_ingreso, INTERVAL v_horasResp HOUR), INTERVAL v_minEsp MINUTE),
    fdLimiteSolucion = DATE_ADD(DATE_ADD(v_ingreso, INTERVAL v_horasSol HOUR), INTERVAL v_minEsp MINUTE),
    fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId
  WHERE fiId = p_fiTicketId;
  COMMIT;
  SELECT 200 AS fiCodigo, 'Prioridad actualizada correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('ticket', p_fiTicketId) AS fjData;
END$$
DELIMITER ;
