-- 91_ticket_sap_material_proveedor.sql
-- Callers: TicketRepositorio GuardarMaterial/Obtener; Detalle materiales/proveedor SAP
-- API: ticketmaterial.fcCodigoSap; ticket.fcProveedorSapCodigo/fcProveedorSapNombre;
--      sp_ticket_material_guardar (+p_fcCodigoSap); sp_ticket_obtener (campos SAP)
-- Schema: columnas nuevas NULL (conserva datos). Confirm: Glob db/migrations/91_* vacío.
-- User instruction: "Migración 91 (idempotente): columnas para código SAP en ticketmaterial y código/nombre de proveedor SAP en ticket (o donde hoy se guarde el proveedor), y ajuste de los SP afectados. Conserva los datos existentes."
SET NAMES utf8mb4;

ALTER TABLE ticketmaterial
  ADD COLUMN IF NOT EXISTS fcCodigoSap VARCHAR(50) NULL COMMENT 'ItemCode SAP B1 (OITM)' AFTER fiTicketId;

ALTER TABLE ticket
  ADD COLUMN IF NOT EXISTS fcProveedorSapCodigo VARCHAR(50) NULL COMMENT 'CardCode SAP B1 (OCRD S)' AFTER fiProveedorId,
  ADD COLUMN IF NOT EXISTS fcProveedorSapNombre VARCHAR(200) NULL COMMENT 'CardName SAP al asignar' AFTER fcProveedorSapCodigo;

DROP PROCEDURE IF EXISTS sp_ticket_material_guardar;
DELIMITER $$
CREATE PROCEDURE sp_ticket_material_guardar(
  IN p_fiId INT,
  IN p_fiTicketId INT,
  IN p_fcDescripcion VARCHAR(250),
  IN p_fnCantidad DECIMAL(12,2),
  IN p_fcUnidad VARCHAR(30),
  IN p_fnCostoUnitario DECIMAL(14,2),
  IN p_fcCodigoSap VARCHAR(50),
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_id INT; DECLARE v_total DECIMAL(14,2);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; SELECT 500 AS fiCodigo, 'Ocurrió un error al guardar el material' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;
  IF p_fiTicketId IS NULL OR NOT EXISTS (SELECT 1 FROM ticket WHERE fiId = p_fiTicketId AND fbActivo = 1) THEN
    SELECT 404 AS fiCodigo, 'El ticket no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF TRIM(IFNULL(p_fcDescripcion,'')) = '' THEN
    SELECT 400 AS fiCodigo, 'La descripción del material es obligatoria' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF IFNULL(p_fnCantidad,1) < 0 THEN
    SELECT 400 AS fiCodigo, 'La cantidad no puede ser negativa' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF IFNULL(p_fnCostoUnitario,0) < 0 THEN
    SELECT 400 AS fiCodigo, 'El costo unitario no puede ser negativo' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  SET v_total = ROUND(IFNULL(p_fnCantidad,1) * IFNULL(p_fnCostoUnitario,0), 2);
  START TRANSACTION;
  IF p_fiId IS NULL OR p_fiId <= 0 THEN
    INSERT INTO ticketmaterial (fiTicketId, fcCodigoSap, fcDescripcion, fnCantidad, fcUnidad, fnCostoUnitario, fnTotal, fiCreadoPor, fbActivo)
    VALUES (p_fiTicketId, NULLIF(TRIM(p_fcCodigoSap),''), TRIM(p_fcDescripcion), IFNULL(p_fnCantidad,1),
            NULLIF(TRIM(p_fcUnidad),''), IFNULL(p_fnCostoUnitario,0), v_total, p_fiUsuarioId, 1);
    SET v_id = LAST_INSERT_ID();
  ELSE
    IF NOT EXISTS (SELECT 1 FROM ticketmaterial WHERE fiId = p_fiId AND fiTicketId = p_fiTicketId AND fbActivo = 1) THEN
      ROLLBACK; SELECT 404 AS fiCodigo, 'El material no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    UPDATE ticketmaterial SET
      fcCodigoSap = NULLIF(TRIM(p_fcCodigoSap),''),
      fcDescripcion = TRIM(p_fcDescripcion),
      fnCantidad = IFNULL(p_fnCantidad,1),
      fcUnidad = NULLIF(TRIM(p_fcUnidad),''),
      fnCostoUnitario = IFNULL(p_fnCostoUnitario,0),
      fnTotal = v_total,
      fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId
    WHERE fiId = p_fiId AND fiTicketId = p_fiTicketId;
    SET v_id = p_fiId;
  END IF;
  UPDATE ticket SET fnCostoMateriales = (SELECT IFNULL(SUM(fnTotal),0) FROM ticketmaterial WHERE fiTicketId = p_fiTicketId AND fbActivo = 1),
    fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId WHERE fiId = p_fiTicketId;
  COMMIT;
  SELECT 200 AS fiCodigo, 'Material guardado correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('ticketmaterial', v_id, 'ticket', p_fiTicketId) AS fjData;
END$$
DELIMITER ;

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
         t.fiProveedorId, t.fcProveedorSapCodigo, t.fcProveedorSapNombre,
         COALESCE(NULLIF(TRIM(t.fcProveedorSapNombre),''), pr.fcNombre) AS fcProveedorNombre,
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

  SELECT m.fiId, m.fiTicketId, m.fcCodigoSap, m.fcDescripcion, m.fnCantidad, m.fcUnidad, m.fnCostoUnitario, m.fnTotal, m.fdCreado, m.fiCreadoPor
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
