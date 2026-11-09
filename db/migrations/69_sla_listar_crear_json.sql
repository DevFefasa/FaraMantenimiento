-- 69 parte SLA: B6 POR_VENCER_RESPUESTA/SOLUCION, B7 resta espera, B12 JSON
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



-- (69 B8) sp_ticket_crear: excluir RECHAZADO
SET NAMES utf8mb4;
DROP PROCEDURE IF EXISTS sp_ticket_crear;
DELIMITER $$
CREATE PROCEDURE sp_ticket_crear(
  IN p_fiUsuarioId INT,
  IN p_fiSucursalId INT,
  IN p_fiUbicacionId INT,
  IN p_fcUbicacionDetalle VARCHAR(250),
  IN p_fiActivoId INT,
  IN p_fiTipoMantenimientoId INT,
  IN p_fiCategoriaId INT,
  IN p_fiPrioridadId INT,
  IN p_fcDescripcion TEXT,
  IN p_fdFechaSugerida DATETIME
)
proc: BEGIN
  DECLARE v_prefijo VARCHAR(20) DEFAULT 'TK';
  DECLARE v_anio INT;
  DECLARE v_ult INT DEFAULT 0;
  DECLARE v_numero VARCHAR(30);
  DECLARE v_estadoId INT;
  DECLARE v_estadoCodigo VARCHAR(30);
  DECLARE v_requiereAprob TINYINT DEFAULT 1;
  DECLARE v_requiereFecha TINYINT DEFAULT 0;
  DECLARE v_horasResp INT;
  DECLARE v_horasSol INT;
  DECLARE v_diasReinc INT DEFAULT 90;
  DECLARE v_ticketId INT;
  DECLARE v_histId INT;
  DECLARE v_reincId INT;
  DECLARE v_nombre VARCHAR(150);
  DECLARE v_cargo VARCHAR(100);
  DECLARE v_correo VARCHAR(150);
  DECLARE v_tel VARCHAR(40);
  DECLARE v_limResp DATETIME;
  DECLARE v_limSol DATETIME;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al crear el ticket' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  IF p_fiUsuarioId IS NULL OR p_fiUsuarioId <= 0 THEN
    SELECT 400 AS fiCodigo, 'El solicitante es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM usuario WHERE fiId = p_fiUsuarioId AND fbActivo = 1) THEN
    SELECT 404 AS fiCodigo, 'El solicitante no existe o está inactivo' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF p_fiSucursalId IS NULL OR p_fiSucursalId <= 0 OR NOT EXISTS (SELECT 1 FROM sucursal WHERE fiId = p_fiSucursalId AND fbActivo = 1) THEN
    SELECT 400 AS fiCodigo, 'La sucursal no es válida' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF p_fiTipoMantenimientoId IS NULL OR NOT EXISTS (SELECT 1 FROM tipomantenimiento WHERE fiId = p_fiTipoMantenimientoId AND fbActivo = 1) THEN
    SELECT 400 AS fiCodigo, 'El tipo de mantenimiento no es válido' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF p_fiCategoriaId IS NULL OR NOT EXISTS (SELECT 1 FROM categoria WHERE fiId = p_fiCategoriaId AND fbActivo = 1) THEN
    SELECT 400 AS fiCodigo, 'La categoría no es válida' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF p_fiPrioridadId IS NULL OR NOT EXISTS (SELECT 1 FROM prioridad WHERE fiId = p_fiPrioridadId AND fbActivo = 1) THEN
    SELECT 400 AS fiCodigo, 'La prioridad no es válida' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF TRIM(IFNULL(p_fcDescripcion,'')) = '' THEN
    SELECT 400 AS fiCodigo, 'La descripción es obligatoria' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF p_fiUbicacionId IS NOT NULL AND p_fiUbicacionId > 0 THEN
    IF NOT EXISTS (SELECT 1 FROM ubicacion WHERE fiId = p_fiUbicacionId AND fiSucursalId = p_fiSucursalId AND fbActivo = 1) THEN
      SELECT 400 AS fiCodigo, 'La ubicación no es válida para la sucursal' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
  END IF;
  IF p_fiActivoId IS NOT NULL AND p_fiActivoId > 0 THEN
    IF NOT EXISTS (SELECT 1 FROM activo WHERE fiId = p_fiActivoId AND fiSucursalId = p_fiSucursalId AND fbActivo = 1) THEN
      SELECT 400 AS fiCodigo, 'El activo no es válido para la sucursal' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
  END IF;

  SELECT fbRequiereAprobacion, fbRequiereFechaSugerida INTO v_requiereAprob, v_requiereFecha
  FROM tipomantenimiento WHERE fiId = p_fiTipoMantenimientoId;

  IF v_requiereFecha = 1 AND p_fdFechaSugerida IS NULL THEN
    SELECT 400 AS fiCodigo, 'La fecha sugerida es obligatoria para este tipo' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;

  SELECT fiHorasRespuesta, fiHorasSolucion INTO v_horasResp, v_horasSol FROM prioridad WHERE fiId = p_fiPrioridadId;
  SELECT fcNombre, fcCargo, fcCorreo, fcTelefono INTO v_nombre, v_cargo, v_correo, v_tel FROM usuario WHERE fiId = p_fiUsuarioId;

  SELECT IFNULL(NULLIF(TRIM(fcValor),''),'TK') INTO v_prefijo FROM parametro WHERE fcClave = 'PREFIJO_TICKET' AND fbActivo = 1 LIMIT 1;
  SELECT CAST(IFNULL(NULLIF(TRIM(fcValor),''),'90') AS UNSIGNED) INTO v_diasReinc FROM parametro WHERE fcClave = 'DIAS_REINCIDENCIA' AND fbActivo = 1 LIMIT 1;

  IF v_requiereAprob = 0 THEN
    SET v_estadoCodigo = 'ASIGNADO';
  ELSE
    SET v_estadoCodigo = 'RECIBIDO';
  END IF;
  SELECT fiId INTO v_estadoId FROM estado WHERE fcCodigo = v_estadoCodigo AND fbActivo = 1 LIMIT 1;
  IF v_estadoId IS NULL THEN
    SELECT 500 AS fiCodigo, 'No está configurado el estado inicial del ticket' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;

  SET v_limResp = DATE_ADD(NOW(), INTERVAL v_horasResp HOUR);
  SET v_limSol = DATE_ADD(NOW(), INTERVAL v_horasSol HOUR);
  SET v_anio = YEAR(NOW());
  SET v_reincId = NULL;

  IF p_fiActivoId IS NOT NULL AND p_fiActivoId > 0 THEN
    SELECT t.fiId INTO v_reincId
    FROM ticket t
    INNER JOIN estado e ON e.fiId = t.fiEstadoId
    WHERE t.fiActivoId = p_fiActivoId
      AND t.fiCategoriaId = p_fiCategoriaId
      AND t.fbActivo = 1
      AND e.fcCodigo <> 'RECHAZADO'
      AND t.fdFechaIngreso >= DATE_SUB(NOW(), INTERVAL v_diasReinc DAY)
    ORDER BY t.fdFechaIngreso DESC
    LIMIT 1;
  END IF;

  START TRANSACTION;

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
    fdLimiteRespuesta, fdLimiteSolucion, fiCreadoPor, fbActivo
  ) VALUES (
    v_numero, NOW(), p_fiUsuarioId, v_nombre, v_cargo, v_correo, v_tel,
    p_fiSucursalId,
    IF(p_fiUbicacionId IS NULL OR p_fiUbicacionId <= 0, NULL, p_fiUbicacionId),
    NULLIF(TRIM(p_fcUbicacionDetalle),''),
    IF(p_fiActivoId IS NULL OR p_fiActivoId <= 0, NULL, p_fiActivoId),
    p_fiTipoMantenimientoId, p_fiCategoriaId, p_fiPrioridadId,
    TRIM(p_fcDescripcion), p_fdFechaSugerida, v_estadoId,
    IF(v_reincId IS NULL, 0, 1), v_reincId,
    v_limResp, v_limSol, p_fiUsuarioId, 1
  );
  SET v_ticketId = LAST_INSERT_ID();

  INSERT INTO ticketestado (fiTicketId, fiEstadoAnteriorId, fiEstadoId, fcComentario, fiUsuarioId, fdFecha)
  VALUES (v_ticketId, NULL, v_estadoId, 'Ticket creado', p_fiUsuarioId, NOW());
  SET v_histId = LAST_INSERT_ID();

  COMMIT;

  SELECT 201 AS fiCodigo, 'Ticket creado correctamente' AS fcMensaje, 1 AS fbSucces,
         JSON_OBJECT('ticket', v_ticketId, 'ticketestado', JSON_ARRAY(v_histId), 'numero', v_numero, 'reincidencia', IF(v_reincId IS NULL, 0, 1)) AS fjData;
END$$
DELIMITER ;


-- (69 B11) sp_ticket_listar
SET NAMES utf8mb4;
DROP PROCEDURE IF EXISTS sp_ticket_listar;
DELIMITER $$
CREATE PROCEDURE sp_ticket_listar(
  IN p_fiSolicitanteId INT,
  IN p_fiEstadoId INT,
  IN p_fcEstadoCodigo VARCHAR(30),
  IN p_fiSucursalId INT,
  IN p_fiPrioridadId INT,
  IN p_fiTipoMantenimientoId INT,
  IN p_fiCategoriaId INT,
  IN p_fcTipoResponsable VARCHAR(20),
  IN p_fiTecnicoId INT,
  IN p_fiProveedorId INT,
  IN p_fdDesde DATETIME,
  IN p_fdHasta DATETIME,
  IN p_fcTexto VARCHAR(200),
  IN p_fbSoloAbiertos TINYINT,
  IN p_fiPagina INT,
  IN p_fiTamano INT
)
proc: BEGIN
  DECLARE v_offset INT DEFAULT 0;
  DECLARE v_tam INT DEFAULT 20;
  DECLARE v_pag INT DEFAULT 1;
  DECLARE v_total INT DEFAULT 0;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN SELECT 500 AS fiCodigo, 'Ocurrió un error al listar tickets' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;

  SET v_pag = IF(p_fiPagina IS NULL OR p_fiPagina < 1, 1, IF(p_fiPagina > 100000, 100000, p_fiPagina));
  SET v_tam = IF(p_fiTamano IS NULL OR p_fiTamano < 1, 20, IF(p_fiTamano > 200, 200, p_fiTamano));
  SET v_offset = (v_pag - 1) * v_tam;

  SELECT COUNT(*) INTO v_total
  FROM ticket t
  INNER JOIN estado e ON e.fiId = t.fiEstadoId
  WHERE t.fbActivo = 1
    AND (p_fiSolicitanteId IS NULL OR p_fiSolicitanteId <= 0 OR t.fiSolicitanteId = p_fiSolicitanteId)
    AND (p_fiEstadoId IS NULL OR p_fiEstadoId <= 0 OR t.fiEstadoId = p_fiEstadoId)
    AND (p_fcEstadoCodigo IS NULL OR TRIM(p_fcEstadoCodigo) = '' OR e.fcCodigo = UPPER(TRIM(p_fcEstadoCodigo)))
    AND (p_fiSucursalId IS NULL OR p_fiSucursalId <= 0 OR t.fiSucursalId = p_fiSucursalId)
    AND (p_fiPrioridadId IS NULL OR p_fiPrioridadId <= 0 OR t.fiPrioridadId = p_fiPrioridadId)
    AND (p_fiTipoMantenimientoId IS NULL OR p_fiTipoMantenimientoId <= 0 OR t.fiTipoMantenimientoId = p_fiTipoMantenimientoId)
    AND (p_fiCategoriaId IS NULL OR p_fiCategoriaId <= 0 OR t.fiCategoriaId = p_fiCategoriaId)
    AND (p_fcTipoResponsable IS NULL OR TRIM(p_fcTipoResponsable) = '' OR t.fcTipoResponsable = UPPER(TRIM(p_fcTipoResponsable)))
    AND (p_fiTecnicoId IS NULL OR p_fiTecnicoId <= 0 OR t.fiTecnicoId = p_fiTecnicoId)
    AND (p_fiProveedorId IS NULL OR p_fiProveedorId <= 0 OR t.fiProveedorId = p_fiProveedorId)
    AND (p_fdDesde IS NULL OR t.fdFechaIngreso >= p_fdDesde)
    AND (p_fdHasta IS NULL OR t.fdFechaIngreso <= p_fdHasta)
    AND (IFNULL(p_fbSoloAbiertos,0) = 0 OR e.fbFinal = 0)
    AND (p_fcTexto IS NULL OR TRIM(p_fcTexto) = '' OR t.fcNumero LIKE CONCAT('%', TRIM(p_fcTexto), '%')
         OR t.fcDescripcion LIKE CONCAT('%', TRIM(p_fcTexto), '%')
         OR t.fcSolicitanteNombre LIKE CONCAT('%', TRIM(p_fcTexto), '%'));

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces,
         JSON_OBJECT('total', v_total, 'pagina', v_pag, 'tamano', v_tam) AS fjData;

  SELECT t.fiId, t.fcNumero, t.fdFechaIngreso, t.fiSolicitanteId, t.fcSolicitanteNombre,
         t.fiSucursalId, s.fcNombre AS fcSucursalNombre,
         t.fiTipoMantenimientoId, tm.fcNombre AS fcTipoNombre,
         t.fiCategoriaId, c.fcNombre AS fcCategoriaNombre,
         t.fiPrioridadId, p.fcNombre AS fcPrioridadNombre, p.fcCodigo AS fcPrioridadCodigo, p.fcColor AS fcPrioridadColor,
         t.fiEstadoId, e.fcCodigo AS fcEstadoCodigo, e.fcNombre AS fcEstadoNombre, e.fcColor AS fcEstadoColor, e.fbFinal,
         t.fcTipoResponsable, t.fiTecnicoId, tec.fcNombre AS fcTecnicoNombre,
         t.fiProveedorId, pr.fcNombre AS fcProveedorNombre,
         t.fbReincidencia, t.fdLimiteRespuesta, t.fdLimiteSolucion,
         t.fbSlaRespuestaCumplido, t.fbSlaSolucionCumplido,
         LEFT(t.fcDescripcion, 160) AS fcDescripcionCorta,
         CASE
           WHEN e.fbFinal = 1 OR e.fcCodigo IN ('CERRADO','RECHAZADO','VALIDADO') THEN 'GRIS'
           WHEN t.fdLimiteSolucion IS NOT NULL AND NOW() > t.fdLimiteSolucion THEN 'ROJO'
           WHEN t.fdLimiteSolucion IS NOT NULL AND TIMESTAMPDIFF(SECOND, t.fdFechaIngreso, NOW()) >=
                0.75 * TIMESTAMPDIFF(SECOND, t.fdFechaIngreso, t.fdLimiteSolucion) THEN 'AMARILLO'
           ELSE 'VERDE'
         END AS fcSemaforoSla
  FROM ticket t
  INNER JOIN sucursal s ON s.fiId = t.fiSucursalId
  INNER JOIN tipomantenimiento tm ON tm.fiId = t.fiTipoMantenimientoId
  INNER JOIN categoria c ON c.fiId = t.fiCategoriaId
  INNER JOIN prioridad p ON p.fiId = t.fiPrioridadId
  INNER JOIN estado e ON e.fiId = t.fiEstadoId
  LEFT JOIN tecnico tec ON tec.fiId = t.fiTecnicoId
  LEFT JOIN proveedor pr ON pr.fiId = t.fiProveedorId
  WHERE t.fbActivo = 1
    AND (p_fiSolicitanteId IS NULL OR p_fiSolicitanteId <= 0 OR t.fiSolicitanteId = p_fiSolicitanteId)
    AND (p_fiEstadoId IS NULL OR p_fiEstadoId <= 0 OR t.fiEstadoId = p_fiEstadoId)
    AND (p_fcEstadoCodigo IS NULL OR TRIM(p_fcEstadoCodigo) = '' OR e.fcCodigo = UPPER(TRIM(p_fcEstadoCodigo)))
    AND (p_fiSucursalId IS NULL OR p_fiSucursalId <= 0 OR t.fiSucursalId = p_fiSucursalId)
    AND (p_fiPrioridadId IS NULL OR p_fiPrioridadId <= 0 OR t.fiPrioridadId = p_fiPrioridadId)
    AND (p_fiTipoMantenimientoId IS NULL OR p_fiTipoMantenimientoId <= 0 OR t.fiTipoMantenimientoId = p_fiTipoMantenimientoId)
    AND (p_fiCategoriaId IS NULL OR p_fiCategoriaId <= 0 OR t.fiCategoriaId = p_fiCategoriaId)
    AND (p_fcTipoResponsable IS NULL OR TRIM(p_fcTipoResponsable) = '' OR t.fcTipoResponsable = UPPER(TRIM(p_fcTipoResponsable)))
    AND (p_fiTecnicoId IS NULL OR p_fiTecnicoId <= 0 OR t.fiTecnicoId = p_fiTecnicoId)
    AND (p_fiProveedorId IS NULL OR p_fiProveedorId <= 0 OR t.fiProveedorId = p_fiProveedorId)
    AND (p_fdDesde IS NULL OR t.fdFechaIngreso >= p_fdDesde)
    AND (p_fdHasta IS NULL OR t.fdFechaIngreso <= p_fdHasta)
    AND (IFNULL(p_fbSoloAbiertos,0) = 0 OR e.fbFinal = 0)
    AND (p_fcTexto IS NULL OR TRIM(p_fcTexto) = '' OR t.fcNumero LIKE CONCAT('%', TRIM(p_fcTexto), '%')
         OR t.fcDescripcion LIKE CONCAT('%', TRIM(p_fcTexto), '%')
         OR t.fcSolicitanteNombre LIKE CONCAT('%', TRIM(p_fcTexto), '%'))
  ORDER BY t.fdFechaIngreso DESC, t.fiId DESC
  LIMIT v_tam OFFSET v_offset;
END$$
DELIMITER ;


-- (69 B12) sp_ticket_cierre_automatico JSON
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
  DECLARE v_ids LONGTEXT DEFAULT '[]';  -- MariaDB 10.4 no tiene JSON_ARRAYAGG
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

  SELECT CONCAT('[', IFNULL(GROUP_CONCAT(fiTicketId ORDER BY fiTicketId), ''), ']') INTO v_ids FROM tmp_cierre_auto;

  SELECT 200 AS fiCodigo,
         IF(v_cerrados = 0, 'No hay tickets para cierre automático',
            CONCAT('Se cerraron automáticamente ', v_cerrados, ' ticket(s)')) AS fcMensaje,
         1 AS fbSucces,
         JSON_OBJECT('cantidad', v_cerrados, 'tickets', JSON_EXTRACT(v_ids, '$')) AS fjData;

  DROP TEMPORARY TABLE IF EXISTS tmp_cierre_auto;
END$$

DELIMITER ;
