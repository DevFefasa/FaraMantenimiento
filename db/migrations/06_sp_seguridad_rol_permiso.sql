-- 06_sp_seguridad_rol_permiso.sql
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_seguridad_rol_listar;
DROP PROCEDURE IF EXISTS sp_seguridad_pantalla_listar;
DROP PROCEDURE IF EXISTS sp_seguridad_rol_permisos_obtener;
DROP PROCEDURE IF EXISTS sp_seguridad_rol_permisos_guardar;

DELIMITER $$

CREATE PROCEDURE sp_seguridad_rol_listar(IN p_fbSoloActivos TINYINT)
BEGIN
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;
  SELECT r.fiId, r.fcCodigo, r.fcNombre, r.fcDescripcion, r.fbActivo, r.fdCreado, r.fdModificado
  FROM rol r
  WHERE (IFNULL(p_fbSoloActivos, 1) = 0 OR r.fbActivo = 1)
  ORDER BY r.fcNombre;
END$$

CREATE PROCEDURE sp_seguridad_pantalla_listar(IN p_fbSoloActivos TINYINT)
BEGIN
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;
  SELECT p.fiId, p.fcCodigo, p.fcNombre, p.fcDescripcion, p.fiOrden, p.fbActivo
  FROM pantalla p
  WHERE (IFNULL(p_fbSoloActivos, 1) = 0 OR p.fbActivo = 1)
  ORDER BY p.fiOrden, p.fcCodigo;
END$$

CREATE PROCEDURE sp_seguridad_rol_permisos_obtener(IN p_fiRolId INT)
proc: BEGIN
  IF p_fiRolId IS NULL OR p_fiRolId <= 0 OR NOT EXISTS (SELECT 1 FROM rol WHERE fiId = p_fiRolId) THEN
    SELECT 404 AS fiCodigo, 'El rol no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('rol', p_fiRolId) AS fjData;
  SELECT r.fiId, r.fcCodigo, r.fcNombre, r.fcDescripcion, r.fbActivo FROM rol r WHERE r.fiId = p_fiRolId;
  SELECT p.fiId, p.fcCodigo, p.fcNombre, p.fiOrden,
         CASE WHEN rp.fiId IS NULL THEN 0 ELSE 1 END AS fbAsignado
  FROM pantalla p
  LEFT JOIN rolpermiso rp ON rp.fiPantallaId = p.fiId AND rp.fiRolId = p_fiRolId
  WHERE p.fbActivo = 1
  ORDER BY p.fiOrden, p.fcCodigo;
END$$

CREATE PROCEDURE sp_seguridad_rol_permisos_guardar(
  IN p_fiRolId INT,
  IN p_fcPantallas TEXT,
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_cnt INT DEFAULT 0;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al guardar los permisos del rol' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  IF p_fiRolId IS NULL OR p_fiRolId <= 0 OR NOT EXISTS (SELECT 1 FROM rol WHERE fiId = p_fiRolId) THEN
    SELECT 404 AS fiCodigo, 'El rol no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  START TRANSACTION;
  DELETE FROM rolpermiso WHERE fiRolId = p_fiRolId;

  IF p_fcPantallas IS NOT NULL AND TRIM(p_fcPantallas) <> '' THEN
    INSERT INTO rolpermiso (fiRolId, fiPantallaId, fiCreadoPor)
    SELECT p_fiRolId, p.fiId, p_fiUsuarioId
    FROM pantalla p
    WHERE p.fbActivo = 1
      AND FIND_IN_SET(p.fcCodigo, REPLACE(TRIM(p_fcPantallas), ' ', '')) > 0;
  END IF;

  SELECT COUNT(*) INTO v_cnt FROM rolpermiso WHERE fiRolId = p_fiRolId;
  COMMIT;
  SELECT 200 AS fiCodigo, 'Permisos guardados correctamente' AS fcMensaje, 1 AS fbSucces,
         JSON_OBJECT('rol', p_fiRolId, 'permisos', v_cnt) AS fjData;
END$$

DELIMITER ;
