-- 98_usuario_jefe_tecnico.sql
-- Callers: applied via docker exec; used by SeguridadRepositorio + CatalogoRepositorio (SPs)
-- API: sp_seguridad_usuario_listar/obtener/guardar; sp_catalogo_tecnico_listar/obtener/guardar
-- Schema: usuario.fiJefeId INT NULL; SELECT fcJefeNombre; tecnico.fcUsuarioNombre; 409 vínculo único
-- Confirm: Glob 98*.sql = 0
-- User instruction: "Migración 98_usuario_jefe_tecnico.sql (idempotente): usuario.fiJefeId INT NULL con FK a usuario(fiId) e índice (usa ADD COLUMN IF NOT EXISTS..."

SET NAMES utf8mb4;

ALTER TABLE usuario ADD COLUMN IF NOT EXISTS fiJefeId INT NULL COMMENT 'Jefe inmediato (usuario)' AFTER fiDepartamentoId;

SET @ix := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'usuario' AND INDEX_NAME = 'ix_usuario_jefe'
);
SET @sql := IF(@ix = 0, 'ALTER TABLE usuario ADD KEY ix_usuario_jefe (fiJefeId)', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @fk := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'usuario' AND CONSTRAINT_NAME = 'fk_usuario_jefe'
);
SET @sql := IF(@fk = 0,
  'ALTER TABLE usuario ADD CONSTRAINT fk_usuario_jefe FOREIGN KEY (fiJefeId) REFERENCES usuario (fiId)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

DROP PROCEDURE IF EXISTS sp_seguridad_usuario_listar;
DROP PROCEDURE IF EXISTS sp_seguridad_usuario_obtener;
DROP PROCEDURE IF EXISTS sp_seguridad_usuario_guardar;

DELIMITER $$

CREATE PROCEDURE sp_seguridad_usuario_listar(IN p_fbSoloActivos TINYINT)
BEGIN
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;
  SELECT u.fiId, u.fcUsuario, u.fcActiveDirectory, u.fcNombre, u.fcCargo, u.fcCorreo, u.fcTelefono,
         u.fiRolId, r.fcCodigo AS fcRolCodigo, r.fcNombre AS fcRolNombre,
         u.fiSucursalId, s.fcNombre AS fcSucursalNombre,
         u.fiAreaId, a.fcNombre AS fcAreaNombre,
         u.fiDepartamentoId, d.fcNombre AS fcDepartamentoNombre,
         u.fiJefeId, j.fcNombre AS fcJefeNombre,
         u.fbEsLocal, u.fbDebeCambiarClave, u.fbActivo, u.fdUltimoAcceso, u.fdCreado, u.fdModificado,
         CASE WHEN u.fcClaveHash IS NULL OR u.fcClaveHash = '' THEN 0 ELSE 1 END AS fbTieneClave
  FROM usuario u
  INNER JOIN rol r ON r.fiId = u.fiRolId
  LEFT JOIN sucursal s ON s.fiId = u.fiSucursalId
  LEFT JOIN area a ON a.fiId = u.fiAreaId
  LEFT JOIN departamento d ON d.fiId = u.fiDepartamentoId
  LEFT JOIN usuario j ON j.fiId = u.fiJefeId
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
         u.fiSucursalId, s.fcNombre AS fcSucursalNombre,
         u.fiAreaId, a.fcNombre AS fcAreaNombre,
         u.fiDepartamentoId, d.fcNombre AS fcDepartamentoNombre,
         u.fiJefeId, j.fcNombre AS fcJefeNombre,
         u.fbEsLocal, u.fbDebeCambiarClave, u.fbActivo, u.fdUltimoAcceso,
         u.fdCreado, u.fiCreadoPor, u.fdModificado, u.fiModificadoPor,
         CASE WHEN u.fcClaveHash IS NULL OR u.fcClaveHash = '' THEN 0 ELSE 1 END AS fbTieneClave
  FROM usuario u
  INNER JOIN rol r ON r.fiId = u.fiRolId
  LEFT JOIN sucursal s ON s.fiId = u.fiSucursalId
  LEFT JOIN area a ON a.fiId = u.fiAreaId
  LEFT JOIN departamento d ON d.fiId = u.fiDepartamentoId
  LEFT JOIN usuario j ON j.fiId = u.fiJefeId
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
  IN p_fiAreaId INT,
  IN p_fiDepartamentoId INT,
  IN p_fiJefeId INT,
  IN p_fbEsLocal TINYINT,
  IN p_fcClaveHash VARCHAR(128),
  IN p_fbDebeCambiarClave TINYINT,
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_id INT;
  DECLARE v_ad VARCHAR(100);
  DECLARE v_otroUsuario VARCHAR(100);
  DECLARE v_suc INT;
  DECLARE v_area INT;
  DECLARE v_depto INT;
  DECLARE v_jefe INT;
  DECLARE v_esSub INT DEFAULT 0;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al guardar el usuario' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  SET v_ad = NULLIF(TRIM(IFNULL(p_fcActiveDirectory,'')), '');
  SET v_suc = IF(p_fiSucursalId IS NULL OR p_fiSucursalId <= 0, NULL, p_fiSucursalId);
  SET v_area = IF(p_fiAreaId IS NULL OR p_fiAreaId <= 0, NULL, p_fiAreaId);
  SET v_depto = IF(p_fiDepartamentoId IS NULL OR p_fiDepartamentoId <= 0, NULL, p_fiDepartamentoId);
  SET v_jefe = IF(p_fiJefeId IS NULL OR p_fiJefeId <= 0, NULL, p_fiJefeId);

  IF TRIM(IFNULL(p_fcUsuario,'')) = '' THEN
    SELECT 400 AS fiCodigo, 'El usuario es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF TRIM(IFNULL(p_fcNombre,'')) = '' THEN
    SELECT 400 AS fiCodigo, 'El nombre es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF p_fiRolId IS NULL OR p_fiRolId <= 0 OR NOT EXISTS (SELECT 1 FROM rol WHERE fiId = p_fiRolId AND fbActivo = 1) THEN
    SELECT 400 AS fiCodigo, 'El rol no es válido' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF v_suc IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sucursal WHERE fiId = v_suc AND fbActivo = 1) THEN
    SELECT 400 AS fiCodigo, 'La sucursal no es válida' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF v_area IS NOT NULL AND NOT EXISTS (SELECT 1 FROM area WHERE fiId = v_area AND fbActivo = 1) THEN
    SELECT 400 AS fiCodigo, 'El área no es válida' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF v_depto IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM departamento WHERE fiId = v_depto AND fbActivo = 1) THEN
      SELECT 400 AS fiCodigo, 'El departamento no es válido' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    IF v_area IS NULL OR NOT EXISTS (SELECT 1 FROM departamento WHERE fiId = v_depto AND fiAreaId = v_area) THEN
      SELECT 400 AS fiCodigo, 'El departamento no pertenece al área seleccionada' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
  END IF;

  IF v_jefe IS NOT NULL THEN
    IF p_fiId IS NOT NULL AND p_fiId > 0 AND v_jefe = p_fiId THEN
      SELECT 400 AS fiCodigo, 'El jefe inmediato no puede ser el mismo usuario' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM usuario WHERE fiId = v_jefe AND fbActivo = 1) THEN
      SELECT 400 AS fiCodigo, 'El jefe inmediato no es válido o está inactivo' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    IF p_fiId IS NOT NULL AND p_fiId > 0 THEN
      WITH RECURSIVE subordinados AS (
        SELECT fiId FROM usuario WHERE fiJefeId = p_fiId
        UNION ALL
        SELECT u.fiId FROM usuario u INNER JOIN subordinados s ON u.fiJefeId = s.fiId
      )
      SELECT COUNT(*) INTO v_esSub FROM subordinados WHERE fiId = v_jefe;
      IF IFNULL(v_esSub, 0) > 0 THEN
        SELECT 400 AS fiCodigo, 'El jefe inmediato no puede ser un subordinado' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
      END IF;
    END IF;
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
    INSERT INTO usuario (fcUsuario, fcActiveDirectory, fcNombre, fcCargo, fcCorreo, fcTelefono, fiRolId, fiSucursalId, fiAreaId, fiDepartamentoId, fiJefeId, fbEsLocal, fcClaveHash, fbDebeCambiarClave, fiCreadoPor, fbActivo)
    VALUES (
      TRIM(p_fcUsuario), v_ad, TRIM(p_fcNombre), NULLIF(TRIM(p_fcCargo),''), NULLIF(TRIM(p_fcCorreo),''), NULLIF(TRIM(p_fcTelefono),''),
      p_fiRolId, v_suc, v_area, v_depto, v_jefe,
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
      fiSucursalId = v_suc,
      fiAreaId = v_area,
      fiDepartamentoId = v_depto,
      fiJefeId = v_jefe,
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

DROP PROCEDURE IF EXISTS sp_catalogo_tecnico_listar$$
DROP PROCEDURE IF EXISTS sp_catalogo_tecnico_obtener$$
DROP PROCEDURE IF EXISTS sp_catalogo_tecnico_guardar$$

CREATE PROCEDURE sp_catalogo_tecnico_listar(IN p_fbSoloActivos TINYINT, IN p_fiCategoriaId INT)
BEGIN
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;
  SELECT t.fiId, t.fcCodigo, t.fcNombre, t.fiUsuarioId, u.fcNombre AS fcUsuarioNombre,
         t.fcTelefono, t.fiCategoriaId, c.fcNombre AS fcCategoriaNombre,
         t.fbActivo, t.fdCreado, t.fdModificado
  FROM tecnico t
  LEFT JOIN categoria c ON c.fiId = t.fiCategoriaId
  LEFT JOIN usuario u ON u.fiId = t.fiUsuarioId
  WHERE (IFNULL(p_fbSoloActivos, 1) = 0 OR t.fbActivo = 1)
    AND (p_fiCategoriaId IS NULL OR p_fiCategoriaId <= 0 OR t.fiCategoriaId = p_fiCategoriaId)
  ORDER BY t.fcNombre;
END$$

CREATE PROCEDURE sp_catalogo_tecnico_obtener(IN p_fiId INT)
proc: BEGIN
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM tecnico WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'El técnico no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('tecnico', p_fiId) AS fjData;
  SELECT t.fiId, t.fcCodigo, t.fcNombre, t.fiUsuarioId, u.fcNombre AS fcUsuarioNombre,
         t.fcTelefono, t.fiCategoriaId, c.fcNombre AS fcCategoriaNombre,
         t.fbActivo, t.fdCreado, t.fiCreadoPor, t.fdModificado, t.fiModificadoPor
  FROM tecnico t
  LEFT JOIN categoria c ON c.fiId = t.fiCategoriaId
  LEFT JOIN usuario u ON u.fiId = t.fiUsuarioId
  WHERE t.fiId = p_fiId;
END$$

CREATE PROCEDURE sp_catalogo_tecnico_guardar(
  IN p_fiId INT, IN p_fcCodigo VARCHAR(30), IN p_fcNombre VARCHAR(150),
  IN p_fiUsuarioIdRef INT, IN p_fcTelefono VARCHAR(40), IN p_fiCategoriaId INT, IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_id INT;
  DECLARE v_usr INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; SELECT 500 AS fiCodigo, 'Ocurrió un error al guardar el técnico' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;
  SET v_usr = IF(p_fiUsuarioIdRef IS NULL OR p_fiUsuarioIdRef <= 0, NULL, p_fiUsuarioIdRef);
  IF TRIM(IFNULL(p_fcCodigo,'')) = '' THEN SELECT 400 AS fiCodigo, 'El código es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc; END IF;
  IF TRIM(IFNULL(p_fcNombre,'')) = '' THEN SELECT 400 AS fiCodigo, 'El nombre es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc; END IF;
  IF p_fiCategoriaId IS NOT NULL AND p_fiCategoriaId > 0 THEN
    IF NOT EXISTS (SELECT 1 FROM categoria WHERE fiId = p_fiCategoriaId AND fbActivo = 1) THEN
      SELECT 400 AS fiCodigo, 'La categoría no es válida' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
  END IF;
  IF v_usr IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM usuario WHERE fiId = v_usr AND fbActivo = 1) THEN
      SELECT 400 AS fiCodigo, 'El usuario del sistema no es válido o está inactivo' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    IF EXISTS (
      SELECT 1 FROM tecnico
      WHERE fiUsuarioId = v_usr AND fbActivo = 1
        AND (p_fiId IS NULL OR p_fiId <= 0 OR fiId <> p_fiId)
    ) THEN
      SELECT 409 AS fiCodigo, 'Ese usuario ya está ligado a otro técnico activo' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
  END IF;
  START TRANSACTION;
  IF p_fiId IS NULL OR p_fiId <= 0 THEN
    IF EXISTS (SELECT 1 FROM tecnico WHERE fcCodigo = p_fcCodigo) THEN
      ROLLBACK; SELECT 409 AS fiCodigo, 'Ya existe un técnico con ese código' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    INSERT INTO tecnico (fcCodigo, fcNombre, fiUsuarioId, fcTelefono, fiCategoriaId, fiCreadoPor, fbActivo)
    VALUES (
      TRIM(p_fcCodigo), TRIM(p_fcNombre), v_usr,
      NULLIF(TRIM(p_fcTelefono),''),
      IF(p_fiCategoriaId IS NULL OR p_fiCategoriaId <= 0, NULL, p_fiCategoriaId),
      p_fiUsuarioId, 1
    );
    SET v_id = LAST_INSERT_ID(); COMMIT;
    SELECT 201 AS fiCodigo, 'Técnico creado correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('tecnico', v_id) AS fjData;
  ELSE
    IF NOT EXISTS (SELECT 1 FROM tecnico WHERE fiId = p_fiId) THEN
      ROLLBACK; SELECT 404 AS fiCodigo, 'El técnico no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    IF EXISTS (SELECT 1 FROM tecnico WHERE fcCodigo = p_fcCodigo AND fiId <> p_fiId) THEN
      ROLLBACK; SELECT 409 AS fiCodigo, 'Ya existe un técnico con ese código' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    UPDATE tecnico SET fcCodigo = TRIM(p_fcCodigo), fcNombre = TRIM(p_fcNombre),
      fiUsuarioId = v_usr,
      fcTelefono = NULLIF(TRIM(p_fcTelefono),''),
      fiCategoriaId = IF(p_fiCategoriaId IS NULL OR p_fiCategoriaId <= 0, NULL, p_fiCategoriaId),
      fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId
    WHERE fiId = p_fiId;
    SET v_id = p_fiId; COMMIT;
    SELECT 200 AS fiCodigo, 'Técnico guardado correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('tecnico', v_id) AS fjData;
  END IF;
END$$

DELIMITER ;
