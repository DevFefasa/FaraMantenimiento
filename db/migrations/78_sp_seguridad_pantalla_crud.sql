-- 78_sp_seguridad_pantalla_crud.sql
-- Callers: SeguridadRepositorio pantalla_*; SeguridadController Pantallas/Pantalla/ActivarPantalla.
-- API: sp_seguridad_pantalla_listar/obtener/guardar/activar.
-- Schema: pantalla (fiId, fcCodigo, fcNombre, fcDescripcion, fiOrden, fbActivo). Sin prod data.
-- User instruction: "CRUD de PERMISOS/PANTALLAS... sp_seguridad_pantalla_listar/guardar/activar"
--   + "pantallas usadas por el código... solo desactivar con aviso" + "Tu rango: 75-79".
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_seguridad_pantalla_listar;
DROP PROCEDURE IF EXISTS sp_seguridad_pantalla_obtener;
DROP PROCEDURE IF EXISTS sp_seguridad_pantalla_guardar;
DROP PROCEDURE IF EXISTS sp_seguridad_pantalla_activar;

DELIMITER $$

CREATE PROCEDURE sp_seguridad_pantalla_listar(IN p_fbSoloActivos TINYINT)
BEGIN
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;
  SELECT p.fiId, p.fcCodigo, p.fcNombre, p.fcDescripcion, p.fiOrden, p.fbActivo, p.fdCreado, p.fdModificado
  FROM pantalla p
  WHERE (IFNULL(p_fbSoloActivos, 1) = 0 OR p.fbActivo = 1)
  ORDER BY p.fiOrden, p.fcCodigo;
END$$

CREATE PROCEDURE sp_seguridad_pantalla_obtener(IN p_fiId INT)
proc: BEGIN
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM pantalla WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'La pantalla no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('pantalla', p_fiId) AS fjData;
  SELECT p.fiId, p.fcCodigo, p.fcNombre, p.fcDescripcion, p.fiOrden, p.fbActivo, p.fdCreado, p.fdModificado
  FROM pantalla p WHERE p.fiId = p_fiId;
END$$

CREATE PROCEDURE sp_seguridad_pantalla_guardar(
  IN p_fiId INT,
  IN p_fcCodigo VARCHAR(50),
  IN p_fcNombre VARCHAR(100),
  IN p_fcDescripcion VARCHAR(250),
  IN p_fiOrden INT,
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_id INT;
  DECLARE v_codigoAnt VARCHAR(50);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; SELECT 500 AS fiCodigo, 'Ocurrió un error al guardar la pantalla' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;

  IF TRIM(IFNULL(p_fcCodigo,'')) = '' THEN
    SELECT 400 AS fiCodigo, 'El código es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF TRIM(IFNULL(p_fcNombre,'')) = '' THEN
    SELECT 400 AS fiCodigo, 'El nombre es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;

  START TRANSACTION;
  IF p_fiId IS NULL OR p_fiId <= 0 THEN
    IF EXISTS (SELECT 1 FROM pantalla WHERE fcCodigo = UPPER(TRIM(p_fcCodigo))) THEN
      ROLLBACK; SELECT 409 AS fiCodigo, 'Ya existe una pantalla con ese código' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    INSERT INTO pantalla (fcCodigo, fcNombre, fcDescripcion, fiOrden, fiCreadoPor, fbActivo)
    VALUES (UPPER(TRIM(p_fcCodigo)), TRIM(p_fcNombre), NULLIF(TRIM(p_fcDescripcion),''), IFNULL(p_fiOrden,0), p_fiUsuarioId, 1);
    SET v_id = LAST_INSERT_ID(); COMMIT;
    SELECT 201 AS fiCodigo, 'Pantalla creada correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('pantalla', v_id) AS fjData;
  ELSE
    IF NOT EXISTS (SELECT 1 FROM pantalla WHERE fiId = p_fiId) THEN
      ROLLBACK; SELECT 404 AS fiCodigo, 'La pantalla no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    SELECT fcCodigo INTO v_codigoAnt FROM pantalla WHERE fiId = p_fiId;
    IF EXISTS (SELECT 1 FROM pantalla WHERE fcCodigo = UPPER(TRIM(p_fcCodigo)) AND fiId <> p_fiId) THEN
      ROLLBACK; SELECT 409 AS fiCodigo, 'Ya existe una pantalla con ese código' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    UPDATE pantalla SET
      fcCodigo = IF(v_codigoAnt IN (
          'DASHBOARD','TICKET_CREAR','TICKET_MIOS','TICKET_BANDEJA','TICKET_APROBACION','TICKET_TODOS',
          'CATALOGOS','REPORTES','SEGURIDAD','PREVENTIVOS'
        ), v_codigoAnt, UPPER(TRIM(p_fcCodigo))),
      fcNombre = TRIM(p_fcNombre),
      fcDescripcion = NULLIF(TRIM(p_fcDescripcion),''),
      fiOrden = IFNULL(p_fiOrden, fiOrden),
      fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId
    WHERE fiId = p_fiId;
    SET v_id = p_fiId; COMMIT;
    SELECT 200 AS fiCodigo, 'Pantalla guardada correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('pantalla', v_id) AS fjData;
  END IF;
END$$

CREATE PROCEDURE sp_seguridad_pantalla_activar(IN p_fiId INT, IN p_fbActivo TINYINT, IN p_fiUsuarioId INT)
proc: BEGIN
  DECLARE v_codigo VARCHAR(50);
  DECLARE v_sistema TINYINT DEFAULT 0;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; SELECT 500 AS fiCodigo, 'Ocurrió un error al actualizar la pantalla' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM pantalla WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'La pantalla no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  SELECT fcCodigo INTO v_codigo FROM pantalla WHERE fiId = p_fiId;
  IF v_codigo IN (
      'DASHBOARD','TICKET_CREAR','TICKET_MIOS','TICKET_BANDEJA','TICKET_APROBACION','TICKET_TODOS',
      'CATALOGOS','REPORTES','SEGURIDAD','PREVENTIVOS'
    ) THEN
    SET v_sistema = 1;
  END IF;
  START TRANSACTION;
  UPDATE pantalla SET fbActivo = IF(IFNULL(p_fbActivo,0)=1,1,0), fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId WHERE fiId = p_fiId;
  COMMIT;
  SELECT 200 AS fiCodigo,
         CASE
           WHEN IFNULL(p_fbActivo,0)=1 THEN 'Pantalla activada correctamente'
           WHEN v_sistema = 1 THEN 'Pantalla del sistema desactivada; puede afectar el menú y los permisos'
           ELSE 'Pantalla desactivada correctamente'
         END AS fcMensaje,
         1 AS fbSucces, JSON_OBJECT('pantalla', p_fiId, 'sistema', v_sistema) AS fjData;
END$$

DELIMITER ;
