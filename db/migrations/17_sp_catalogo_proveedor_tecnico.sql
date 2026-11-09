-- 17_sp_catalogo_proveedor_tecnico.sql
-- Callers: docker exec MariaLocal; CatalogoRepositorio (futuro)
-- API: sp_catalogo_proveedor_*, sp_catalogo_tecnico_*
-- Schema: proveedor(fcNombre,fcRtn,fcContacto,fcTelefono,fcCorreo,fcEspecialidad); tecnico(fcNombre,fiUsuarioId NULL sin FK,fcTelefono,fiCategoriaId)
-- User instruction: "SP de catalogos con respuesta estandar... listar, obtener, guardar, activar/desactivar"
-- Aplicar: docker exec -i MariaLocal sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" faramantenimiento' < db/migrations/17_sp_catalogo_proveedor_tecnico.sql

SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_catalogo_proveedor_listar;
DROP PROCEDURE IF EXISTS sp_catalogo_proveedor_obtener;
DROP PROCEDURE IF EXISTS sp_catalogo_proveedor_guardar;
DROP PROCEDURE IF EXISTS sp_catalogo_proveedor_activar;
DROP PROCEDURE IF EXISTS sp_catalogo_tecnico_listar;
DROP PROCEDURE IF EXISTS sp_catalogo_tecnico_obtener;
DROP PROCEDURE IF EXISTS sp_catalogo_tecnico_guardar;
DROP PROCEDURE IF EXISTS sp_catalogo_tecnico_activar;

DELIMITER $$

CREATE PROCEDURE sp_catalogo_proveedor_listar(IN p_fbSoloActivos TINYINT)
BEGIN
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;
  SELECT p.fiId, p.fcCodigo, p.fcNombre, p.fcRtn, p.fcContacto, p.fcTelefono, p.fcCorreo, p.fcEspecialidad,
         p.fbActivo, p.fdCreado, p.fdModificado
  FROM proveedor p
  WHERE (IFNULL(p_fbSoloActivos, 1) = 0 OR p.fbActivo = 1)
  ORDER BY p.fcNombre;
END$$

CREATE PROCEDURE sp_catalogo_proveedor_obtener(IN p_fiId INT)
proc: BEGIN
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM proveedor WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'El proveedor no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('proveedor', p_fiId) AS fjData;
  SELECT p.fiId, p.fcCodigo, p.fcNombre, p.fcRtn, p.fcContacto, p.fcTelefono, p.fcCorreo, p.fcEspecialidad,
         p.fbActivo, p.fdCreado, p.fiCreadoPor, p.fdModificado, p.fiModificadoPor
  FROM proveedor p WHERE p.fiId = p_fiId;
END$$

CREATE PROCEDURE sp_catalogo_proveedor_guardar(
  IN p_fiId INT, IN p_fcCodigo VARCHAR(30), IN p_fcNombre VARCHAR(150), IN p_fcRtn VARCHAR(30),
  IN p_fcContacto VARCHAR(150), IN p_fcTelefono VARCHAR(40), IN p_fcCorreo VARCHAR(150),
  IN p_fcEspecialidad VARCHAR(150), IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_id INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; SELECT 500 AS fiCodigo, 'Ocurrió un error al guardar el proveedor' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;
  IF TRIM(IFNULL(p_fcCodigo,'')) = '' THEN SELECT 400 AS fiCodigo, 'El código es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc; END IF;
  IF TRIM(IFNULL(p_fcNombre,'')) = '' THEN SELECT 400 AS fiCodigo, 'El nombre es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc; END IF;
  START TRANSACTION;
  IF p_fiId IS NULL OR p_fiId <= 0 THEN
    IF EXISTS (SELECT 1 FROM proveedor WHERE fcCodigo = p_fcCodigo) THEN
      ROLLBACK; SELECT 409 AS fiCodigo, 'Ya existe un proveedor con ese código' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    INSERT INTO proveedor (fcCodigo, fcNombre, fcRtn, fcContacto, fcTelefono, fcCorreo, fcEspecialidad, fiCreadoPor, fbActivo)
    VALUES (TRIM(p_fcCodigo), TRIM(p_fcNombre), NULLIF(TRIM(p_fcRtn),''), NULLIF(TRIM(p_fcContacto),''),
            NULLIF(TRIM(p_fcTelefono),''), NULLIF(TRIM(p_fcCorreo),''), NULLIF(TRIM(p_fcEspecialidad),''), p_fiUsuarioId, 1);
    SET v_id = LAST_INSERT_ID(); COMMIT;
    SELECT 201 AS fiCodigo, 'Proveedor creado correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('proveedor', v_id) AS fjData;
  ELSE
    IF NOT EXISTS (SELECT 1 FROM proveedor WHERE fiId = p_fiId) THEN
      ROLLBACK; SELECT 404 AS fiCodigo, 'El proveedor no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    IF EXISTS (SELECT 1 FROM proveedor WHERE fcCodigo = p_fcCodigo AND fiId <> p_fiId) THEN
      ROLLBACK; SELECT 409 AS fiCodigo, 'Ya existe un proveedor con ese código' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    UPDATE proveedor SET fcCodigo = TRIM(p_fcCodigo), fcNombre = TRIM(p_fcNombre),
      fcRtn = NULLIF(TRIM(p_fcRtn),''), fcContacto = NULLIF(TRIM(p_fcContacto),''),
      fcTelefono = NULLIF(TRIM(p_fcTelefono),''), fcCorreo = NULLIF(TRIM(p_fcCorreo),''),
      fcEspecialidad = NULLIF(TRIM(p_fcEspecialidad),''), fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId
    WHERE fiId = p_fiId;
    SET v_id = p_fiId; COMMIT;
    SELECT 200 AS fiCodigo, 'Proveedor guardado correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('proveedor', v_id) AS fjData;
  END IF;
END$$

CREATE PROCEDURE sp_catalogo_proveedor_activar(IN p_fiId INT, IN p_fbActivo TINYINT, IN p_fiUsuarioId INT)
proc: BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; SELECT 500 AS fiCodigo, 'Ocurrió un error al actualizar el proveedor' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM proveedor WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'El proveedor no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  START TRANSACTION;
  UPDATE proveedor SET fbActivo = IF(IFNULL(p_fbActivo,0)=1,1,0), fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId WHERE fiId = p_fiId;
  COMMIT;
  SELECT 200 AS fiCodigo, IF(IFNULL(p_fbActivo,0)=1,'Proveedor activado correctamente','Proveedor desactivado correctamente') AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('proveedor', p_fiId) AS fjData;
END$$

CREATE PROCEDURE sp_catalogo_tecnico_listar(IN p_fbSoloActivos TINYINT, IN p_fiCategoriaId INT)
BEGIN
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;
  SELECT t.fiId, t.fcCodigo, t.fcNombre, t.fiUsuarioId, t.fcTelefono, t.fiCategoriaId,
         c.fcNombre AS fcCategoriaNombre, t.fbActivo, t.fdCreado, t.fdModificado
  FROM tecnico t
  LEFT JOIN categoria c ON c.fiId = t.fiCategoriaId
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
  SELECT t.fiId, t.fcCodigo, t.fcNombre, t.fiUsuarioId, t.fcTelefono, t.fiCategoriaId,
         c.fcNombre AS fcCategoriaNombre, t.fbActivo, t.fdCreado, t.fiCreadoPor, t.fdModificado, t.fiModificadoPor
  FROM tecnico t
  LEFT JOIN categoria c ON c.fiId = t.fiCategoriaId
  WHERE t.fiId = p_fiId;
END$$

CREATE PROCEDURE sp_catalogo_tecnico_guardar(
  IN p_fiId INT, IN p_fcCodigo VARCHAR(30), IN p_fcNombre VARCHAR(150),
  IN p_fiUsuarioIdRef INT, IN p_fcTelefono VARCHAR(40), IN p_fiCategoriaId INT, IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_id INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; SELECT 500 AS fiCodigo, 'Ocurrió un error al guardar el técnico' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;
  IF TRIM(IFNULL(p_fcCodigo,'')) = '' THEN SELECT 400 AS fiCodigo, 'El código es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc; END IF;
  IF TRIM(IFNULL(p_fcNombre,'')) = '' THEN SELECT 400 AS fiCodigo, 'El nombre es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc; END IF;
  IF p_fiCategoriaId IS NOT NULL AND p_fiCategoriaId > 0 THEN
    IF NOT EXISTS (SELECT 1 FROM categoria WHERE fiId = p_fiCategoriaId AND fbActivo = 1) THEN
      SELECT 400 AS fiCodigo, 'La categoría no es válida' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
  END IF;
  START TRANSACTION;
  IF p_fiId IS NULL OR p_fiId <= 0 THEN
    IF EXISTS (SELECT 1 FROM tecnico WHERE fcCodigo = p_fcCodigo) THEN
      ROLLBACK; SELECT 409 AS fiCodigo, 'Ya existe un técnico con ese código' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    INSERT INTO tecnico (fcCodigo, fcNombre, fiUsuarioId, fcTelefono, fiCategoriaId, fiCreadoPor, fbActivo)
    VALUES (
      TRIM(p_fcCodigo), TRIM(p_fcNombre),
      IF(p_fiUsuarioIdRef IS NULL OR p_fiUsuarioIdRef <= 0, NULL, p_fiUsuarioIdRef),
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
      fiUsuarioId = IF(p_fiUsuarioIdRef IS NULL OR p_fiUsuarioIdRef <= 0, NULL, p_fiUsuarioIdRef),
      fcTelefono = NULLIF(TRIM(p_fcTelefono),''),
      fiCategoriaId = IF(p_fiCategoriaId IS NULL OR p_fiCategoriaId <= 0, NULL, p_fiCategoriaId),
      fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId
    WHERE fiId = p_fiId;
    SET v_id = p_fiId; COMMIT;
    SELECT 200 AS fiCodigo, 'Técnico guardado correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('tecnico', v_id) AS fjData;
  END IF;
END$$

CREATE PROCEDURE sp_catalogo_tecnico_activar(IN p_fiId INT, IN p_fbActivo TINYINT, IN p_fiUsuarioId INT)
proc: BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; SELECT 500 AS fiCodigo, 'Ocurrió un error al actualizar el técnico' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM tecnico WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'El técnico no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  START TRANSACTION;
  UPDATE tecnico SET fbActivo = IF(IFNULL(p_fbActivo,0)=1,1,0), fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId WHERE fiId = p_fiId;
  COMMIT;
  SELECT 200 AS fiCodigo, IF(IFNULL(p_fbActivo,0)=1,'Técnico activado correctamente','Técnico desactivado correctamente') AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('tecnico', p_fiId) AS fjData;
END$$

DELIMITER ;
