-- 32_sp_ticket_cierre_automatico.sql
-- Callers: SlaServicio.CierreAutomaticoAsync; SlaTarea
-- API: sp_ticket_cierre_automatico(p_fdAhora)
-- Schema: RESUELTO + DIAS_CIERRE_AUTOMATICO → VALIDADO → CERRADO (fbCierreAutomatico=1) + ticketestado
-- User instruction: "sp_ticket_cierre_automatico(p_fdAhora): RESUELTO con fdResuelto + DIAS_CIERRE_AUTOMATICO dias -> VALIDADO y CERRADO con fbCierreAutomatico=1 e historial"
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_ticket_cierre_automatico;

DELIMITER $$

CREATE PROCEDURE sp_ticket_cierre_automatico(IN p_fdAhora DATETIME)
proc: BEGIN
  DECLARE v_ahora DATETIME;
  DECLARE v_dias INT DEFAULT 5;
  DECLARE v_usuarioId INT DEFAULT 1;
  DECLARE v_validadoId INT;
  DECLARE v_cerradoId INT;
  DECLARE v_cerrados INT DEFAULT 0;
  DECLARE done INT DEFAULT 0;
  DECLARE v_ticketId INT;
  DECLARE v_estadoId INT;

  DECLARE cur CURSOR FOR
    SELECT t.fiId, t.fiEstadoId
    FROM ticket t
    JOIN estado e ON e.fiId = t.fiEstadoId
    WHERE t.fbActivo = 1 AND e.fcCodigo = 'RESUELTO'
      AND t.fdResuelto IS NOT NULL
      AND DATE_ADD(t.fdResuelto, INTERVAL v_dias DAY) <= v_ahora;

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error en el cierre automático' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  SET v_ahora = IFNULL(p_fdAhora, NOW());
  SET v_dias = IFNULL((
    SELECT CAST(NULLIF(TRIM(fcValor),'') AS UNSIGNED)
    FROM parametro WHERE fcClave = 'DIAS_CIERRE_AUTOMATICO' AND fbActivo = 1 LIMIT 1
  ), 5);
  SET v_usuarioId = IFNULL((SELECT fiId FROM usuario WHERE fcUsuario = 'admin' AND fbActivo = 1 LIMIT 1), 1);
  SET v_validadoId = (SELECT fiId FROM estado WHERE fcCodigo = 'VALIDADO' AND fbActivo = 1 LIMIT 1);
  SET v_cerradoId = (SELECT fiId FROM estado WHERE fcCodigo = 'CERRADO' AND fbActivo = 1 LIMIT 1);

  IF v_validadoId IS NULL OR v_cerradoId IS NULL THEN
    SELECT 500 AS fiCodigo, 'No están configurados los estados VALIDADO/CERRADO' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  DROP TEMPORARY TABLE IF EXISTS tmp_cierre_auto;
  CREATE TEMPORARY TABLE tmp_cierre_auto (fiTicketId INT NOT NULL PRIMARY KEY) ENGINE=MEMORY;

  START TRANSACTION;
  OPEN cur;
  cierre_loop: LOOP
    FETCH cur INTO v_ticketId, v_estadoId;
    IF done = 1 THEN LEAVE cierre_loop; END IF;

    UPDATE ticket SET fiEstadoId = v_validadoId, fdValidado = IFNULL(fdValidado, v_ahora),
      fdModificado = v_ahora, fiModificadoPor = v_usuarioId WHERE fiId = v_ticketId;
    INSERT INTO ticketestado (fiTicketId, fiEstadoAnteriorId, fiEstadoId, fcComentario, fiUsuarioId, fdFecha)
    VALUES (v_ticketId, v_estadoId, v_validadoId, 'Validación automática por vencimiento de plazo', v_usuarioId, v_ahora);

    UPDATE ticket SET fiEstadoId = v_cerradoId, fdCerrado = v_ahora, fbCierreAutomatico = 1,
      fdModificado = v_ahora, fiModificadoPor = v_usuarioId WHERE fiId = v_ticketId;
    INSERT INTO ticketestado (fiTicketId, fiEstadoAnteriorId, fiEstadoId, fcComentario, fiUsuarioId, fdFecha)
    VALUES (v_ticketId, v_validadoId, v_cerradoId, 'Cierre automático por vencimiento de plazo', v_usuarioId, v_ahora);

    INSERT INTO tmp_cierre_auto (fiTicketId) VALUES (v_ticketId);
    SET v_cerrados = v_cerrados + 1;
  END LOOP;
  CLOSE cur;
  COMMIT;

  SELECT 200 AS fiCodigo,
         IF(v_cerrados = 0, 'No hay tickets para cierre automático',
            CONCAT('Se cerraron automáticamente ', v_cerrados, ' ticket(s)')) AS fcMensaje,
         1 AS fbSucces,
         CONCAT('{"cantidad":', v_cerrados, ',"tickets":', IFNULL((
           SELECT CONCAT('[', GROUP_CONCAT(fiTicketId ORDER BY fiTicketId SEPARATOR ','), ']') FROM tmp_cierre_auto
         ), '[]'), '}') AS fjData;

  DROP TEMPORARY TABLE IF EXISTS tmp_cierre_auto;
END$$

DELIMITER ;
