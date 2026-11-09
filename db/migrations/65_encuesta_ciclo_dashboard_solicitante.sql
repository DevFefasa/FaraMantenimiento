-- 65_encuesta_ciclo_dashboard_solicitante.sql
-- Callers: sp_ticket_encuesta_guardar / sp_ticket_obtener / sp_reporte_satisfaccion; seed rolpermiso
-- Corrige: A5 (encuesta por ciclo), M2 (quitar DASHBOARD a SOLICITANTE)
SET NAMES utf8mb4;

SET @col := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ticketencuesta' AND COLUMN_NAME = 'fiCiclo'
);
SET @sql := IF(@col = 0,
  'ALTER TABLE ticketencuesta ADD COLUMN fiCiclo INT NOT NULL DEFAULT 1 COMMENT ''Ciclo de resolución (1..n)'' AFTER fiTicketId',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

UPDATE ticketencuesta SET fiCiclo = 1 WHERE IFNULL(fiCiclo,0) < 1;

-- La FK usa el índice único antiguo; hay que soltarla antes de cambiar la llave.
SET @fk := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ticketencuesta'
    AND CONSTRAINT_NAME = 'fk_ticketencuesta_ticket' AND CONSTRAINT_TYPE = 'FOREIGN KEY'
);
SET @sql := IF(@fk > 0, 'ALTER TABLE ticketencuesta DROP FOREIGN KEY fk_ticketencuesta_ticket', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @uk := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ticketencuesta' AND INDEX_NAME = 'uk_ticketencuesta_ticket'
);
SET @sql := IF(@uk > 0, 'ALTER TABLE ticketencuesta DROP INDEX uk_ticketencuesta_ticket', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @uk2 := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ticketencuesta' AND INDEX_NAME = 'uk_ticketencuesta_ticket_ciclo'
);
SET @sql := IF(@uk2 = 0,
  'ALTER TABLE ticketencuesta ADD UNIQUE KEY uk_ticketencuesta_ticket_ciclo (fiTicketId, fiCiclo)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk2 := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ticketencuesta'
    AND CONSTRAINT_NAME = 'fk_ticketencuesta_ticket' AND CONSTRAINT_TYPE = 'FOREIGN KEY'
);
SET @sql := IF(@fk2 = 0,
  'ALTER TABLE ticketencuesta ADD CONSTRAINT fk_ticketencuesta_ticket FOREIGN KEY (fiTicketId) REFERENCES ticket (fiId)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

DELETE rp FROM rolpermiso rp
INNER JOIN rol r ON r.fiId = rp.fiRolId
INNER JOIN pantalla p ON p.fiId = rp.fiPantallaId
WHERE r.fcCodigo = 'SOLICITANTE' AND p.fcCodigo = 'DASHBOARD';

DROP PROCEDURE IF EXISTS sp_ticket_encuesta_guardar;
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
  DECLARE v_maxCiclo INT DEFAULT 0; DECLARE v_ultConforme TINYINT; DECLARE v_ciclo INT DEFAULT 1;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; SELECT 500 AS fiCodigo, 'Ocurrió un error al guardar la encuesta' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;

  IF p_fiTicketId IS NULL OR NOT EXISTS (SELECT 1 FROM ticket WHERE fiId = p_fiTicketId AND fbActivo = 1) THEN
    SELECT 404 AS fiCodigo, 'El ticket no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF p_fiCalificacion IS NULL OR p_fiCalificacion < 1 OR p_fiCalificacion > 5 THEN
    SELECT 400 AS fiCodigo, 'La calificación debe ser entre 1 y 5' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;

  START TRANSACTION;

  SELECT t.fiEstadoId, e.fcCodigo, t.fiSolicitanteId
  INTO v_estadoId, v_estadoCod, v_sol
  FROM ticket t JOIN estado e ON e.fiId = t.fiEstadoId
  WHERE t.fiId = p_fiTicketId FOR UPDATE;

  IF v_estadoCod <> 'RESUELTO' THEN
    ROLLBACK; SELECT 409 AS fiCodigo, 'Solo se puede encuestar un ticket en estado RESUELTO' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF v_sol IS NULL OR v_sol <> p_fiUsuarioId THEN
    ROLLBACK; SELECT 403 AS fiCodigo, 'Solo el solicitante puede responder la encuesta' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;

  SELECT IFNULL(MAX(fiCiclo), 0) INTO v_maxCiclo FROM ticketencuesta WHERE fiTicketId = p_fiTicketId;
  IF v_maxCiclo > 0 THEN
    SELECT fbConforme INTO v_ultConforme FROM ticketencuesta WHERE fiTicketId = p_fiTicketId AND fiCiclo = v_maxCiclo LIMIT 1;
    IF IFNULL(v_ultConforme, 1) = 1 THEN
      ROLLBACK; SELECT 409 AS fiCodigo, 'El ticket ya tiene encuesta conforme' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    SET v_ciclo = v_maxCiclo + 1;
  ELSE
    SET v_ciclo = 1;
  END IF;

  IF IFNULL(p_fbConforme, 0) = 1 THEN SET v_nuevoCod = 'VALIDADO'; ELSE SET v_nuevoCod = 'EN_PROCESO'; END IF;
  SELECT fiId INTO v_nuevoId FROM estado WHERE fcCodigo = v_nuevoCod AND fbActivo = 1 LIMIT 1;

  INSERT INTO ticketencuesta (fiTicketId, fiCiclo, fiCalificacion, fbConforme, fcComentario, fdFecha, fiUsuarioId)
  VALUES (p_fiTicketId, v_ciclo, p_fiCalificacion, IF(IFNULL(p_fbConforme,0)=1,1,0), NULLIF(TRIM(p_fcComentario),''), NOW(), p_fiUsuarioId);
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
          IF(v_nuevoCod='VALIDADO', CONCAT('Validado por solicitante (', p_fiCalificacion, ' estrellas, ciclo ', v_ciclo, ')'),
             CONCAT('No conforme (ciclo ', v_ciclo, '): ', IFNULL(NULLIF(TRIM(p_fcComentario),''), 'Sin comentario'))),
          p_fiUsuarioId, NOW());
  SET v_histId = LAST_INSERT_ID();
  COMMIT;
  SELECT 200 AS fiCodigo,
         IF(v_nuevoCod='VALIDADO','Encuesta registrada y ticket validado','Encuesta registrada; el ticket vuelve a proceso') AS fcMensaje,
         1 AS fbSucces,
         JSON_OBJECT('ticketencuesta', v_encId, 'ticket', p_fiTicketId, 'ciclo', v_ciclo, 'ticketestado', JSON_ARRAY(v_histId)) AS fjData;
END$$
DELIMITER ;

-- (redefinido en 65) sp_ticket_obtener: ultima encuesta por ciclo
SET NAMES utf8mb4;
DROP PROCEDURE IF EXISTS sp_ticket_obtener;
DELIMITER $$
CREATE PROCEDURE sp_ticket_obtener(IN p_fiTicketId INT)
proc: BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN SELECT 500 AS fiCodigo, 'Ocurrió un error al consultar el ticket' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;
  IF p_fiTicketId IS NULL OR p_fiTicketId <= 0 OR NOT EXISTS (SELECT 1 FROM ticket WHERE fiId = p_fiTicketId AND fbActivo = 1) THEN
    SELECT 404 AS fiCodigo, 'El ticket no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('ticket', p_fiTicketId) AS fjData;

  SELECT t.fiId, t.fcNumero, t.fdFechaIngreso, t.fiSolicitanteId, t.fcSolicitanteNombre, t.fcCargo, t.fcCorreo, t.fcTelefono,
         t.fiSucursalId, s.fcNombre AS fcSucursalNombre, s.fcCodigo AS fcSucursalCodigo,
         t.fiUbicacionId, u.fcNombre AS fcUbicacionNombre, t.fcUbicacionDetalle,
         t.fiActivoId, a.fcNombre AS fcActivoNombre, a.fcCodigo AS fcActivoCodigo,
         t.fiTipoMantenimientoId, tm.fcNombre AS fcTipoNombre, tm.fcCodigo AS fcTipoCodigo,
         tm.fbRequiereAprobacion, tm.fbEsPreventivo, tm.fbEsPostFalla, tm.fbRequiereFechaSugerida,
         t.fiCategoriaId, c.fcNombre AS fcCategoriaNombre, c.fcCodigo AS fcCategoriaCodigo,
         t.fiPrioridadId, p.fcNombre AS fcPrioridadNombre, p.fcCodigo AS fcPrioridadCodigo, p.fcColor AS fcPrioridadColor,
         p.fiHorasRespuesta, p.fiHorasSolucion,
         t.fcDescripcion, t.fdFechaSugerida,
         t.fiEstadoId, e.fcCodigo AS fcEstadoCodigo, e.fcNombre AS fcEstadoNombre, e.fcColor AS fcEstadoColor, e.fbFinal,
         t.fiMotivoEsperaId, me.fcNombre AS fcMotivoEsperaNombre,
         t.fcTipoResponsable, t.fiTecnicoId, tec.fcNombre AS fcTecnicoNombre,
         t.fiProveedorId, pr.fcNombre AS fcProveedorNombre,
         t.fdFechaProgramada, t.fdFechaInicio, t.fdFechaFin, t.fnHorasTrabajadas,
         t.fnCostoManoObra, t.fnCostoMateriales, t.fnCostoProveedor,
         t.fcDiagnostico, t.fcCausaRaiz, t.fcTrabajoRealizado, t.fcAccionesPreventivas,
         t.fbReincidencia, t.fiTicketReincidenteId, tr.fcNumero AS fcTicketReincidenteNumero,
         t.fdLimiteRespuesta, t.fdLimiteSolucion, t.fdPrimeraRespuesta, t.fdResuelto, t.fdValidado, t.fdCerrado,
         t.fdInicioEspera, t.fiMinutosEnEspera, t.fbSlaRespuestaCumplido, t.fbSlaSolucionCumplido, t.fbCierreAutomatico,
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
  LEFT JOIN ubicacion u ON u.fiId = t.fiUbicacionId
  LEFT JOIN activo a ON a.fiId = t.fiActivoId
  LEFT JOIN motivoespera me ON me.fiId = t.fiMotivoEsperaId
  LEFT JOIN tecnico tec ON tec.fiId = t.fiTecnicoId
  LEFT JOIN proveedor pr ON pr.fiId = t.fiProveedorId
  LEFT JOIN ticket tr ON tr.fiId = t.fiTicketReincidenteId
  WHERE t.fiId = p_fiTicketId;

  SELECT te.fiId, te.fiTicketId, te.fiEstadoAnteriorId, ea.fcCodigo AS fcEstadoAnteriorCodigo, ea.fcNombre AS fcEstadoAnteriorNombre,
         te.fiEstadoId, e.fcCodigo AS fcEstadoCodigo, e.fcNombre AS fcEstadoNombre, e.fcColor AS fcEstadoColor,
         te.fiMotivoEsperaId, me.fcNombre AS fcMotivoEsperaNombre, te.fcComentario, te.fiUsuarioId,
         us.fcNombre AS fcUsuarioNombre, te.fdFecha
  FROM ticketestado te
  INNER JOIN estado e ON e.fiId = te.fiEstadoId
  LEFT JOIN estado ea ON ea.fiId = te.fiEstadoAnteriorId
  LEFT JOIN motivoespera me ON me.fiId = te.fiMotivoEsperaId
  LEFT JOIN usuario us ON us.fiId = te.fiUsuarioId
  WHERE te.fiTicketId = p_fiTicketId
  ORDER BY te.fdFecha ASC, te.fiId ASC;

  SELECT m.fiId, m.fiTicketId, m.fcDescripcion, m.fnCantidad, m.fcUnidad, m.fnCostoUnitario, m.fnTotal, m.fdCreado, m.fiCreadoPor
  FROM ticketmaterial m WHERE m.fiTicketId = p_fiTicketId AND m.fbActivo = 1 ORDER BY m.fiId;

  SELECT en.fiId, en.fiTicketId, en.fiCiclo, en.fiCalificacion, en.fbConforme, en.fcComentario, en.fdFecha, en.fiUsuarioId
  FROM ticketencuesta en WHERE en.fiTicketId = p_fiTicketId
  ORDER BY en.fiCiclo DESC, en.fiId DESC
  LIMIT 1;

  SELECT co.fiId, co.fiTicketId, co.fcComentario, co.fbInterno, co.fiUsuarioId, us.fcNombre AS fcUsuarioNombre, co.fdFecha
  FROM ticketcomentario co
  LEFT JOIN usuario us ON us.fiId = co.fiUsuarioId
  WHERE co.fiTicketId = p_fiTicketId AND co.fbActivo = 1
  ORDER BY co.fdFecha ASC, co.fiId ASC;
END$$
DELIMITER ;


DROP PROCEDURE IF EXISTS sp_reporte_satisfaccion;
DELIMITER $$
CREATE PROCEDURE sp_reporte_satisfaccion(
  IN p_fdDesde DATETIME, IN p_fdHasta DATETIME, IN p_fiSucursalId INT, IN p_fiRegionId INT,
  IN p_fiTipoMantenimientoId INT, IN p_fiCategoriaId INT, IN p_fiPrioridadId INT, IN p_fiEstadoId INT,
  IN p_fiTecnicoId INT, IN p_fiProveedorId INT
)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN SELECT 500 AS fiCodigo, 'Ocurrió un error al consultar satisfacción' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;

  SELECT
    COUNT(*) AS fiEncuestas,
    ROUND(AVG(en.fiCalificacion), 2) AS fnCalificacionPromedio,
    SUM(CASE WHEN en.fbConforme = 1 THEN 1 ELSE 0 END) AS fiConformes,
    ROUND(100.0 * SUM(CASE WHEN en.fbConforme = 1 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS fnPctConformes
  FROM ticketencuesta en
  INNER JOIN (
    SELECT fiTicketId, MAX(fiCiclo) AS fiCiclo FROM ticketencuesta GROUP BY fiTicketId
  ) ult ON ult.fiTicketId = en.fiTicketId AND ult.fiCiclo = en.fiCiclo
  INNER JOIN ticket t ON t.fiId = en.fiTicketId
  INNER JOIN sucursal s ON s.fiId = t.fiSucursalId
  WHERE t.fbActivo = 1
    AND (p_fdDesde IS NULL OR t.fdFechaIngreso >= p_fdDesde)
    AND (p_fdHasta IS NULL OR t.fdFechaIngreso < DATE_ADD(DATE(p_fdHasta), INTERVAL 1 DAY))
    AND (p_fiSucursalId IS NULL OR t.fiSucursalId = p_fiSucursalId)
    AND (p_fiRegionId IS NULL OR s.fiRegionId = p_fiRegionId)
    AND (p_fiTipoMantenimientoId IS NULL OR t.fiTipoMantenimientoId = p_fiTipoMantenimientoId)
    AND (p_fiCategoriaId IS NULL OR t.fiCategoriaId = p_fiCategoriaId)
    AND (p_fiPrioridadId IS NULL OR t.fiPrioridadId = p_fiPrioridadId)
    AND (p_fiEstadoId IS NULL OR t.fiEstadoId = p_fiEstadoId)
    AND (p_fiTecnicoId IS NULL OR t.fiTecnicoId = p_fiTecnicoId)
    AND (p_fiProveedorId IS NULL OR t.fiProveedorId = p_fiProveedorId);

  SELECT
    en.fiCalificacion,
    COUNT(*) AS fiCantidad,
    ROUND(100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0), 2) AS fnPorcentaje
  FROM ticketencuesta en
  INNER JOIN (
    SELECT fiTicketId, MAX(fiCiclo) AS fiCiclo FROM ticketencuesta GROUP BY fiTicketId
  ) ult ON ult.fiTicketId = en.fiTicketId AND ult.fiCiclo = en.fiCiclo
  INNER JOIN ticket t ON t.fiId = en.fiTicketId
  INNER JOIN sucursal s ON s.fiId = t.fiSucursalId
  WHERE t.fbActivo = 1
    AND (p_fdDesde IS NULL OR t.fdFechaIngreso >= p_fdDesde)
    AND (p_fdHasta IS NULL OR t.fdFechaIngreso < DATE_ADD(DATE(p_fdHasta), INTERVAL 1 DAY))
    AND (p_fiSucursalId IS NULL OR t.fiSucursalId = p_fiSucursalId)
    AND (p_fiRegionId IS NULL OR s.fiRegionId = p_fiRegionId)
    AND (p_fiTipoMantenimientoId IS NULL OR t.fiTipoMantenimientoId = p_fiTipoMantenimientoId)
    AND (p_fiCategoriaId IS NULL OR t.fiCategoriaId = p_fiCategoriaId)
    AND (p_fiPrioridadId IS NULL OR t.fiPrioridadId = p_fiPrioridadId)
    AND (p_fiEstadoId IS NULL OR t.fiEstadoId = p_fiEstadoId)
    AND (p_fiTecnicoId IS NULL OR t.fiTecnicoId = p_fiTecnicoId)
    AND (p_fiProveedorId IS NULL OR t.fiProveedorId = p_fiProveedorId)
  GROUP BY en.fiCalificacion
  ORDER BY en.fiCalificacion;
END$$
DELIMITER ;
