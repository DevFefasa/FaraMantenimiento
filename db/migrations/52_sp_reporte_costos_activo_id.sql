-- 52_sp_reporte_costos_activo_id.sql (recrea sp_reporte_costos con fiActivoId)
SET NAMES utf8mb4;
DROP PROCEDURE IF EXISTS sp_reporte_costos;
DELIMITER $$
CREATE PROCEDURE sp_reporte_costos(
  IN p_fdDesde DATETIME, IN p_fdHasta DATETIME, IN p_fiSucursalId INT, IN p_fiRegionId INT,
  IN p_fiTipoMantenimientoId INT, IN p_fiCategoriaId INT, IN p_fiPrioridadId INT, IN p_fiEstadoId INT,
  IN p_fiTecnicoId INT, IN p_fiProveedorId INT
)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN SELECT 500 AS fiCodigo, 'Ocurrió un error al consultar costos' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;

  SELECT 'SUCURSAL' AS fcAgrupacion, NULL AS fiActivoId, s.fcCodigo AS fcCodigo, s.fcNombre AS fcNombre,
    COUNT(*) AS fiTickets,
    ROUND(SUM(IFNULL(t.fnCostoManoObra,0)), 2) AS fnCostoManoObra,
    ROUND(SUM(IFNULL(t.fnCostoMateriales,0)), 2) AS fnCostoMateriales,
    ROUND(SUM(IFNULL(t.fnCostoProveedor,0)), 2) AS fnCostoProveedor,
    ROUND(SUM(IFNULL(t.fnCostoManoObra,0)+IFNULL(t.fnCostoMateriales,0)+IFNULL(t.fnCostoProveedor,0)), 2) AS fnCostoTotal
  FROM ticket t
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
  GROUP BY s.fiId, s.fcCodigo, s.fcNombre
  ORDER BY fnCostoTotal DESC;

  SELECT 'CATEGORIA' AS fcAgrupacion, NULL AS fiActivoId, c.fcCodigo AS fcCodigo, c.fcNombre AS fcNombre,
    COUNT(*) AS fiTickets,
    ROUND(SUM(IFNULL(t.fnCostoManoObra,0)), 2) AS fnCostoManoObra,
    ROUND(SUM(IFNULL(t.fnCostoMateriales,0)), 2) AS fnCostoMateriales,
    ROUND(SUM(IFNULL(t.fnCostoProveedor,0)), 2) AS fnCostoProveedor,
    ROUND(SUM(IFNULL(t.fnCostoManoObra,0)+IFNULL(t.fnCostoMateriales,0)+IFNULL(t.fnCostoProveedor,0)), 2) AS fnCostoTotal
  FROM ticket t
  INNER JOIN sucursal s ON s.fiId = t.fiSucursalId
  INNER JOIN categoria c ON c.fiId = t.fiCategoriaId
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
  GROUP BY c.fiId, c.fcCodigo, c.fcNombre
  ORDER BY fnCostoTotal DESC;

  SELECT 'ACTIVO' AS fcAgrupacion, a.fiId AS fiActivoId, IFNULL(a.fcCodigo,'SIN_ACTIVO') AS fcCodigo, IFNULL(a.fcNombre,'Sin activo') AS fcNombre,
    COUNT(*) AS fiTickets,
    ROUND(SUM(IFNULL(t.fnCostoManoObra,0)), 2) AS fnCostoManoObra,
    ROUND(SUM(IFNULL(t.fnCostoMateriales,0)), 2) AS fnCostoMateriales,
    ROUND(SUM(IFNULL(t.fnCostoProveedor,0)), 2) AS fnCostoProveedor,
    ROUND(SUM(IFNULL(t.fnCostoManoObra,0)+IFNULL(t.fnCostoMateriales,0)+IFNULL(t.fnCostoProveedor,0)), 2) AS fnCostoTotal
  FROM ticket t
  INNER JOIN sucursal s ON s.fiId = t.fiSucursalId
  LEFT JOIN activo a ON a.fiId = t.fiActivoId
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
  GROUP BY a.fiId, a.fcCodigo, a.fcNombre
  ORDER BY fnCostoTotal DESC
  LIMIT 100;
END$$
DELIMITER ;
