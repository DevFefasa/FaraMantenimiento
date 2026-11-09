-- 59_sp_reporte_cumplimiento_preventivo.sql
-- Callers: PreventivoRepositorio.CumplimientoAsync; PreventivosController.Calendario (tarjeta %)
-- API: sp_reporte_cumplimiento_preventivo(p_fdDesde, p_fdHasta, p_fiSucursalId)
-- Schema: fila estándar + resumen programados/ejecutados/% + detalle por plan
-- User instruction: "sp_reporte_cumplimiento_preventivo(desde,hasta,sucursal): programados vs ejecutados (ticket CERRADO/VALIDADO) y % de cumplimiento."
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_reporte_cumplimiento_preventivo;

DELIMITER $$

CREATE PROCEDURE sp_reporte_cumplimiento_preventivo(
  IN p_fdDesde DATE,
  IN p_fdHasta DATE,
  IN p_fiSucursalId INT
)
proc: BEGIN
  IF p_fdDesde IS NULL OR p_fdHasta IS NULL OR p_fdHasta < p_fdDesde THEN
    SELECT 400 AS fiCodigo, 'El rango de fechas no es válido' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces,
         JSON_OBJECT('desde', p_fdDesde, 'hasta', p_fdHasta) AS fjData;

  SELECT
    COUNT(*) AS fiProgramados,
    SUM(CASE WHEN est.fcCodigo IN ('CERRADO', 'VALIDADO') THEN 1 ELSE 0 END) AS fiEjecutados,
    ROUND(
      IF(COUNT(*) = 0, 0,
         100.0 * SUM(CASE WHEN est.fcCodigo IN ('CERRADO', 'VALIDADO') THEN 1 ELSE 0 END) / COUNT(*)),
      2
    ) AS fnPorcentajeCumplimiento
  FROM planpreventivoejecucion e
  JOIN planpreventivo p ON p.fiId = e.fiPlanId
  LEFT JOIN ticket tk ON tk.fiId = e.fiTicketId
  LEFT JOIN estado est ON est.fiId = tk.fiEstadoId
  WHERE e.fdFechaProgramada BETWEEN p_fdDesde AND p_fdHasta
    AND (p_fiSucursalId IS NULL OR p_fiSucursalId <= 0 OR p.fiSucursalId = p_fiSucursalId);

  SELECT
    p.fiId AS fiPlanId,
    p.fcNombre,
    p.fiSucursalId,
    s.fcNombre AS fcSucursalNombre,
    COUNT(*) AS fiProgramados,
    SUM(CASE WHEN est.fcCodigo IN ('CERRADO', 'VALIDADO') THEN 1 ELSE 0 END) AS fiEjecutados,
    ROUND(
      IF(COUNT(*) = 0, 0,
         100.0 * SUM(CASE WHEN est.fcCodigo IN ('CERRADO', 'VALIDADO') THEN 1 ELSE 0 END) / COUNT(*)),
      2
    ) AS fnPorcentajeCumplimiento
  FROM planpreventivoejecucion e
  JOIN planpreventivo p ON p.fiId = e.fiPlanId
  JOIN sucursal s ON s.fiId = p.fiSucursalId
  LEFT JOIN ticket tk ON tk.fiId = e.fiTicketId
  LEFT JOIN estado est ON est.fiId = tk.fiEstadoId
  WHERE e.fdFechaProgramada BETWEEN p_fdDesde AND p_fdHasta
    AND (p_fiSucursalId IS NULL OR p_fiSucursalId <= 0 OR p.fiSucursalId = p_fiSucursalId)
  GROUP BY p.fiId, p.fcNombre, p.fiSucursalId, s.fcNombre
  ORDER BY p.fcNombre;
END$$

DELIMITER ;
