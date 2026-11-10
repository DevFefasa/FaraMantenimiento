-- 76_sp_seguridad_usuario_debe_cambiar.sql
-- Callers: SeguridadRepositorio.cs GuardarUsuarioAsync/Listar/Obtener/ObtenerPorLogin;
--   SeguridadServicio AutenticarAsync / GuardarUsuarioAsync / CambiarClavePropiaAsync.
-- API: sp_seguridad_usuario_* con p_fbDebeCambiarClave; SELECT fbDebeCambiarClave.
-- Schema: usuario.fbDebeCambiarClave (75). Sin datos de producción.
-- User instruction: "marcar al usuario para cambiar clave... (columna fbDebeCambiarClave;
--   reutiliza el mecanismo de M4...)" + "Tu rango de migraciones: 75-79".
-- Sustituye SPs de 05/04; no hay 76_* (Glob db/migrations/7*.sql = vacío salvo 75).
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_seguridad_usuario_listar;
DROP PROCEDURE IF EXISTS sp_seguridad_usuario_obtener;
DROP PROCEDURE IF EXISTS sp_seguridad_usuario_guardar;
DROP PROCEDURE IF EXISTS sp_seguridad_usuario_activar;
DROP PROCEDURE IF EXISTS sp_seguridad_usuario_por_login;

DELIMITER $$

CREATE PROCEDURE sp_seguridad_usuario_listar(IN p_fbSoloActivos TINYINT)
BEGIN
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;
  SELECT u.fiId, u.fcUsuario, u.fcNombre, u.fcCargo, u.fcCorreo, u.fcTelefono,
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
  SELECT u.fiId, u.fcUsuario, u.fcNombre, u.fcCargo, u.fcCorreo, u.fcTelefono,
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
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al guardar el usuario' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  IF TRIM(IFNULL(p_fcUsuario,'')) = '' THEN
    SELECT 400 AS fiCodigo, 'El usuario es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF TRIM(IFNULL(p_fcNombre,'')) = '' THEN
    SELECT 400 AS fiCodigo, 'El nombre es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF p_fiRolId IS NULL OR p_fiRolId <= 0 OR NOT EXISTS (SELECT 1 FROM rol WHERE fiId = p_fiRolId AND fbActivo = 1) THEN
    SELECT 400 AS fiCodigo, 'El rol no es válido' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;

  START TRANSACTION;
  IF p_fiId IS NULL OR p_fiId <= 0 THEN
    IF EXISTS (SELECT 1 FROM usuario WHERE fcUsuario = TRIM(p_fcUsuario)) THEN
      ROLLBACK;
      SELECT 409 AS fiCodigo, 'Ya existe un usuario con ese nombre' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
    INSERT INTO usuario (fcUsuario, fcNombre, fcCargo, fcCorreo, fcTelefono, fiRolId, fiSucursalId, fbEsLocal, fcClaveHash, fbDebeCambiarClave, fiCreadoPor, fbActivo)
    VALUES (
      TRIM(p_fcUsuario), TRIM(p_fcNombre), NULLIF(TRIM(p_fcCargo),''), NULLIF(TRIM(p_fcCorreo),''), NULLIF(TRIM(p_fcTelefono),''),
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
    IF EXISTS (SELECT 1 FROM usuario WHERE fcUsuario = TRIM(p_fcUsuario) AND fiId <> p_fiId) THEN
      ROLLBACK;
      SELECT 409 AS fiCodigo, 'Ya existe un usuario con ese nombre' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
    UPDATE usuario SET
      fcUsuario = TRIM(p_fcUsuario),
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

CREATE PROCEDURE sp_seguridad_usuario_activar(IN p_fiId INT, IN p_fbActivo TINYINT, IN p_fiUsuarioId INT)
proc: BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; SELECT 500 AS fiCodigo, 'Ocurrió un error al actualizar el usuario' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM usuario WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'El usuario no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  START TRANSACTION;
  UPDATE usuario SET fbActivo = IF(IFNULL(p_fbActivo,0)=1,1,0), fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId WHERE fiId = p_fiId;
  COMMIT;
  SELECT 200 AS fiCodigo,
         IF(IFNULL(p_fbActivo,0)=1,'Usuario activado correctamente','Usuario desactivado correctamente') AS fcMensaje,
         1 AS fbSucces, JSON_OBJECT('usuario', p_fiId) AS fjData;
END$$

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
         u.fiSucursalId, u.fbEsLocal, u.fcClaveHash, u.fbDebeCambiarClave, u.fbActivo, u.fdUltimoAcceso
  FROM usuario u
  INNER JOIN rol r ON r.fiId = u.fiRolId
  WHERE u.fiId = v_id;
END$$

DELIMITER ;
