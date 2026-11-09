-- 24_sp_ticket_ejecucion.sql
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
  START TRANSACTION;
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
  COMMIT;
  SELECT 200 AS fiCodigo, 'Ejecución guardada correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('ticket', p_fiTicketId) AS fjData;
END$$
DELIMITER ;
