-- 50_sp_reporte_activo_hojavida.sql
-- Callers: ReporteRepositorio.HojaVidaAsync / Reportes/HojaVida
SET NAMES utf8mb4;
DROP PROCEDURE IF EXISTS sp_reporte_activo_hojavida;
DELIMITER $$
CREATE PROCEDURE sp_reporte_activo_hojavida(IN p_fiActivoId INT)
proc: BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    SELECT 500 AS fiCodigo, 'Ocurrió un error al consultar la hoja de vida' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  IF p_fiActivoId IS NULL OR p_fiActivoId <= 0 THEN
    SELECT 400 AS fiCodigo, 'Seleccione un activo' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM activo a WHERE a.fiId = p_fiActivoId AND a.fbActivo = 1) THEN
    SELECT 404 AS fiCodigo, 'El activo no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('activo', p_fiActivoId) AS fjData;

  -- 2) Datos del activo
  SELECT
    a.fiId AS fiActivoId,
    a.fcCodigo,
    a.fcNombre,
    a.fcMarca,
    a.fcModelo,
    a.fcSerie,
    a.fdFechaInstalacion,
    s.fcNombre AS fcSucursalNombre,
    s.fcCodigo AS fcSucursalCodigo,
    u.fcNombre AS fcUbicacionNombre,
    c.fcNombre AS fcCategoriaNombre,
    c.fcCodigo AS fcCategoriaCodigo
  FROM activo a
  INNER JOIN sucursal s ON s.fiId = a.fiSucursalId
  LEFT JOIN ubicacion u ON u.fiId = a.fiUbicacionId
  LEFT JOIN categoria c ON c.fiId = a.fiCategoriaId
  WHERE a.fiId = p_fiActivoId;

  -- 3) Tickets del activo
  SELECT
    t.fiId AS fiTicketId,
    t.fcNumero,
    t.fdFechaIngreso,
    tm.fcNombre AS fcTipoNombre,
    tm.fbEsPreventivo,
    cat.fcNombre AS fcCategoriaNombre,
    e.fcNombre AS fcEstadoNombre,
    e.fcCodigo AS fcEstadoCodigo,
    t.fcDiagnostico,
    t.fcCausaRaiz,
    ROUND(IFNULL(t.fnCostoManoObra,0)+IFNULL(t.fnCostoMateriales,0)+IFNULL(t.fnCostoProveedor,0), 2) AS fnCostoTotal
  FROM ticket t
  INNER JOIN tipomantenimiento tm ON tm.fiId = t.fiTipoMantenimientoId
  INNER JOIN categoria cat ON cat.fiId = t.fiCategoriaId
  INNER JOIN estado e ON e.fiId = t.fiEstadoId
  WHERE t.fbActivo = 1 AND t.fiActivoId = p_fiActivoId
  ORDER BY t.fdFechaIngreso DESC;

  -- 4) Totales
  SELECT
    COUNT(*) AS fiTickets,
    SUM(CASE WHEN tm.fbEsPreventivo = 0 THEN 1 ELSE 0 END) AS fiCorrectivos,
    SUM(CASE WHEN tm.fbEsPreventivo = 1 THEN 1 ELSE 0 END) AS fiPreventivos,
    SUM(CASE WHEN t.fbReincidencia = 1 THEN 1 ELSE 0 END) AS fiReincidencias,
    ROUND(SUM(IFNULL(t.fnCostoManoObra,0)), 2) AS fnCostoManoObra,
    ROUND(SUM(IFNULL(t.fnCostoMateriales,0)), 2) AS fnCostoMateriales,
    ROUND(SUM(IFNULL(t.fnCostoProveedor,0)), 2) AS fnCostoProveedor,
    ROUND(SUM(IFNULL(t.fnCostoManoObra,0)+IFNULL(t.fnCostoMateriales,0)+IFNULL(t.fnCostoProveedor,0)), 2) AS fnCostoTotal,
    ROUND(
      CASE
        WHEN SUM(CASE WHEN tm.fbEsPreventivo = 0 THEN 1 ELSE 0 END) <= 1 THEN NULL
        ELSE TIMESTAMPDIFF(DAY,
          MIN(CASE WHEN tm.fbEsPreventivo = 0 THEN t.fdFechaIngreso END),
          MAX(CASE WHEN tm.fbEsPreventivo = 0 THEN t.fdFechaIngreso END)
        ) / NULLIF(SUM(CASE WHEN tm.fbEsPreventivo = 0 THEN 1 ELSE 0 END) - 1, 0)
      END
    , 2) AS fnMtbfDias,
    MAX(t.fdFechaIngreso) AS fdUltimaIntervencion
  FROM ticket t
  INNER JOIN tipomantenimiento tm ON tm.fiId = t.fiTipoMantenimientoId
  WHERE t.fbActivo = 1 AND t.fiActivoId = p_fiActivoId;
END$$
DELIMITER ;
