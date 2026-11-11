-- 92_sp_ticket_asignar_sap_proveedor.sql
-- Callers: TicketRepositorio.AsignarAsync; TicketsController.Asignar
-- API: sp_ticket_asignar (+p_fcProveedorSapCodigo, p_fcProveedorSapNombre);
--      PROVEEDOR acepta SAP (preferido) o fiProveedorId local (compatibilidad)
-- Schema: columnas mig 91. Confirm: Glob db/migrations/92_* vacío.
-- User instruction: "los proveedores se toman de los socios de negocio de SAP tipo proveedor (OCRD con CardType = 'S'); el catálogo local de proveedores deja de usarse para elegir (no lo borres)."
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_ticket_asignar;
DELIMITER $$
CREATE PROCEDURE sp_ticket_asignar(
  IN p_fiTicketId INT,
  IN p_fcTipoResponsable VARCHAR(20),
  IN p_fiTecnicoId INT,
  IN p_fiProveedorId INT,
  IN p_fcProveedorSapCodigo VARCHAR(50),
  IN p_fcProveedorSapNombre VARCHAR(200),
  IN p_fdFechaProgramada DATETIME,
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_estadoId INT; DECLARE v_estadoCod VARCHAR(30); DECLARE v_tipo VARCHAR(20);
  DECLARE v_asignadoId INT; DECLARE v_histId INT; DECLARE v_antId INT;
  DECLARE v_priResp DATETIME; DECLARE v_limResp DATETIME;
  DECLARE v_nuevaPri DATETIME; DECLARE v_slaResp TINYINT;
  DECLARE v_sapCod VARCHAR(50); DECLARE v_sapNom VARCHAR(200);
  DECLARE v_provLocal INT;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; SELECT 500 AS fiCodigo, 'Ocurrió un error al asignar el ticket' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;

  IF p_fiTicketId IS NULL OR NOT EXISTS (SELECT 1 FROM ticket WHERE fiId = p_fiTicketId AND fbActivo = 1) THEN
    SELECT 404 AS fiCodigo, 'El ticket no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  SET v_tipo = UPPER(TRIM(IFNULL(p_fcTipoResponsable,'')));
  IF v_tipo NOT IN ('INTERNO','PROVEEDOR') THEN
    SELECT 400 AS fiCodigo, 'El tipo de responsable debe ser INTERNO o PROVEEDOR' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF v_tipo = 'INTERNO' AND (p_fiTecnicoId IS NULL OR p_fiTecnicoId <= 0 OR NOT EXISTS (SELECT 1 FROM tecnico WHERE fiId = p_fiTecnicoId AND fbActivo = 1)) THEN
    SELECT 400 AS fiCodigo, 'Debe indicar un técnico válido' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;

  SET v_sapCod = NULLIF(TRIM(IFNULL(p_fcProveedorSapCodigo,'')), '');
  SET v_sapNom = NULLIF(TRIM(IFNULL(p_fcProveedorSapNombre,'')), '');
  SET v_provLocal = NULL;
  IF v_tipo = 'PROVEEDOR' THEN
    IF v_sapCod IS NOT NULL AND v_sapNom IS NOT NULL THEN
      SET v_provLocal = NULL;
    ELSEIF p_fiProveedorId IS NOT NULL AND p_fiProveedorId > 0 AND EXISTS (SELECT 1 FROM proveedor WHERE fiId = p_fiProveedorId AND fbActivo = 1) THEN
      SET v_provLocal = p_fiProveedorId;
      SELECT fcNombre INTO v_sapNom FROM proveedor WHERE fiId = p_fiProveedorId LIMIT 1;
    ELSE
      SELECT 400 AS fiCodigo, 'Debe indicar un proveedor SAP válido' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
  END IF;

  SELECT fiId INTO v_asignadoId FROM estado WHERE fcCodigo = 'ASIGNADO' AND fbActivo = 1 LIMIT 1;

  START TRANSACTION;

  SELECT t.fiEstadoId, e.fcCodigo, t.fdPrimeraRespuesta, t.fdLimiteRespuesta
  INTO v_estadoId, v_estadoCod, v_priResp, v_limResp
  FROM ticket t JOIN estado e ON e.fiId = t.fiEstadoId
  WHERE t.fiId = p_fiTicketId
  FOR UPDATE;

  IF v_estadoCod NOT IN ('APROBADO','ASIGNADO','EN_PROCESO') THEN
    ROLLBACK; SELECT 409 AS fiCodigo, 'El ticket no puede asignarse en su estado actual' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;

  IF v_priResp IS NULL AND v_estadoCod = 'APROBADO' THEN
    SET v_nuevaPri = NOW();
    SET v_slaResp = IF(NOW() <= IFNULL(v_limResp, NOW()), 1, 0);
  ELSE
    SET v_nuevaPri = v_priResp;
    SET v_slaResp = NULL;
  END IF;

  UPDATE ticket SET
    fcTipoResponsable = v_tipo,
    fiTecnicoId = IF(v_tipo = 'INTERNO', p_fiTecnicoId, NULL),
    fiProveedorId = IF(v_tipo = 'PROVEEDOR', v_provLocal, NULL),
    fcProveedorSapCodigo = IF(v_tipo = 'PROVEEDOR', v_sapCod, NULL),
    fcProveedorSapNombre = IF(v_tipo = 'PROVEEDOR', v_sapNom, NULL),
    fdFechaProgramada = p_fdFechaProgramada,
    fiEstadoId = IF(v_estadoCod = 'APROBADO', v_asignadoId, fiEstadoId),
    fdPrimeraRespuesta = IF(v_nuevaPri IS NOT NULL, v_nuevaPri, fdPrimeraRespuesta),
    fbSlaRespuestaCumplido = IF(v_slaResp IS NOT NULL, v_slaResp, fbSlaRespuestaCumplido),
    fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId
  WHERE fiId = p_fiTicketId;

  IF v_estadoCod = 'APROBADO' THEN
    SET v_antId = v_estadoId;
    INSERT INTO ticketestado (fiTicketId, fiEstadoAnteriorId, fiEstadoId, fcComentario, fiUsuarioId, fdFecha)
    VALUES (p_fiTicketId, v_antId, v_asignadoId, 'Ticket asignado', p_fiUsuarioId, NOW());
    SET v_histId = LAST_INSERT_ID();
  ELSE
    INSERT INTO ticketestado (fiTicketId, fiEstadoAnteriorId, fiEstadoId, fcComentario, fiUsuarioId, fdFecha)
    VALUES (p_fiTicketId, v_estadoId, v_estadoId, 'Responsable actualizado', p_fiUsuarioId, NOW());
    SET v_histId = LAST_INSERT_ID();
  END IF;
  COMMIT;
  SELECT 200 AS fiCodigo, 'Ticket asignado correctamente' AS fcMensaje, 1 AS fbSucces,
         JSON_OBJECT('ticket', p_fiTicketId, 'ticketestado', JSON_ARRAY(v_histId)) AS fjData;
END$$
DELIMITER ;
