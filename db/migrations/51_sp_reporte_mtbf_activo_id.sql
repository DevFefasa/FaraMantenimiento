-- 51_sp_reporte_mtbf_activo_id.sql (recrea sp_reporte_mtbf con fiActivoId)
SET NAMES utf8mb4;
DROP PROCEDURE IF EXISTS sp_reporte_mtbf;
DELIMITER $$
CREATE PROCEDURE sp_reporte_mtbf(
  IN p_fdDesde DATETIME, IN p_fdHasta DATETIME, IN p_fiSucursalId INT, IN p_fiRegionId INT,
  IN p_fiTipoMantenimientoId INT, IN p_fiCategoriaId INT, IN p_fiPrioridadId INT, IN p_fiEstadoId INT,
  IN p_fiTecnicoId INT, IN p_fiProveedorId INT
)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN SELECT 500 AS fiCodigo, 'Ocurrió un error al consultar MTBF' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;

  SELECT
    'ACTIVO' AS fcAgrupacion,
    a.fiId AS fiActivoId,
    IFNULL(a.fcCodigo, 'SIN_ACTIVO') AS fcCodigo,
    IFNULL(a.fcNombre, 'Sin activo') AS fcNombre,
    s.fcNombre AS fcSucursalNombre,
    COUNT(*) AS fiFallos,
    ROUND(
      CASE WHEN COUNT(*) <= 1 THEN NULL
      ELSE TIMESTAMPDIFF(HOUR, MIN(t.fdFechaIngreso), MAX(t.fdFechaIngreso)) / NULLIF(COUNT(*) - 1, 0)
      END
    , 2) AS fnMtbfHoras
  FROM ticket t
  INNER JOIN sucursal s ON s.fiId = t.fiSucursalId
  INNER JOIN tipomantenimiento tm ON tm.fiId = t.fiTipoMantenimientoId
  LEFT JOIN activo a ON a.fiId = t.fiActivoId
  WHERE t.fbActivo = 1
    AND tm.fbEsPreventivo = 0
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
  GROUP BY a.fiId, a.fcCodigo, a.fcNombre, s.fcNombre
  HAVING COUNT(*) >= 1
  ORDER BY fiFallos DESC, fcNombre
  LIMIT 200;

  SELECT
    'SUCURSAL' AS fcAgrupacion,
    NULL AS fiActivoId,
    s.fcCodigo AS fcCodigo,
    s.fcNombre AS fcNombre,
    s.fcNombre AS fcSucursalNombre,
    COUNT(*) AS fiFallos,
    ROUND(
      CASE WHEN COUNT(*) <= 1 THEN NULL
      ELSE TIMESTAMPDIFF(HOUR, MIN(t.fdFechaIngreso), MAX(t.fdFechaIngreso)) / NULLIF(COUNT(*) - 1, 0)
      END
    , 2) AS fnMtbfHoras
  FROM ticket t
  INNER JOIN sucursal s ON s.fiId = t.fiSucursalId
  INNER JOIN tipomantenimiento tm ON tm.fiId = t.fiTipoMantenimientoId
  WHERE t.fbActivo = 1
    AND tm.fbEsPreventivo = 0
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
  ORDER BY fiFallos DESC, s.fcNombre;
END$$
DELIMITER ;
