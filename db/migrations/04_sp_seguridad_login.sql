-- 04_sp_seguridad_login.sql
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_seguridad_usuario_por_login;
DROP PROCEDURE IF EXISTS sp_seguridad_login_ad_alta;
DROP PROCEDURE IF EXISTS sp_seguridad_registrar_acceso;
DROP PROCEDURE IF EXISTS sp_seguridad_permisos_usuario;

DELIMITER $$

CREATE PROCEDURE sp_seguridad_usuario_por_login(IN p_fcUsuario VARCHAR(100))
proc: BEGIN
  DECLARE v_id INT;
  IF TRIM(IFNULL(p_fcUsuario,'')) = '' THEN
    SELECT 400 AS fiCodigo, 'El usuario es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  SELECT u.fiId INTO v_id
  FROM usuario u
  WHERE u.fcUsuario = TRIM(p_fcUsuario) AND u.fbActivo = 1
  LIMIT 1;

  IF v_id IS NULL THEN
    SELECT 404 AS fiCodigo, 'Usuario no encontrado o inactivo' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('usuario', v_id) AS fjData;
  SELECT u.fiId, u.fcUsuario, u.fcNombre, u.fcCargo, u.fcCorreo, u.fcTelefono,
         u.fiRolId, r.fcCodigo AS fcRolCodigo, r.fcNombre AS fcRolNombre,
         u.fiSucursalId, u.fbEsLocal, u.fcClaveHash, u.fbActivo, u.fdUltimoAcceso
  FROM usuario u
  INNER JOIN rol r ON r.fiId = u.fiRolId
  WHERE u.fiId = v_id;
END$$

CREATE PROCEDURE sp_seguridad_login_ad_alta(
  IN p_fcUsuario VARCHAR(100),
  IN p_fcNombre VARCHAR(150),
  IN p_fcCorreo VARCHAR(150),
  IN p_fcCargo VARCHAR(100),
  IN p_fcTelefono VARCHAR(40)
)
proc: BEGIN
  DECLARE v_id INT;
  DECLARE v_rolId INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al registrar el usuario de dominio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  IF TRIM(IFNULL(p_fcUsuario,'')) = '' THEN
    SELECT 400 AS fiCodigo, 'El usuario es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  SELECT fiId INTO v_id FROM usuario WHERE fcUsuario = TRIM(p_fcUsuario) LIMIT 1;
  IF v_id IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM usuario WHERE fiId = v_id AND fbActivo = 0) THEN
      SELECT 403 AS fiCodigo, 'El usuario está inactivo' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
    UPDATE usuario
    SET fcNombre = IFNULL(NULLIF(TRIM(p_fcNombre),''), fcNombre),
        fcCorreo = IFNULL(NULLIF(TRIM(p_fcCorreo),''), fcCorreo),
        fcCargo = IFNULL(NULLIF(TRIM(p_fcCargo),''), fcCargo),
        fcTelefono = IFNULL(NULLIF(TRIM(p_fcTelefono),''), fcTelefono),
        fdUltimoAcceso = NOW()
    WHERE fiId = v_id;
    SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('usuario', v_id) AS fjData;
    SELECT u.fiId, u.fcUsuario, u.fcNombre, u.fcCargo, u.fcCorreo, u.fcTelefono,
           u.fiRolId, r.fcCodigo AS fcRolCodigo, r.fcNombre AS fcRolNombre,
           u.fiSucursalId, u.fbEsLocal, u.fcClaveHash, u.fbActivo, u.fdUltimoAcceso
    FROM usuario u INNER JOIN rol r ON r.fiId = u.fiRolId WHERE u.fiId = v_id;
    LEAVE proc;
  END IF;

  SELECT fiId INTO v_rolId FROM rol WHERE fcCodigo = 'SOLICITANTE' AND fbActivo = 1 LIMIT 1;
  IF v_rolId IS NULL THEN
    SELECT 500 AS fiCodigo, 'No está configurado el rol solicitante' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  START TRANSACTION;
  INSERT INTO usuario (fcUsuario, fcNombre, fcCargo, fcCorreo, fcTelefono, fiRolId, fbEsLocal, fcClaveHash, fbActivo, fdUltimoAcceso)
  VALUES (
    TRIM(p_fcUsuario),
    IFNULL(NULLIF(TRIM(p_fcNombre),''), TRIM(p_fcUsuario)),
    NULLIF(TRIM(p_fcCargo),''),
    NULLIF(TRIM(p_fcCorreo),''),
    NULLIF(TRIM(p_fcTelefono),''),
    v_rolId, 0, NULL, 1, NOW()
  );
  SET v_id = LAST_INSERT_ID();
  COMMIT;

  SELECT 201 AS fiCodigo, 'Usuario de dominio registrado' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('usuario', v_id) AS fjData;
  SELECT u.fiId, u.fcUsuario, u.fcNombre, u.fcCargo, u.fcCorreo, u.fcTelefono,
         u.fiRolId, r.fcCodigo AS fcRolCodigo, r.fcNombre AS fcRolNombre,
         u.fiSucursalId, u.fbEsLocal, u.fcClaveHash, u.fbActivo, u.fdUltimoAcceso
  FROM usuario u INNER JOIN rol r ON r.fiId = u.fiRolId WHERE u.fiId = v_id;
END$$

CREATE PROCEDURE sp_seguridad_registrar_acceso(
  IN p_fiUsuarioId INT,
  IN p_fcUsuario VARCHAR(100),
  IN p_fcAccion VARCHAR(50),
  IN p_fcIp VARCHAR(45),
  IN p_fcDetalle VARCHAR(500)
)
proc: BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    SELECT 500 AS fiCodigo, 'Ocurrió un error al registrar el acceso' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  IF TRIM(IFNULL(p_fcAccion,'')) = '' THEN
    SELECT 400 AS fiCodigo, 'La acción es obligatoria' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  INSERT INTO bitacoraacceso (fiUsuarioId, fcUsuario, fcAccion, fcIp, fcDetalle)
  VALUES (
    IF(p_fiUsuarioId IS NULL OR p_fiUsuarioId <= 0, NULL, p_fiUsuarioId),
    NULLIF(TRIM(p_fcUsuario),''),
    TRIM(p_fcAccion),
    NULLIF(TRIM(p_fcIp),''),
    NULLIF(TRIM(p_fcDetalle),'')
  );

  IF p_fcAccion = 'LOGIN_OK' AND p_fiUsuarioId IS NOT NULL AND p_fiUsuarioId > 0 THEN
    UPDATE usuario SET fdUltimoAcceso = NOW() WHERE fiId = p_fiUsuarioId;
  END IF;

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('bitacoraacceso', LAST_INSERT_ID()) AS fjData;
END$$

CREATE PROCEDURE sp_seguridad_permisos_usuario(IN p_fiUsuarioId INT)
proc: BEGIN
  IF p_fiUsuarioId IS NULL OR p_fiUsuarioId <= 0 OR NOT EXISTS (SELECT 1 FROM usuario WHERE fiId = p_fiUsuarioId AND fbActivo = 1) THEN
    SELECT 404 AS fiCodigo, 'El usuario no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('usuario', p_fiUsuarioId) AS fjData;
  SELECT p.fcCodigo AS fcPantalla, p.fcNombre
  FROM usuario u
  INNER JOIN rolpermiso rp ON rp.fiRolId = u.fiRolId
  INNER JOIN pantalla p ON p.fiId = rp.fiPantallaId AND p.fbActivo = 1
  WHERE u.fiId = p_fiUsuarioId
  ORDER BY p.fiOrden, p.fcCodigo;
END$$

DELIMITER ;
