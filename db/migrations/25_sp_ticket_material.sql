-- 25_sp_ticket_material.sql
SET NAMES utf8mb4;
DROP PROCEDURE IF EXISTS sp_ticket_material_guardar;
DROP PROCEDURE IF EXISTS sp_ticket_material_eliminar;
DELIMITER $$
CREATE PROCEDURE sp_ticket_material_guardar(
  IN p_fiId INT,
  IN p_fiTicketId INT,
  IN p_fcDescripcion VARCHAR(250),
  IN p_fnCantidad DECIMAL(12,2),
  IN p_fcUnidad VARCHAR(30),
  IN p_fnCostoUnitario DECIMAL(14,2),
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
  SET v_total = ROUND(IFNULL(p_fnCantidad,1) * IFNULL(p_fnCostoUnitario,0), 2);
  START TRANSACTION;
  IF p_fiId IS NULL OR p_fiId <= 0 THEN
    INSERT INTO ticketmaterial (fiTicketId, fcDescripcion, fnCantidad, fcUnidad, fnCostoUnitario, fnTotal, fiCreadoPor, fbActivo)
    VALUES (p_fiTicketId, TRIM(p_fcDescripcion), IFNULL(p_fnCantidad,1), NULLIF(TRIM(p_fcUnidad),''), IFNULL(p_fnCostoUnitario,0), v_total, p_fiUsuarioId, 1);
    SET v_id = LAST_INSERT_ID();
  ELSE
    IF NOT EXISTS (SELECT 1 FROM ticketmaterial WHERE fiId = p_fiId AND fiTicketId = p_fiTicketId AND fbActivo = 1) THEN
      ROLLBACK; SELECT 404 AS fiCodigo, 'El material no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    UPDATE ticketmaterial SET fcDescripcion = TRIM(p_fcDescripcion), fnCantidad = IFNULL(p_fnCantidad,1),
      fcUnidad = NULLIF(TRIM(p_fcUnidad),''), fnCostoUnitario = IFNULL(p_fnCostoUnitario,0), fnTotal = v_total,
      fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId
    WHERE fiId = p_fiId;
    SET v_id = p_fiId;
  END IF;
  UPDATE ticket SET fnCostoMateriales = (SELECT IFNULL(SUM(fnTotal),0) FROM ticketmaterial WHERE fiTicketId = p_fiTicketId AND fbActivo = 1),
    fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId WHERE fiId = p_fiTicketId;
  COMMIT;
  SELECT 200 AS fiCodigo, 'Material guardado correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('ticketmaterial', v_id, 'ticket', p_fiTicketId) AS fjData;
END$$

CREATE PROCEDURE sp_ticket_material_eliminar(IN p_fiId INT, IN p_fiUsuarioId INT)
proc: BEGIN
  DECLARE v_ticket INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; SELECT 500 AS fiCodigo, 'Ocurrió un error al eliminar el material' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;
  SELECT fiTicketId INTO v_ticket FROM ticketmaterial WHERE fiId = p_fiId AND fbActivo = 1 LIMIT 1;
  IF v_ticket IS NULL THEN SELECT 404 AS fiCodigo, 'El material no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc; END IF;
  START TRANSACTION;
  UPDATE ticketmaterial SET fbActivo = 0, fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId WHERE fiId = p_fiId;
  UPDATE ticket SET fnCostoMateriales = (SELECT IFNULL(SUM(fnTotal),0) FROM ticketmaterial WHERE fiTicketId = v_ticket AND fbActivo = 1),
    fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId WHERE fiId = v_ticket;
  COMMIT;
  SELECT 200 AS fiCodigo, 'Material eliminado correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('ticketmaterial', p_fiId, 'ticket', v_ticket) AS fjData;
END$$
DELIMITER ;
