-- 47_sp_reporte_productividad.sql
SET NAMES utf8mb4;
DROP PROCEDURE IF EXISTS sp_reporte_productividad;
DELIMITER $$
CREATE PROCEDURE sp_reporte_productividad(
  IN p_fdDesde DATETIME, IN p_fdHasta DATETIME, IN p_fiSucursalId INT, IN p_fiRegionId INT,
  IN p_fiTipoMantenimientoId INT, IN p_fiCategoriaId INT, IN p_fiPrioridadId INT, IN p_fiEstadoId INT,
  IN p_fiTecnicoId INT, IN p_fiProveedorId INT
)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN SELECT 500 AS fiCodigo, 'Ocurrió un error al consultar productividad' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;

  SELECT
    'TECNICO' AS fcTipoResponsable,
    te.fcCodigo AS fcCodigo,
    te.fcNombre AS fcNombre,
    COUNT(*) AS fiTickets,
    ROUND(SUM(IFNULL(t.fnHorasTrabajadas,0)), 2) AS fnHorasTrabajadas,
    ROUND(AVG(CASE WHEN t.fdResuelto IS NOT NULL
      THEN GREATEST(0, TIMESTAMPDIFF(MINUTE, t.fdFechaIngreso, t.fdResuelto) - IFNULL(t.fiMinutosEnEspera,0)) / 60.0 END), 2) AS fnHorasSolucionPromedio
  FROM ticket t
  INNER JOIN sucursal s ON s.fiId = t.fiSucursalId
  INNER JOIN tecnico te ON te.fiId = t.fiTecnicoId
  WHERE t.fbActivo = 1
    AND t.fiTecnicoId IS NOT NULL
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
  GROUP BY te.fiId, te.fcCodigo, te.fcNombre
  ORDER BY fiTickets DESC;

  SELECT
    'PROVEEDOR' AS fcTipoResponsable,
    pr.fcCodigo AS fcCodigo,
    pr.fcNombre AS fcNombre,
    COUNT(*) AS fiTickets,
    ROUND(SUM(IFNULL(t.fnHorasTrabajadas,0)), 2) AS fnHorasTrabajadas,
    ROUND(AVG(CASE WHEN t.fdResuelto IS NOT NULL
      THEN GREATEST(0, TIMESTAMPDIFF(MINUTE, t.fdFechaIngreso, t.fdResuelto) - IFNULL(t.fiMinutosEnEspera,0)) / 60.0 END), 2) AS fnHorasSolucionPromedio
  FROM ticket t
  INNER JOIN sucursal s ON s.fiId = t.fiSucursalId
  INNER JOIN proveedor pr ON pr.fiId = t.fiProveedorId
  WHERE t.fbActivo = 1
    AND t.fiProveedorId IS NOT NULL
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
  GROUP BY pr.fiId, pr.fcCodigo, pr.fcNombre
  ORDER BY fiTickets DESC;
END$$
DELIMITER ;
