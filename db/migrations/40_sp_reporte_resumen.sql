-- 40_sp_reporte_resumen.sql
-- Callers: ReporteRepositorio.ResumenAsync / Dashboard
-- Filtros: fecha, sucursal, región, tipo, categoría, prioridad, estado, técnico, proveedor
-- Aplicar: docker exec -i MariaLocal sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" faramantenimiento' < db/migrations/40_sp_reporte_resumen.sql

SET NAMES utf8mb4;
DROP PROCEDURE IF EXISTS sp_reporte_resumen;
DELIMITER $$
CREATE PROCEDURE sp_reporte_resumen(
  IN p_fdDesde DATETIME,
  IN p_fdHasta DATETIME,
  IN p_fiSucursalId INT,
  IN p_fiRegionId INT,
  IN p_fiTipoMantenimientoId INT,
  IN p_fiCategoriaId INT,
  IN p_fiPrioridadId INT,
  IN p_fiEstadoId INT,
  IN p_fiTecnicoId INT,
  IN p_fiProveedorId INT
)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    SELECT 500 AS fiCodigo, 'Ocurrió un error al consultar el resumen' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;

  SELECT
    COUNT(*) AS fiRecibidos,
    SUM(CASE WHEN e.fbFinal = 0 THEN 1 ELSE 0 END) AS fiAbiertos,
    SUM(CASE WHEN e.fcCodigo IN ('CERRADO','VALIDADO') THEN 1 ELSE 0 END) AS fiCerrados,
    SUM(CASE WHEN e.fbFinal = 0 THEN 1 ELSE 0 END) AS fiBacklog,
    SUM(CASE WHEN t.fbReincidencia = 1 THEN 1 ELSE 0 END) AS fiReincidentes,
    ROUND(AVG(
      CASE WHEN t.fdPrimeraRespuesta IS NOT NULL
        THEN TIMESTAMPDIFF(MINUTE, t.fdFechaIngreso, t.fdPrimeraRespuesta) / 60.0
      END
    ), 2) AS fnHorasRespuestaPromedio,
    ROUND(AVG(
      CASE WHEN t.fdResuelto IS NOT NULL
        THEN GREATEST(0, TIMESTAMPDIFF(MINUTE, t.fdFechaIngreso, t.fdResuelto) - IFNULL(t.fiMinutosEnEspera, 0)) / 60.0
      END
    ), 2) AS fnHorasSolucionPromedio,
    ROUND(
      100.0 * SUM(CASE WHEN t.fbSlaSolucionCumplido = 1 THEN 1 ELSE 0 END)
      / NULLIF(SUM(CASE WHEN t.fbSlaSolucionCumplido IS NOT NULL THEN 1 ELSE 0 END), 0)
    , 2) AS fnPctSlaSolucion,
    ROUND(AVG(CASE WHEN en.fiCalificacion IS NOT NULL THEN en.fiCalificacion END), 2) AS fnSatisfaccionPromedio
  FROM ticket t
  INNER JOIN sucursal s ON s.fiId = t.fiSucursalId
  INNER JOIN estado e ON e.fiId = t.fiEstadoId
  LEFT JOIN ticketencuesta en ON en.fiTicketId = t.fiId
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
END$$
DELIMITER ;
