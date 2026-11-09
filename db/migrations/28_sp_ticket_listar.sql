-- 28_sp_ticket_listar.sql
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

  SET v_pag = IF(p_fiPagina IS NULL OR p_fiPagina < 1, 1, p_fiPagina);
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
