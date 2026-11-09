-- 27_sp_ticket_obtener.sql
SET NAMES utf8mb4;
DROP PROCEDURE IF EXISTS sp_ticket_obtener;
DELIMITER $$
CREATE PROCEDURE sp_ticket_obtener(IN p_fiTicketId INT)
proc: BEGIN
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

  SELECT en.fiId, en.fiTicketId, en.fiCalificacion, en.fbConforme, en.fcComentario, en.fdFecha, en.fiUsuarioId
  FROM ticketencuesta en WHERE en.fiTicketId = p_fiTicketId;

  SELECT co.fiId, co.fiTicketId, co.fcComentario, co.fbInterno, co.fiUsuarioId, us.fcNombre AS fcUsuarioNombre, co.fdFecha
  FROM ticketcomentario co
  LEFT JOIN usuario us ON us.fiId = co.fiUsuarioId
  WHERE co.fiTicketId = p_fiTicketId AND co.fbActivo = 1
  ORDER BY co.fdFecha ASC, co.fiId ASC;
END$$
DELIMITER ;
