-- 100_ticket_ejecucion_historial.sql (también: sp_ticket_listar_vista con proveedor SAP, al final)
-- sp_ticket_ejecucion_guardar (versión de 68) + constancia en la línea de tiempo:
-- inserta en ticketestado una fila SIN cambio de estado (anterior = actual) con
-- "Ejecución registrada" (primer guardado) o "Ejecución actualizada" (si ya había datos).
-- ticketestado solo lo leen el historial del detalle y los datos de correo; ningún reporte cuenta transiciones.
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_ticket_ejecucion_guardar;

DELIMITER $$
CREATE PROCEDURE sp_ticket_ejecucion_guardar(
  IN p_fiTicketId INT,
  IN p_fdFechaInicio DATETIME,
  IN p_fdFechaFin DATETIME,
  IN p_fnHorasTrabajadas DECIMAL(10,2),
  IN p_fnCostoManoObra DECIMAL(14,2),
  IN p_fnCostoProveedor DECIMAL(14,2),
  IN p_fcDiagnostico TEXT,
  IN p_fcCausaRaiz TEXT,
  IN p_fcTrabajoRealizado TEXT,
  IN p_fcAccionesPreventivas TEXT,
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_teniaDatos TINYINT DEFAULT 0;
  DECLARE v_estadoId INT;
  DECLARE v_texto VARCHAR(60);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; SELECT 500 AS fiCodigo, 'Ocurrió un error al guardar la ejecución' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;
  IF p_fiTicketId IS NULL OR NOT EXISTS (SELECT 1 FROM ticket WHERE fiId = p_fiTicketId AND fbActivo = 1) THEN
    SELECT 404 AS fiCodigo, 'El ticket no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM ticket t JOIN estado e ON e.fiId = t.fiEstadoId
    WHERE t.fiId = p_fiTicketId AND e.fcCodigo IN ('ASIGNADO','EN_PROCESO','EN_ESPERA','RESUELTO')
  ) THEN
    SELECT 409 AS fiCodigo, 'No se puede registrar ejecución en el estado actual' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF p_fnHorasTrabajadas IS NOT NULL AND p_fnHorasTrabajadas < 0 THEN
    SELECT 400 AS fiCodigo, 'Las horas trabajadas no pueden ser negativas' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF p_fnCostoManoObra IS NOT NULL AND p_fnCostoManoObra < 0 THEN
    SELECT 400 AS fiCodigo, 'El costo de mano de obra no puede ser negativo' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF p_fnCostoProveedor IS NOT NULL AND p_fnCostoProveedor < 0 THEN
    SELECT 400 AS fiCodigo, 'El costo de proveedor no puede ser negativo' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF p_fdFechaInicio IS NOT NULL AND p_fdFechaFin IS NOT NULL AND p_fdFechaFin < p_fdFechaInicio THEN
    SELECT 400 AS fiCodigo, 'La fecha fin no puede ser anterior a la fecha inicio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  START TRANSACTION;
  -- ¿Ya había un resumen de ejecución? (para el texto del historial)
  SELECT IF(fdFechaInicio IS NOT NULL OR fdFechaFin IS NOT NULL OR fnHorasTrabajadas IS NOT NULL
            OR IFNULL(fnCostoManoObra, 0) <> 0 OR IFNULL(fnCostoProveedor, 0) <> 0
            OR fcDiagnostico IS NOT NULL OR fcCausaRaiz IS NOT NULL OR fcTrabajoRealizado IS NOT NULL
            OR fcAccionesPreventivas IS NOT NULL, 1, 0), fiEstadoId
    INTO v_teniaDatos, v_estadoId
  FROM ticket WHERE fiId = p_fiTicketId FOR UPDATE;
  SET v_texto = IF(v_teniaDatos = 1, 'Ejecución actualizada', 'Ejecución registrada');
  UPDATE ticket SET
    fdFechaInicio = p_fdFechaInicio,
    fdFechaFin = p_fdFechaFin,
    fnHorasTrabajadas = p_fnHorasTrabajadas,
    fnCostoManoObra = p_fnCostoManoObra,
    fnCostoProveedor = p_fnCostoProveedor,
    fcDiagnostico = NULLIF(TRIM(p_fcDiagnostico),''),
    fcCausaRaiz = NULLIF(TRIM(p_fcCausaRaiz),''),
    fcTrabajoRealizado = NULLIF(TRIM(p_fcTrabajoRealizado),''),
    fcAccionesPreventivas = NULLIF(TRIM(p_fcAccionesPreventivas),''),
    fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId
  WHERE fiId = p_fiTicketId;
  -- Constancia en la línea de tiempo sin cambiar el estado (anterior = actual).
  INSERT INTO ticketestado (fiTicketId, fiEstadoAnteriorId, fiEstadoId, fiMotivoEsperaId, fcComentario, fiUsuarioId, fdFecha)
  VALUES (p_fiTicketId, v_estadoId, v_estadoId, NULL, v_texto, p_fiUsuarioId, NOW());
  COMMIT;
  SELECT 200 AS fiCodigo, IF(v_teniaDatos = 1, 'Ejecución actualizada correctamente', 'Ejecución registrada correctamente') AS fcMensaje, 1 AS fbSucces,
         JSON_OBJECT('ticket', p_fiTicketId, 'ticketestado', JSON_ARRAY(LAST_INSERT_ID())) AS fjData;
END$$

DELIMITER ;

-- sp_ticket_listar_vista (versión de 99) + proveedor SAP (91): fcProveedorNombre usa fcProveedorSapNombre si existe,
-- para la columna "Responsable" de la lista.
DROP PROCEDURE IF EXISTS sp_ticket_listar_vista;

DELIMITER $$
CREATE PROCEDURE sp_ticket_listar_vista(
  IN p_fcVista VARCHAR(20),
  IN p_fiUsuarioId INT,
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
  DECLARE v_vista VARCHAR(20);
  DECLARE v_offset INT DEFAULT 0;
  DECLARE v_tam INT DEFAULT 20;
  DECLARE v_pag INT DEFAULT 1;
  DECLARE v_total INT DEFAULT 0;
  DECLARE v_ok TINYINT DEFAULT 0;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN SELECT 500 AS fiCodigo, 'Ocurrió un error al listar tickets' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;

  SET v_vista = LOWER(TRIM(IFNULL(p_fcVista, '')));
  IF v_vista NOT IN ('creados', 'asignados', 'equipo', 'aprobar', 'atender', 'todos') THEN
    SELECT 400 AS fiCodigo, 'Vista de tickets no válida' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF p_fiUsuarioId IS NULL OR NOT EXISTS (SELECT 1 FROM usuario WHERE fiId = p_fiUsuarioId AND fbActivo = 1) THEN
    SELECT 403 AS fiCodigo, 'Usuario no válido' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  SET v_ok = CASE v_vista
    WHEN 'aprobar' THEN fn_usuario_tiene_permiso(p_fiUsuarioId, 'TICKET_APROBACION')
    WHEN 'atender' THEN fn_usuario_tiene_permiso(p_fiUsuarioId, 'TICKET_BANDEJA')
    WHEN 'todos' THEN fn_usuario_tiene_permiso(p_fiUsuarioId, 'TICKET_TODOS')
    ELSE 1 END;
  IF v_ok = 0 THEN
    SELECT 403 AS fiCodigo, 'No tiene permiso para esta vista de tickets' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;

  SET v_pag = IF(p_fiPagina IS NULL OR p_fiPagina < 1, 1, IF(p_fiPagina > 100000, 100000, p_fiPagina));
  SET v_tam = IF(p_fiTamano IS NULL OR p_fiTamano < 1, 20, IF(p_fiTamano > 200, 200, p_fiTamano));
  SET v_offset = (v_pag - 1) * v_tam;

  SELECT COUNT(*) INTO v_total
  FROM ticket t
  INNER JOIN estado e ON e.fiId = t.fiEstadoId
  LEFT JOIN tecnico tv ON tv.fiId = t.fiTecnicoId
  WHERE t.fbActivo = 1
    AND (   (v_vista = 'creados'   AND t.fiSolicitanteId = p_fiUsuarioId)
         OR (v_vista = 'asignados' AND tv.fiUsuarioId = p_fiUsuarioId)
         OR (v_vista = 'equipo'    AND fn_usuario_es_subordinado(t.fiSolicitanteId, p_fiUsuarioId) = 1)
         OR (v_vista = 'aprobar'   AND e.fcCodigo = 'EN_EVALUACION')
         OR v_vista IN ('atender', 'todos'))
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
         JSON_OBJECT('total', v_total, 'pagina', v_pag, 'tamano', v_tam, 'vista', v_vista) AS fjData;

  SELECT t.fiId, t.fcNumero, t.fdFechaIngreso, t.fiSolicitanteId, t.fcSolicitanteNombre,
         t.fiSucursalId, s.fcNombre AS fcSucursalNombre,
         t.fiTipoMantenimientoId, tm.fcNombre AS fcTipoNombre,
         t.fiCategoriaId, c.fcNombre AS fcCategoriaNombre,
         t.fiPrioridadId, p.fcNombre AS fcPrioridadNombre, p.fcCodigo AS fcPrioridadCodigo, p.fcColor AS fcPrioridadColor,
         t.fiEstadoId, e.fcCodigo AS fcEstadoCodigo, e.fcNombre AS fcEstadoNombre, e.fcColor AS fcEstadoColor, e.fbFinal,
         t.fcTipoResponsable, t.fiTecnicoId, tec.fcNombre AS fcTecnicoNombre,
         t.fiProveedorId, t.fcProveedorSapCodigo, t.fcProveedorSapNombre,
         COALESCE(NULLIF(TRIM(t.fcProveedorSapNombre), ''), pr.fcNombre) AS fcProveedorNombre,
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
    AND (   (v_vista = 'creados'   AND t.fiSolicitanteId = p_fiUsuarioId)
         OR (v_vista = 'asignados' AND tec.fiUsuarioId = p_fiUsuarioId)
         OR (v_vista = 'equipo'    AND fn_usuario_es_subordinado(t.fiSolicitanteId, p_fiUsuarioId) = 1)
         OR (v_vista = 'aprobar'   AND e.fcCodigo = 'EN_EVALUACION')
         OR v_vista IN ('atender', 'todos'))
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
