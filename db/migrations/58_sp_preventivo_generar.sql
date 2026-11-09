-- 58_sp_preventivo_generar.sql
-- Callers: PreventivoRepositorio.GenerarTicketsAsync; PreventivoTarea; PreventivosController.GenerarAhora
-- API: sp_preventivo_generar_tickets(p_fdHoy, p_fiUsuarioId)
-- Schema: crea tickets PREVENTIVO (lógica alineada a sp_ticket_crear), registra ejecucion, avanza fdProximaFecha; idempotente
-- User instruction: "sp_preventivo_generar_tickets(...): ... crea ticket tipo Preventivo (reutiliza la logica de sp_ticket_crear; ... Idempotente"
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_preventivo_generar_tickets;

DELIMITER $$

CREATE PROCEDURE sp_preventivo_generar_tickets(
  IN p_fdHoy DATE,
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_hoy DATE;
  DECLARE v_usuarioId INT;
  DECLARE v_tipoPrevId INT;
  DECLARE v_prefijo VARCHAR(20) DEFAULT 'TK';
  DECLARE v_diasReinc INT DEFAULT 90;
  DECLARE v_creados INT DEFAULT 0;
  DECLARE done INT DEFAULT 0;

  DECLARE v_planId INT; DECLARE v_nombre VARCHAR(150); DECLARE v_desc TEXT;
  DECLARE v_sucId INT; DECLARE v_ubiId INT; DECLARE v_actId INT;
  DECLARE v_catId INT; DECLARE v_prioId INT; DECLARE v_prox DATE;
  DECLARE v_antic INT; DECLARE v_freq INT; DECLARE v_tecId INT; DECLARE v_provId INT;

  DECLARE v_ticketId INT; DECLARE v_anio INT; DECLARE v_ult INT;
  DECLARE v_numero VARCHAR(30); DECLARE v_estadoId INT; DECLARE v_estadoFinal INT;
  DECLARE v_requiereAprob TINYINT; DECLARE v_horasResp INT; DECLARE v_horasSol INT;
  DECLARE v_limResp DATETIME; DECLARE v_limSol DATETIME; DECLARE v_reincId INT;
  DECLARE v_solNombre VARCHAR(150); DECLARE v_cargo VARCHAR(100);
  DECLARE v_correo VARCHAR(150); DECLARE v_tel VARCHAR(40);
  DECLARE v_asignadoId INT; DECLARE v_tieneResp TINYINT;
  DECLARE v_idsJson TEXT DEFAULT '[]';

  DECLARE cur CURSOR FOR
    SELECT p.fiId, p.fcNombre, p.fcDescripcion, p.fiSucursalId, p.fiUbicacionId, p.fiActivoId,
           p.fiCategoriaId, p.fiPrioridadId, p.fdProximaFecha, p.fiDiasAnticipacion, p.fiFrecuenciaDias,
           p.fiTecnicoId, p.fiProveedorId
    FROM planpreventivo p
    WHERE p.fbActivo = 1
      AND p.fiFrecuenciaDias > 0
      AND DATE_SUB(p.fdProximaFecha, INTERVAL p.fiDiasAnticipacion DAY) <= v_hoy
      AND NOT EXISTS (
        SELECT 1 FROM planpreventivoejecucion e
        WHERE e.fiPlanId = p.fiId AND e.fdFechaProgramada = p.fdProximaFecha
      )
    ORDER BY p.fdProximaFecha, p.fiId;

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al generar tickets preventivos' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  SET v_hoy = IFNULL(p_fdHoy, CURDATE());
  SET v_usuarioId = IFNULL(NULLIF(p_fiUsuarioId, 0), 1);

  IF NOT EXISTS (SELECT 1 FROM usuario WHERE fiId = v_usuarioId AND fbActivo = 1) THEN
    SELECT 400 AS fiCodigo, 'El usuario ejecutor no es válido' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  SET v_tipoPrevId = (SELECT fiId FROM tipomantenimiento WHERE fcCodigo = 'PREVENTIVO' AND fbActivo = 1 LIMIT 1);
  IF v_tipoPrevId IS NULL THEN
    SELECT 500 AS fiCodigo, 'No está configurado el tipo Preventivo' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  SET v_prefijo = IFNULL((SELECT NULLIF(TRIM(fcValor),'') FROM parametro WHERE fcClave = 'PREFIJO_TICKET' AND fbActivo = 1 LIMIT 1), 'TK');
  SET v_diasReinc = IFNULL((SELECT CAST(NULLIF(TRIM(fcValor),'') AS UNSIGNED) FROM parametro WHERE fcClave = 'DIAS_REINCIDENCIA' AND fbActivo = 1 LIMIT 1), 90);

  SET v_requiereAprob = (SELECT fbRequiereAprobacion FROM tipomantenimiento WHERE fiId = v_tipoPrevId);
  SET v_estadoId = (SELECT fiId FROM estado WHERE fcCodigo = IF(IFNULL(v_requiereAprob, 1) = 0, 'ASIGNADO', 'RECIBIDO') AND fbActivo = 1 LIMIT 1);
  SET v_asignadoId = (SELECT fiId FROM estado WHERE fcCodigo = 'ASIGNADO' AND fbActivo = 1 LIMIT 1);
  IF v_estadoId IS NULL THEN
    SELECT 500 AS fiCodigo, 'No está configurado el estado inicial del ticket' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  SELECT fcNombre, fcCargo, fcCorreo, fcTelefono
  INTO v_solNombre, v_cargo, v_correo, v_tel
  FROM usuario WHERE fiId = v_usuarioId;

  DROP TEMPORARY TABLE IF EXISTS tmp_prev_tickets;
  CREATE TEMPORARY TABLE tmp_prev_tickets (fiTicketId INT NOT NULL PRIMARY KEY) ENGINE=MEMORY;

  START TRANSACTION;

  OPEN cur;
  gen_loop: LOOP
    FETCH cur INTO v_planId, v_nombre, v_desc, v_sucId, v_ubiId, v_actId, v_catId, v_prioId,
                   v_prox, v_antic, v_freq, v_tecId, v_provId;
    IF done = 1 THEN LEAVE gen_loop; END IF;

    SELECT fiId INTO v_planId FROM planpreventivo WHERE fiId = v_planId FOR UPDATE;

    IF EXISTS (
      SELECT 1 FROM planpreventivoejecucion
      WHERE fiPlanId = v_planId AND fdFechaProgramada = v_prox
    ) THEN
      ITERATE gen_loop;
    END IF;

    SET v_tieneResp = IF((v_tecId IS NOT NULL AND v_tecId > 0) OR (v_provId IS NOT NULL AND v_provId > 0), 1, 0);
    SET v_estadoFinal = IF(v_tieneResp = 1 AND v_asignadoId IS NOT NULL, v_asignadoId, v_estadoId);

    SET v_horasResp = (SELECT fiHorasRespuesta FROM prioridad WHERE fiId = v_prioId);
    SET v_horasSol = (SELECT fiHorasSolucion FROM prioridad WHERE fiId = v_prioId);
    SET v_limResp = DATE_ADD(NOW(), INTERVAL IFNULL(v_horasResp, 24) HOUR);
    SET v_limSol = DATE_ADD(NOW(), INTERVAL IFNULL(v_horasSol, 72) HOUR);
    SET v_anio = YEAR(NOW());
    SET v_reincId = NULL;
    IF v_actId IS NOT NULL AND v_actId > 0 THEN
      SET v_reincId = (
        SELECT t.fiId FROM ticket t
        WHERE t.fiActivoId = v_actId AND t.fiCategoriaId = v_catId AND t.fbActivo = 1
          AND t.fdFechaIngreso >= DATE_SUB(NOW(), INTERVAL v_diasReinc DAY)
        ORDER BY t.fdFechaIngreso DESC LIMIT 1
      );
    END IF;

    INSERT INTO ticketsecuencia (fiAnio, fiUltimo)
    VALUES (v_anio, 0)
    ON DUPLICATE KEY UPDATE fiAnio = fiAnio;

    SELECT fiUltimo INTO v_ult FROM ticketsecuencia WHERE fiAnio = v_anio FOR UPDATE;
    SET v_ult = IFNULL(v_ult, 0) + 1;
    UPDATE ticketsecuencia SET fiUltimo = v_ult WHERE fiAnio = v_anio;
    SET v_numero = CONCAT(v_prefijo, '-', v_anio, '-', LPAD(v_ult, 6, '0'));

    INSERT INTO ticket (
      fcNumero, fdFechaIngreso, fiSolicitanteId, fcSolicitanteNombre, fcCargo, fcCorreo, fcTelefono,
      fiSucursalId, fiUbicacionId, fcUbicacionDetalle, fiActivoId, fiTipoMantenimientoId, fiCategoriaId, fiPrioridadId,
      fcDescripcion, fdFechaSugerida, fiEstadoId, fbReincidencia, fiTicketReincidenteId,
      fdLimiteRespuesta, fdLimiteSolucion,
      fcTipoResponsable, fiTecnicoId, fiProveedorId, fdFechaProgramada,
      fiCreadoPor, fbActivo
    ) VALUES (
      v_numero, NOW(), v_usuarioId, v_solNombre, v_cargo, v_correo, v_tel,
      v_sucId,
      IF(v_ubiId IS NULL OR v_ubiId <= 0, NULL, v_ubiId),
      NULL,
      IF(v_actId IS NULL OR v_actId <= 0, NULL, v_actId),
      v_tipoPrevId, v_catId, v_prioId,
      CONCAT('Preventivo: ', v_nombre, IF(IFNULL(TRIM(v_desc),'') = '', '', CONCAT(' — ', v_desc))),
      TIMESTAMP(v_prox),
      v_estadoFinal,
      IF(v_reincId IS NULL, 0, 1), v_reincId,
      v_limResp, v_limSol,
      IF(v_tecId IS NOT NULL AND v_tecId > 0, 'INTERNO', IF(v_provId IS NOT NULL AND v_provId > 0, 'PROVEEDOR', NULL)),
      IF(v_tecId IS NOT NULL AND v_tecId > 0, v_tecId, NULL),
      IF(v_provId IS NOT NULL AND v_provId > 0, v_provId, NULL),
      TIMESTAMP(v_prox),
      v_usuarioId, 1
    );
    SET v_ticketId = LAST_INSERT_ID();

    INSERT INTO ticketestado (fiTicketId, fiEstadoAnteriorId, fiEstadoId, fcComentario, fiUsuarioId, fdFecha)
    VALUES (v_ticketId, NULL, v_estadoFinal, CONCAT('Ticket preventivo generado desde plan #', v_planId), v_usuarioId, NOW());

    INSERT INTO planpreventivoejecucion (fiPlanId, fdFechaProgramada, fiTicketId, fdGenerado)
    VALUES (v_planId, v_prox, v_ticketId, NOW());

    UPDATE planpreventivo
    SET fdProximaFecha = DATE_ADD(v_prox, INTERVAL v_freq DAY),
        fdModificado = NOW(),
        fiModificadoPor = v_usuarioId
    WHERE fiId = v_planId;

    INSERT INTO tmp_prev_tickets (fiTicketId) VALUES (v_ticketId);
    SET v_creados = v_creados + 1;
  END LOOP;
  CLOSE cur;

  SET v_idsJson = IFNULL((
    SELECT CONCAT('[', GROUP_CONCAT(fiTicketId ORDER BY fiTicketId SEPARATOR ','), ']')
    FROM tmp_prev_tickets
  ), '[]');

  COMMIT;

  SELECT 200 AS fiCodigo,
         IF(v_creados = 0,
            'No hay planes pendientes de generar',
            CONCAT('Se generaron ', v_creados, ' ticket(s) preventivo(s)')) AS fcMensaje,
         1 AS fbSucces,
         CONCAT('{"cantidad":', v_creados, ',"tickets":', IFNULL(v_idsJson, '[]'), '}') AS fjData;

  DROP TEMPORARY TABLE IF EXISTS tmp_prev_tickets;
END$$

DELIMITER ;
