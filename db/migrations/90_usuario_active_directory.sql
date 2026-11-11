-- 90_usuario_active_directory.sql
-- Callers: SeguridadRepositorio (ObtenerPorLogin/GuardarUsuario/LoginAdAlta);
--   SeguridadServicio.AutenticarAsync / GuardarUsuarioAsync.
-- API: sp_seguridad_usuario_*; sp_seguridad_login_ad_alta; fcCampoCoincide.
-- Schema: usuario.fcActiveDirectory VARCHAR(100) NULL + uk_usuario_ad. Sin prod data.
-- User instruction: "Migración db/migrations/90_usuario_active_directory.sql
--   (idempotente...): usuario.fcActiveDirectory ... UNIQUE ... Backfill ..."
-- No existe 90_* ni fcActiveDirectory (Grep).
SET NAMES utf8mb4;

SET @col := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'usuario' AND COLUMN_NAME = 'fcActiveDirectory'
);
SET @sql := IF(@col = 0,
  'ALTER TABLE usuario ADD COLUMN fcActiveDirectory VARCHAR(100) NULL COMMENT ''Usuario de dominio (AD) vinculado'' AFTER fcUsuario',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @uk := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'usuario' AND INDEX_NAME = 'uk_usuario_ad'
);
SET @sql := IF(@uk = 0,
  'ALTER TABLE usuario ADD UNIQUE KEY uk_usuario_ad (fcActiveDirectory)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

UPDATE usuario
SET fcActiveDirectory = fcUsuario
WHERE fbEsLocal = 0
  AND (fcActiveDirectory IS NULL OR TRIM(fcActiveDirectory) = '')
  AND TRIM(IFNULL(fcUsuario,'')) <> '';

DROP PROCEDURE IF EXISTS sp_seguridad_usuario_listar;
DROP PROCEDURE IF EXISTS sp_seguridad_usuario_obtener;
DROP PROCEDURE IF EXISTS sp_seguridad_usuario_guardar;
DROP PROCEDURE IF EXISTS sp_seguridad_usuario_por_login;
DROP PROCEDURE IF EXISTS sp_seguridad_login_ad_alta;

DELIMITER $$

CREATE PROCEDURE sp_seguridad_usuario_listar(IN p_fbSoloActivos TINYINT)
BEGIN
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;
  SELECT u.fiId, u.fcUsuario, u.fcActiveDirectory, u.fcNombre, u.fcCargo, u.fcCorreo, u.fcTelefono,
         u.fiRolId, r.fcCodigo AS fcRolCodigo, r.fcNombre AS fcRolNombre,
         u.fiSucursalId, u.fbEsLocal, u.fbDebeCambiarClave, u.fbActivo, u.fdUltimoAcceso, u.fdCreado, u.fdModificado,
         CASE WHEN u.fcClaveHash IS NULL OR u.fcClaveHash = '' THEN 0 ELSE 1 END AS fbTieneClave
  FROM usuario u
  INNER JOIN rol r ON r.fiId = u.fiRolId
  WHERE (IFNULL(p_fbSoloActivos, 1) = 0 OR u.fbActivo = 1)
  ORDER BY u.fcNombre;
END$$

CREATE PROCEDURE sp_seguridad_usuario_obtener(IN p_fiId INT)
proc: BEGIN
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM usuario WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'El usuario no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('usuario', p_fiId) AS fjData;
  SELECT u.fiId, u.fcUsuario, u.fcActiveDirectory, u.fcNombre, u.fcCargo, u.fcCorreo, u.fcTelefono,
         u.fiRolId, r.fcCodigo AS fcRolCodigo, r.fcNombre AS fcRolNombre,
         u.fiSucursalId, u.fbEsLocal, u.fbDebeCambiarClave, u.fbActivo, u.fdUltimoAcceso,
         u.fdCreado, u.fiCreadoPor, u.fdModificado, u.fiModificadoPor,
         CASE WHEN u.fcClaveHash IS NULL OR u.fcClaveHash = '' THEN 0 ELSE 1 END AS fbTieneClave
  FROM usuario u
  INNER JOIN rol r ON r.fiId = u.fiRolId
  WHERE u.fiId = p_fiId;
END$$

CREATE PROCEDURE sp_seguridad_usuario_guardar(
  IN p_fiId INT,
  IN p_fcUsuario VARCHAR(100),
  IN p_fcActiveDirectory VARCHAR(100),
  IN p_fcNombre VARCHAR(150),
  IN p_fcCargo VARCHAR(100),
  IN p_fcCorreo VARCHAR(150),
  IN p_fcTelefono VARCHAR(40),
  IN p_fiRolId INT,
  IN p_fiSucursalId INT,
  IN p_fbEsLocal TINYINT,
  IN p_fcClaveHash VARCHAR(128),
  IN p_fbDebeCambiarClave TINYINT,
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_id INT;
  DECLARE v_ad VARCHAR(100);
  DECLARE v_otroUsuario VARCHAR(100);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al guardar el usuario' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  SET v_ad = NULLIF(TRIM(IFNULL(p_fcActiveDirectory,'')), '');

  IF TRIM(IFNULL(p_fcUsuario,'')) = '' THEN
    SELECT 400 AS fiCodigo, 'El usuario es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF TRIM(IFNULL(p_fcNombre,'')) = '' THEN
    SELECT 400 AS fiCodigo, 'El nombre es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF p_fiRolId IS NULL OR p_fiRolId <= 0 OR NOT EXISTS (SELECT 1 FROM rol WHERE fiId = p_fiRolId AND fbActivo = 1) THEN
    SELECT 400 AS fiCodigo, 'El rol no es válido' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;

  IF v_ad IS NOT NULL THEN
    SELECT fcUsuario INTO v_otroUsuario
    FROM usuario
    WHERE LOWER(fcActiveDirectory) = LOWER(v_ad)
      AND (p_fiId IS NULL OR p_fiId <= 0 OR fiId <> p_fiId)
    LIMIT 1;
    IF v_otroUsuario IS NOT NULL THEN
      SELECT 409 AS fiCodigo,
             CONCAT('El usuario de AD ', v_ad, ' ya está vinculado a ', v_otroUsuario) AS fcMensaje,
             0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
  END IF;

  START TRANSACTION;
  IF p_fiId IS NULL OR p_fiId <= 0 THEN
    IF EXISTS (SELECT 1 FROM usuario WHERE LOWER(fcUsuario) = LOWER(TRIM(p_fcUsuario))) THEN
      ROLLBACK;
      SELECT 409 AS fiCodigo, 'Ya existe un usuario con ese nombre' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
    INSERT INTO usuario (fcUsuario, fcActiveDirectory, fcNombre, fcCargo, fcCorreo, fcTelefono, fiRolId, fiSucursalId, fbEsLocal, fcClaveHash, fbDebeCambiarClave, fiCreadoPor, fbActivo)
    VALUES (
      TRIM(p_fcUsuario), v_ad, TRIM(p_fcNombre), NULLIF(TRIM(p_fcCargo),''), NULLIF(TRIM(p_fcCorreo),''), NULLIF(TRIM(p_fcTelefono),''),
      p_fiRolId,
      IF(p_fiSucursalId IS NULL OR p_fiSucursalId <= 0, NULL, p_fiSucursalId),
      IF(IFNULL(p_fbEsLocal,0)=1,1,0),
      NULLIF(TRIM(p_fcClaveHash),''),
      IF(IFNULL(p_fbDebeCambiarClave,0)=1,1,0),
      p_fiUsuarioId, 1
    );
    SET v_id = LAST_INSERT_ID();
    COMMIT;
    SELECT 201 AS fiCodigo, 'Usuario creado correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('usuario', v_id) AS fjData;
  ELSE
    IF NOT EXISTS (SELECT 1 FROM usuario WHERE fiId = p_fiId) THEN
      ROLLBACK;
      SELECT 404 AS fiCodigo, 'El usuario no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
    IF EXISTS (SELECT 1 FROM usuario WHERE LOWER(fcUsuario) = LOWER(TRIM(p_fcUsuario)) AND fiId <> p_fiId) THEN
      ROLLBACK;
      SELECT 409 AS fiCodigo, 'Ya existe un usuario con ese nombre' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
    UPDATE usuario SET
      fcUsuario = TRIM(p_fcUsuario),
      fcActiveDirectory = v_ad,
      fcNombre = TRIM(p_fcNombre),
      fcCargo = IF(p_fcCargo IS NULL, fcCargo, NULLIF(TRIM(p_fcCargo),'')),
      fcCorreo = NULLIF(TRIM(p_fcCorreo),''),
      fcTelefono = NULLIF(TRIM(p_fcTelefono),''),
      fiRolId = p_fiRolId,
      fiSucursalId = IF(p_fiSucursalId IS NULL OR p_fiSucursalId <= 0, NULL, p_fiSucursalId),
      fbEsLocal = IF(NULLIF(TRIM(p_fcClaveHash),'') IS NOT NULL, 1, fbEsLocal),
      fcClaveHash = IF(NULLIF(TRIM(p_fcClaveHash),'') IS NULL, fcClaveHash, TRIM(p_fcClaveHash)),
      fbDebeCambiarClave = IF(p_fbDebeCambiarClave IS NULL, fbDebeCambiarClave, IF(p_fbDebeCambiarClave=1,1,0)),
      fdModificado = NOW(),
      fiModificadoPor = p_fiUsuarioId
    WHERE fiId = p_fiId;
    SET v_id = p_fiId;
    COMMIT;
    SELECT 200 AS fiCodigo, 'Usuario guardado correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('usuario', v_id) AS fjData;
  END IF;
END$$

CREATE PROCEDURE sp_seguridad_usuario_por_login(IN p_fcUsuario VARCHAR(100))
proc: BEGIN
  DECLARE v_id INT;
  DECLARE v_campo VARCHAR(30);
  DECLARE v_login VARCHAR(100);

  IF TRIM(IFNULL(p_fcUsuario,'')) = '' THEN
    SELECT 400 AS fiCodigo, 'El usuario es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  SET v_login = TRIM(p_fcUsuario);

  SELECT u.fiId, 'fcUsuario' INTO v_id, v_campo
  FROM usuario u
  WHERE LOWER(u.fcUsuario) = LOWER(v_login) AND u.fbActivo = 1
  LIMIT 1;

  IF v_id IS NULL THEN
    SELECT u.fiId, 'fcActiveDirectory' INTO v_id, v_campo
    FROM usuario u
    WHERE u.fcActiveDirectory IS NOT NULL
      AND LOWER(u.fcActiveDirectory) = LOWER(v_login)
      AND u.fbActivo = 1
    LIMIT 1;
  END IF;

  IF v_id IS NULL THEN
    SELECT 404 AS fiCodigo, 'Usuario no encontrado o inactivo' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces,
         JSON_OBJECT('usuario', v_id, 'fcCampoCoincide', v_campo) AS fjData;
  SELECT u.fiId, u.fcUsuario, u.fcActiveDirectory, u.fcNombre, u.fcCargo, u.fcCorreo, u.fcTelefono,
         u.fiRolId, r.fcCodigo AS fcRolCodigo, r.fcNombre AS fcRolNombre,
         u.fiSucursalId, u.fbEsLocal, u.fcClaveHash, u.fbDebeCambiarClave, u.fbActivo, u.fdUltimoAcceso,
         v_campo AS fcCampoCoincide
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
  DECLARE v_ad VARCHAR(100);
  DECLARE v_localAd VARCHAR(100);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al registrar el usuario de dominio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  IF TRIM(IFNULL(p_fcUsuario,'')) = '' THEN
    SELECT 400 AS fiCodigo, 'El usuario es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  SET v_ad = TRIM(p_fcUsuario);

  SELECT fiId INTO v_id
  FROM usuario
  WHERE fcActiveDirectory IS NOT NULL AND LOWER(fcActiveDirectory) = LOWER(v_ad)
  LIMIT 1;

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
    SELECT u.fiId, u.fcUsuario, u.fcActiveDirectory, u.fcNombre, u.fcCargo, u.fcCorreo, u.fcTelefono,
           u.fiRolId, r.fcCodigo AS fcRolCodigo, r.fcNombre AS fcRolNombre,
           u.fiSucursalId, u.fbEsLocal, u.fcClaveHash, u.fbDebeCambiarClave, u.fbActivo, u.fdUltimoAcceso
    FROM usuario u INNER JOIN rol r ON r.fiId = u.fiRolId WHERE u.fiId = v_id;
    LEAVE proc;
  END IF;

  SELECT fiId, fcActiveDirectory INTO v_id, v_localAd
  FROM usuario
  WHERE LOWER(fcUsuario) = LOWER(v_ad)
  LIMIT 1;

  IF v_id IS NOT NULL THEN
    SELECT 409 AS fiCodigo,
           'Existe un usuario local con ese nombre; vincúlelo desde Seguridad' AS fcMensaje,
           0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  SELECT fiId INTO v_rolId FROM rol WHERE fcCodigo = 'SOLICITANTE' AND fbActivo = 1 LIMIT 1;
  IF v_rolId IS NULL THEN
    SELECT 500 AS fiCodigo, 'No está configurado el rol solicitante' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  START TRANSACTION;
  INSERT INTO usuario (fcUsuario, fcActiveDirectory, fcNombre, fcCargo, fcCorreo, fcTelefono, fiRolId, fbEsLocal, fcClaveHash, fbActivo, fdUltimoAcceso)
  VALUES (
    v_ad, v_ad,
    IFNULL(NULLIF(TRIM(p_fcNombre),''), v_ad),
    NULLIF(TRIM(p_fcCargo),''),
    NULLIF(TRIM(p_fcCorreo),''),
    NULLIF(TRIM(p_fcTelefono),''),
    v_rolId, 0, NULL, 1, NOW()
  );
  SET v_id = LAST_INSERT_ID();
  COMMIT;

  SELECT 201 AS fiCodigo, 'Usuario de dominio registrado' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('usuario', v_id) AS fjData;
  SELECT u.fiId, u.fcUsuario, u.fcActiveDirectory, u.fcNombre, u.fcCargo, u.fcCorreo, u.fcTelefono,
         u.fiRolId, r.fcCodigo AS fcRolCodigo, r.fcNombre AS fcRolNombre,
         u.fiSucursalId, u.fbEsLocal, u.fcClaveHash, u.fbDebeCambiarClave, u.fbActivo, u.fdUltimoAcceso
  FROM usuario u INNER JOIN rol r ON r.fiId = u.fiRolId WHERE u.fiId = v_id;
END$$

DELIMITER ;
