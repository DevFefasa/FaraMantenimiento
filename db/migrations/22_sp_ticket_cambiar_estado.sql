-- 22_sp_ticket_cambiar_estado.sql
SET NAMES utf8mb4;
DROP PROCEDURE IF EXISTS sp_ticket_cambiar_estado;
DELIMITER $$
CREATE PROCEDURE sp_ticket_cambiar_estado(
  IN p_fiTicketId INT,
  IN p_fcEstadoCodigo VARCHAR(30),
  IN p_fiMotivoEsperaId INT,
  IN p_fcComentario VARCHAR(500),
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_estadoActId INT;
  DECLARE v_estadoActCod VARCHAR(30);
  DECLARE v_estadoNuevoId INT;
  DECLARE v_estadoNuevoCod VARCHAR(30);
  DECLARE v_fbFinalAct TINYINT;
  DECLARE v_ok TINYINT DEFAULT 0;
  DECLARE v_min INT DEFAULT 0;
  DECLARE v_histId INT;
  DECLARE v_limResp DATETIME;
  DECLARE v_limSol DATETIME;
  DECLARE v_iniEsp DATETIME;
  DECLARE v_minEsp INT;
  DECLARE v_priResp DATETIME;
  DECLARE v_esEspera TINYINT DEFAULT 0;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al cambiar el estado del ticket' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  IF p_fiTicketId IS NULL OR p_fiTicketId <= 0 OR NOT EXISTS (SELECT 1 FROM ticket WHERE fiId = p_fiTicketId AND fbActivo = 1) THEN
    SELECT 404 AS fiCodigo, 'El ticket no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF TRIM(IFNULL(p_fcEstadoCodigo,'')) = '' THEN
    SELECT 400 AS fiCodigo, 'El estado destino es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;

  SELECT t.fiEstadoId, e.fcCodigo, e.fbFinal, t.fdLimiteRespuesta, t.fdLimiteSolucion, t.fdInicioEspera, t.fiMinutosEnEspera, t.fdPrimeraRespuesta
  INTO v_estadoActId, v_estadoActCod, v_fbFinalAct, v_limResp, v_limSol, v_iniEsp, v_minEsp, v_priResp
  FROM ticket t INNER JOIN estado e ON e.fiId = t.fiEstadoId
  WHERE t.fiId = p_fiTicketId;

  IF v_fbFinalAct = 1 THEN
    SELECT 409 AS fiCodigo, 'El ticket ya está en un estado final' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;

  SET v_estadoNuevoCod = UPPER(TRIM(p_fcEstadoCodigo));
  SELECT fiId INTO v_estadoNuevoId FROM estado WHERE fcCodigo = v_estadoNuevoCod AND fbActivo = 1 LIMIT 1;
  IF v_estadoNuevoId IS NULL THEN
    SELECT 400 AS fiCodigo, 'El estado destino no es válido' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;

  IF v_estadoActCod = 'RECIBIDO' AND v_estadoNuevoCod = 'EN_EVALUACION' THEN SET v_ok = 1; END IF;
  IF v_estadoActCod = 'EN_EVALUACION' AND v_estadoNuevoCod IN ('APROBADO','RECHAZADO') THEN SET v_ok = 1; END IF;
  IF v_estadoActCod = 'APROBADO' AND v_estadoNuevoCod = 'ASIGNADO' THEN SET v_ok = 1; END IF;
  IF v_estadoActCod = 'ASIGNADO' AND v_estadoNuevoCod = 'EN_PROCESO' THEN SET v_ok = 1; END IF;
  IF v_estadoActCod = 'EN_PROCESO' AND v_estadoNuevoCod IN ('EN_ESPERA','RESUELTO') THEN SET v_ok = 1; END IF;
  IF v_estadoActCod = 'EN_ESPERA' AND v_estadoNuevoCod = 'EN_PROCESO' THEN SET v_ok = 1; END IF;
  IF v_estadoActCod = 'RESUELTO' AND v_estadoNuevoCod IN ('VALIDADO','EN_PROCESO') THEN SET v_ok = 1; END IF;
  IF v_estadoActCod = 'VALIDADO' AND v_estadoNuevoCod = 'CERRADO' THEN SET v_ok = 1; END IF;

  IF v_ok = 0 THEN
    SELECT 409 AS fiCodigo, CONCAT('No se puede pasar de ', v_estadoActCod, ' a ', v_estadoNuevoCod) AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  IF v_estadoNuevoCod = 'EN_ESPERA' THEN
    SET v_esEspera = 1;
    IF p_fiMotivoEsperaId IS NULL OR p_fiMotivoEsperaId <= 0 OR NOT EXISTS (SELECT 1 FROM motivoespera WHERE fiId = p_fiMotivoEsperaId AND fbActivo = 1) THEN
      SELECT 400 AS fiCodigo, 'Debe indicar el motivo de espera' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
  END IF;

  START TRANSACTION;

  -- Salir de espera: acumular minutos y correr límites
  IF v_estadoActCod = 'EN_ESPERA' AND v_iniEsp IS NOT NULL THEN
    SET v_min = TIMESTAMPDIFF(MINUTE, v_iniEsp, NOW());
    IF v_min < 0 THEN SET v_min = 0; END IF;
    SET v_minEsp = IFNULL(v_minEsp, 0) + v_min;
    IF v_limResp IS NOT NULL THEN SET v_limResp = DATE_ADD(v_limResp, INTERVAL v_min MINUTE); END IF;
    IF v_limSol IS NOT NULL THEN SET v_limSol = DATE_ADD(v_limSol, INTERVAL v_min MINUTE); END IF;
  END IF;

  UPDATE ticket SET
    fiEstadoId = v_estadoNuevoId,
    fiMotivoEsperaId = IF(v_esEspera = 1, p_fiMotivoEsperaId, NULL),
    fdInicioEspera = IF(v_esEspera = 1, NOW(), NULL),
    fiMinutosEnEspera = v_minEsp,
    fdLimiteRespuesta = v_limResp,
    fdLimiteSolucion = v_limSol,
    fdPrimeraRespuesta = IF(v_priResp IS NULL, NOW(), v_priResp),
    fbSlaRespuestaCumplido = IF(v_priResp IS NULL, IF(NOW() <= IFNULL(v_limResp, NOW()), 1, 0), fbSlaRespuestaCumplido),
    fdResuelto = IF(v_estadoNuevoCod = 'RESUELTO', NOW(), IF(v_estadoNuevoCod = 'EN_PROCESO' AND v_estadoActCod = 'RESUELTO', NULL, fdResuelto)),
    fbSlaSolucionCumplido = IF(v_estadoNuevoCod = 'RESUELTO', IF(NOW() <= IFNULL(v_limSol, NOW()), 1, 0),
                              IF(v_estadoNuevoCod = 'EN_PROCESO' AND v_estadoActCod = 'RESUELTO', NULL, fbSlaSolucionCumplido)),
    fdValidado = IF(v_estadoNuevoCod = 'VALIDADO', NOW(), fdValidado),
    fdCerrado = IF(v_estadoNuevoCod = 'CERRADO', NOW(), fdCerrado),
    fdModificado = NOW(),
    fiModificadoPor = p_fiUsuarioId
  WHERE fiId = p_fiTicketId;

  INSERT INTO ticketestado (fiTicketId, fiEstadoAnteriorId, fiEstadoId, fiMotivoEsperaId, fcComentario, fiUsuarioId, fdFecha)
  VALUES (
    p_fiTicketId, v_estadoActId, v_estadoNuevoId,
    IF(v_esEspera = 1, p_fiMotivoEsperaId, NULL),
    NULLIF(TRIM(p_fcComentario),''),
    p_fiUsuarioId, NOW()
  );
  SET v_histId = LAST_INSERT_ID();

  COMMIT;
  SELECT 200 AS fiCodigo, 'Estado actualizado correctamente' AS fcMensaje, 1 AS fbSucces,
         JSON_OBJECT('ticket', p_fiTicketId, 'ticketestado', JSON_ARRAY(v_histId), 'estado', v_estadoNuevoCod) AS fjData;
END$$
DELIMITER ;
