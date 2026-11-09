-- 60_sp_seguridad_permisos_usuario_rol.sql
-- Revisión A4: los permisos se releen en cada petición; ahora también el rol vigente
-- (en fjData) y se rechaza al usuario o rol inactivo para invalidar la sesión.
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_seguridad_permisos_usuario;

DELIMITER $$

CREATE PROCEDURE sp_seguridad_permisos_usuario(IN p_fiUsuarioId INT)
proc: BEGIN
  DECLARE v_rolId INT;
  DECLARE v_rolCodigo VARCHAR(50);
  DECLARE v_rolActivo TINYINT;

  IF p_fiUsuarioId IS NULL OR p_fiUsuarioId <= 0 OR NOT EXISTS (SELECT 1 FROM usuario WHERE fiId = p_fiUsuarioId AND fbActivo = 1) THEN
    SELECT 404 AS fiCodigo, 'El usuario no existe o está inactivo' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  SELECT r.fiId, r.fcCodigo, r.fbActivo INTO v_rolId, v_rolCodigo, v_rolActivo
  FROM usuario u INNER JOIN rol r ON r.fiId = u.fiRolId
  WHERE u.fiId = p_fiUsuarioId
  LIMIT 1;

  IF v_rolId IS NULL OR IFNULL(v_rolActivo, 0) = 0 THEN
    SELECT 403 AS fiCodigo, 'El rol del usuario está inactivo' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces,
         JSON_OBJECT('usuario', p_fiUsuarioId, 'fiRolId', v_rolId, 'fcRolCodigo', v_rolCodigo) AS fjData;
  SELECT p.fcCodigo AS fcPantalla, p.fcNombre
  FROM rolpermiso rp
  INNER JOIN pantalla p ON p.fiId = rp.fiPantallaId AND p.fbActivo = 1
  WHERE rp.fiRolId = v_rolId
  ORDER BY p.fiOrden, p.fcCodigo;
END$$

DELIMITER ;
