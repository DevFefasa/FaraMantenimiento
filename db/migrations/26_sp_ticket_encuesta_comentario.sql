-- 26_sp_ticket_encuesta_comentario.sql
SET NAMES utf8mb4;
DROP PROCEDURE IF EXISTS sp_ticket_encuesta_guardar;
DROP PROCEDURE IF EXISTS sp_ticket_comentario_agregar;
DELIMITER $$
CREATE PROCEDURE sp_ticket_encuesta_guardar(
  IN p_fiTicketId INT,
  IN p_fiCalificacion TINYINT,
  IN p_fbConforme TINYINT,
  IN p_fcComentario VARCHAR(500),
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_estadoId INT; DECLARE v_estadoCod VARCHAR(30); DECLARE v_sol INT;
  DECLARE v_nuevoId INT; DECLARE v_nuevoCod VARCHAR(30); DECLARE v_histId INT; DECLARE v_encId INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; SELECT 500 AS fiCodigo, 'Ocurrió un error al guardar la encuesta' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;

  IF p_fiTicketId IS NULL OR NOT EXISTS (SELECT 1 FROM ticket WHERE fiId = p_fiTicketId AND fbActivo = 1) THEN
    SELECT 404 AS fiCodigo, 'El ticket no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF p_fiCalificacion IS NULL OR p_fiCalificacion < 1 OR p_fiCalificacion > 5 THEN
    SELECT 400 AS fiCodigo, 'La calificación debe ser entre 1 y 5' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;

  SELECT t.fiEstadoId, e.fcCodigo, t.fiSolicitanteId INTO v_estadoId, v_estadoCod, v_sol
  FROM ticket t JOIN estado e ON e.fiId = t.fiEstadoId WHERE t.fiId = p_fiTicketId;
  IF v_estadoCod <> 'RESUELTO' THEN
    SELECT 409 AS fiCodigo, 'Solo se puede encuestar un ticket en estado RESUELTO' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF v_sol IS NULL OR v_sol <> p_fiUsuarioId THEN
    SELECT 403 AS fiCodigo, 'Solo el solicitante puede responder la encuesta' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF EXISTS (SELECT 1 FROM ticketencuesta WHERE fiTicketId = p_fiTicketId) THEN
    SELECT 409 AS fiCodigo, 'El ticket ya tiene encuesta' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;

  IF IFNULL(p_fbConforme,0) = 1 THEN SET v_nuevoCod = 'VALIDADO'; ELSE SET v_nuevoCod = 'EN_PROCESO'; END IF;
  SELECT fiId INTO v_nuevoId FROM estado WHERE fcCodigo = v_nuevoCod AND fbActivo = 1 LIMIT 1;

  START TRANSACTION;
  INSERT INTO ticketencuesta (fiTicketId, fiCalificacion, fbConforme, fcComentario, fdFecha, fiUsuarioId)
  VALUES (p_fiTicketId, p_fiCalificacion, IF(IFNULL(p_fbConforme,0)=1,1,0), NULLIF(TRIM(p_fcComentario),''), NOW(), p_fiUsuarioId);
  SET v_encId = LAST_INSERT_ID();

  UPDATE ticket SET
    fiEstadoId = v_nuevoId,
    fdValidado = IF(v_nuevoCod = 'VALIDADO', NOW(), fdValidado),
    fdResuelto = IF(v_nuevoCod = 'EN_PROCESO', NULL, fdResuelto),
    fbSlaSolucionCumplido = IF(v_nuevoCod = 'EN_PROCESO', NULL, fbSlaSolucionCumplido),
    fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId
  WHERE fiId = p_fiTicketId;

  INSERT INTO ticketestado (fiTicketId, fiEstadoAnteriorId, fiEstadoId, fcComentario, fiUsuarioId, fdFecha)
  VALUES (p_fiTicketId, v_estadoId, v_nuevoId,
          IF(v_nuevoCod='VALIDADO', CONCAT('Validado por solicitante (', p_fiCalificacion, ' estrellas)'),
             CONCAT('Rechazado por solicitante: ', IFNULL(NULLIF(TRIM(p_fcComentario),''), 'Sin comentario'))),
          p_fiUsuarioId, NOW());
  SET v_histId = LAST_INSERT_ID();
  COMMIT;
  SELECT 200 AS fiCodigo, IF(v_nuevoCod='VALIDADO','Encuesta registrada y ticket validado','Encuesta registrada; el ticket vuelve a proceso') AS fcMensaje,
         1 AS fbSucces, JSON_OBJECT('ticketencuesta', v_encId, 'ticket', p_fiTicketId, 'ticketestado', JSON_ARRAY(v_histId)) AS fjData;
END$$

CREATE PROCEDURE sp_ticket_comentario_agregar(
  IN p_fiTicketId INT,
  IN p_fcComentario TEXT,
  IN p_fbInterno TINYINT,
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_id INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; SELECT 500 AS fiCodigo, 'Ocurrió un error al agregar el comentario' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;
  IF p_fiTicketId IS NULL OR NOT EXISTS (SELECT 1 FROM ticket WHERE fiId = p_fiTicketId AND fbActivo = 1) THEN
    SELECT 404 AS fiCodigo, 'El ticket no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF TRIM(IFNULL(p_fcComentario,'')) = '' THEN
    SELECT 400 AS fiCodigo, 'El comentario es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  START TRANSACTION;
  INSERT INTO ticketcomentario (fiTicketId, fcComentario, fbInterno, fiUsuarioId, fdFecha, fbActivo)
  VALUES (p_fiTicketId, TRIM(p_fcComentario), IF(IFNULL(p_fbInterno,0)=1,1,0), p_fiUsuarioId, NOW(), 1);
  SET v_id = LAST_INSERT_ID();
  COMMIT;
  SELECT 201 AS fiCodigo, 'Comentario agregado' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('ticketcomentario', v_id, 'ticket', p_fiTicketId) AS fjData;
END$$
DELIMITER ;
