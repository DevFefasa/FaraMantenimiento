-- 08_sp_seguridad_rol_guardar.sql
-- Alta/edición básica de roles (nombre/descripcion) y activar
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_seguridad_rol_obtener;
DROP PROCEDURE IF EXISTS sp_seguridad_rol_guardar;
DROP PROCEDURE IF EXISTS sp_seguridad_rol_activar;

DELIMITER $$

CREATE PROCEDURE sp_seguridad_rol_obtener(IN p_fiId INT)
proc: BEGIN
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM rol WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'El rol no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('rol', p_fiId) AS fjData;
  SELECT r.fiId, r.fcCodigo, r.fcNombre, r.fcDescripcion, r.fbActivo, r.fdCreado, r.fdModificado
  FROM rol r WHERE r.fiId = p_fiId;
END$$

CREATE PROCEDURE sp_seguridad_rol_guardar(
  IN p_fiId INT,
  IN p_fcCodigo VARCHAR(30),
  IN p_fcNombre VARCHAR(100),
  IN p_fcDescripcion VARCHAR(250),
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_id INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; SELECT 500 AS fiCodigo, 'Ocurrió un error al guardar el rol' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;
  IF TRIM(IFNULL(p_fcCodigo,'')) = '' THEN SELECT 400 AS fiCodigo, 'El código es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc; END IF;
  IF TRIM(IFNULL(p_fcNombre,'')) = '' THEN SELECT 400 AS fiCodigo, 'El nombre es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc; END IF;
  START TRANSACTION;
  IF p_fiId IS NULL OR p_fiId <= 0 THEN
    IF EXISTS (SELECT 1 FROM rol WHERE fcCodigo = TRIM(p_fcCodigo)) THEN
      ROLLBACK; SELECT 409 AS fiCodigo, 'Ya existe un rol con ese código' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    INSERT INTO rol (fcCodigo, fcNombre, fcDescripcion, fiCreadoPor, fbActivo)
    VALUES (UPPER(TRIM(p_fcCodigo)), TRIM(p_fcNombre), NULLIF(TRIM(p_fcDescripcion),''), p_fiUsuarioId, 1);
    SET v_id = LAST_INSERT_ID(); COMMIT;
    SELECT 201 AS fiCodigo, 'Rol creado correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('rol', v_id) AS fjData;
  ELSE
    IF NOT EXISTS (SELECT 1 FROM rol WHERE fiId = p_fiId) THEN
      ROLLBACK; SELECT 404 AS fiCodigo, 'El rol no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    IF EXISTS (SELECT 1 FROM rol WHERE fcCodigo = TRIM(p_fcCodigo) AND fiId <> p_fiId) THEN
      ROLLBACK; SELECT 409 AS fiCodigo, 'Ya existe un rol con ese código' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    UPDATE rol SET fcCodigo = UPPER(TRIM(p_fcCodigo)), fcNombre = TRIM(p_fcNombre),
      fcDescripcion = NULLIF(TRIM(p_fcDescripcion),''), fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId
    WHERE fiId = p_fiId;
    SET v_id = p_fiId; COMMIT;
    SELECT 200 AS fiCodigo, 'Rol guardado correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('rol', v_id) AS fjData;
  END IF;
END$$

CREATE PROCEDURE sp_seguridad_rol_activar(IN p_fiId INT, IN p_fbActivo TINYINT, IN p_fiUsuarioId INT)
proc: BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; SELECT 500 AS fiCodigo, 'Ocurrió un error al actualizar el rol' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM rol WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'El rol no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  START TRANSACTION;
  UPDATE rol SET fbActivo = IF(IFNULL(p_fbActivo,0)=1,1,0), fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId WHERE fiId = p_fiId;
  COMMIT;
  SELECT 200 AS fiCodigo, IF(IFNULL(p_fbActivo,0)=1,'Rol activado correctamente','Rol desactivado correctamente') AS fcMensaje,
         1 AS fbSucces, JSON_OBJECT('rol', p_fiId) AS fjData;
END$$

DELIMITER ;
