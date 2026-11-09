-- 15_sp_catalogo_tipo_categoria_prioridad.sql
-- Callers: docker exec MariaLocal; CatalogoRepositorio (futuro)
-- API: sp_catalogo_tipomantenimiento_*, sp_catalogo_categoria_*, sp_catalogo_prioridad_*
-- Schema: tipomantenimiento, categoria, prioridad (fc/fi/fb/fd)
-- User instruction: "SP de catalogos con respuesta estandar... listar, obtener, guardar, activar/desactivar"
-- Aplicar: docker exec -i MariaLocal sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" faramantenimiento' < db/migrations/15_sp_catalogo_tipo_categoria_prioridad.sql

SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_catalogo_tipomantenimiento_listar;
DROP PROCEDURE IF EXISTS sp_catalogo_tipomantenimiento_obtener;
DROP PROCEDURE IF EXISTS sp_catalogo_tipomantenimiento_guardar;
DROP PROCEDURE IF EXISTS sp_catalogo_tipomantenimiento_activar;
DROP PROCEDURE IF EXISTS sp_catalogo_categoria_listar;
DROP PROCEDURE IF EXISTS sp_catalogo_categoria_obtener;
DROP PROCEDURE IF EXISTS sp_catalogo_categoria_guardar;
DROP PROCEDURE IF EXISTS sp_catalogo_categoria_activar;
DROP PROCEDURE IF EXISTS sp_catalogo_prioridad_listar;
DROP PROCEDURE IF EXISTS sp_catalogo_prioridad_obtener;
DROP PROCEDURE IF EXISTS sp_catalogo_prioridad_guardar;
DROP PROCEDURE IF EXISTS sp_catalogo_prioridad_activar;

DELIMITER $$

CREATE PROCEDURE sp_catalogo_tipomantenimiento_listar(IN p_fbSoloActivos TINYINT)
BEGIN
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;
  SELECT t.fiId, t.fcCodigo, t.fcNombre, t.fbRequiereAprobacion, t.fbEsPreventivo, t.fbEsPostFalla,
         t.fbRequiereFechaSugerida, t.fiOrden, t.fbActivo, t.fdCreado, t.fdModificado
  FROM tipomantenimiento t
  WHERE (IFNULL(p_fbSoloActivos, 1) = 0 OR t.fbActivo = 1)
  ORDER BY t.fiOrden, t.fcNombre;
END$$

CREATE PROCEDURE sp_catalogo_tipomantenimiento_obtener(IN p_fiId INT)
proc: BEGIN
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM tipomantenimiento WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'El tipo de mantenimiento no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('tipomantenimiento', p_fiId) AS fjData;
  SELECT t.fiId, t.fcCodigo, t.fcNombre, t.fbRequiereAprobacion, t.fbEsPreventivo, t.fbEsPostFalla,
         t.fbRequiereFechaSugerida, t.fiOrden, t.fbActivo, t.fdCreado, t.fiCreadoPor, t.fdModificado, t.fiModificadoPor
  FROM tipomantenimiento t WHERE t.fiId = p_fiId;
END$$

CREATE PROCEDURE sp_catalogo_tipomantenimiento_guardar(
  IN p_fiId INT,
  IN p_fcCodigo VARCHAR(30),
  IN p_fcNombre VARCHAR(100),
  IN p_fbRequiereAprobacion TINYINT,
  IN p_fbEsPreventivo TINYINT,
  IN p_fbEsPostFalla TINYINT,
  IN p_fbRequiereFechaSugerida TINYINT,
  IN p_fiOrden INT,
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_id INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al guardar el tipo de mantenimiento' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;
  IF TRIM(IFNULL(p_fcCodigo, '')) = '' THEN
    SELECT 400 AS fiCodigo, 'El código es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF TRIM(IFNULL(p_fcNombre, '')) = '' THEN
    SELECT 400 AS fiCodigo, 'El nombre es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  START TRANSACTION;
  IF p_fiId IS NULL OR p_fiId <= 0 THEN
    IF EXISTS (SELECT 1 FROM tipomantenimiento WHERE fcCodigo = p_fcCodigo) THEN
      ROLLBACK; SELECT 409 AS fiCodigo, 'Ya existe un tipo con ese código' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    INSERT INTO tipomantenimiento (fcCodigo, fcNombre, fbRequiereAprobacion, fbEsPreventivo, fbEsPostFalla, fbRequiereFechaSugerida, fiOrden, fiCreadoPor, fbActivo)
    VALUES (TRIM(p_fcCodigo), TRIM(p_fcNombre), IF(IFNULL(p_fbRequiereAprobacion,0)=1,1,0), IF(IFNULL(p_fbEsPreventivo,0)=1,1,0),
            IF(IFNULL(p_fbEsPostFalla,0)=1,1,0), IF(IFNULL(p_fbRequiereFechaSugerida,0)=1,1,0), IFNULL(p_fiOrden,0), p_fiUsuarioId, 1);
    SET v_id = LAST_INSERT_ID();
    COMMIT;
    SELECT 201 AS fiCodigo, 'Tipo de mantenimiento creado correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('tipomantenimiento', v_id) AS fjData;
  ELSE
    IF NOT EXISTS (SELECT 1 FROM tipomantenimiento WHERE fiId = p_fiId) THEN
      ROLLBACK; SELECT 404 AS fiCodigo, 'El tipo de mantenimiento no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    IF EXISTS (SELECT 1 FROM tipomantenimiento WHERE fcCodigo = p_fcCodigo AND fiId <> p_fiId) THEN
      ROLLBACK; SELECT 409 AS fiCodigo, 'Ya existe un tipo con ese código' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    UPDATE tipomantenimiento SET
      fcCodigo = TRIM(p_fcCodigo), fcNombre = TRIM(p_fcNombre),
      fbRequiereAprobacion = IF(IFNULL(p_fbRequiereAprobacion,0)=1,1,0),
      fbEsPreventivo = IF(IFNULL(p_fbEsPreventivo,0)=1,1,0),
      fbEsPostFalla = IF(IFNULL(p_fbEsPostFalla,0)=1,1,0),
      fbRequiereFechaSugerida = IF(IFNULL(p_fbRequiereFechaSugerida,0)=1,1,0),
      fiOrden = IFNULL(p_fiOrden,0), fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId
    WHERE fiId = p_fiId;
    SET v_id = p_fiId; COMMIT;
    SELECT 200 AS fiCodigo, 'Tipo de mantenimiento guardado correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('tipomantenimiento', v_id) AS fjData;
  END IF;
END$$

CREATE PROCEDURE sp_catalogo_tipomantenimiento_activar(IN p_fiId INT, IN p_fbActivo TINYINT, IN p_fiUsuarioId INT)
proc: BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; SELECT 500 AS fiCodigo, 'Ocurrió un error al actualizar el tipo de mantenimiento' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM tipomantenimiento WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'El tipo de mantenimiento no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  START TRANSACTION;
  UPDATE tipomantenimiento SET fbActivo = IF(IFNULL(p_fbActivo,0)=1,1,0), fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId WHERE fiId = p_fiId;
  COMMIT;
  SELECT 200 AS fiCodigo, IF(IFNULL(p_fbActivo,0)=1,'Tipo activado correctamente','Tipo desactivado correctamente') AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('tipomantenimiento', p_fiId) AS fjData;
END$$

CREATE PROCEDURE sp_catalogo_categoria_listar(IN p_fbSoloActivos TINYINT)
BEGIN
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;
  SELECT c.fiId, c.fcCodigo, c.fcNombre, c.fiOrden, c.fbActivo, c.fdCreado, c.fdModificado
  FROM categoria c
  WHERE (IFNULL(p_fbSoloActivos, 1) = 0 OR c.fbActivo = 1)
  ORDER BY c.fiOrden, c.fcNombre;
END$$

CREATE PROCEDURE sp_catalogo_categoria_obtener(IN p_fiId INT)
proc: BEGIN
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM categoria WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'La categoría no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('categoria', p_fiId) AS fjData;
  SELECT c.fiId, c.fcCodigo, c.fcNombre, c.fiOrden, c.fbActivo, c.fdCreado, c.fiCreadoPor, c.fdModificado, c.fiModificadoPor
  FROM categoria c WHERE c.fiId = p_fiId;
END$$

CREATE PROCEDURE sp_catalogo_categoria_guardar(
  IN p_fiId INT, IN p_fcCodigo VARCHAR(30), IN p_fcNombre VARCHAR(150), IN p_fiOrden INT, IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_id INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; SELECT 500 AS fiCodigo, 'Ocurrió un error al guardar la categoría' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;
  IF TRIM(IFNULL(p_fcCodigo,'')) = '' THEN SELECT 400 AS fiCodigo, 'El código es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc; END IF;
  IF TRIM(IFNULL(p_fcNombre,'')) = '' THEN SELECT 400 AS fiCodigo, 'El nombre es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc; END IF;
  START TRANSACTION;
  IF p_fiId IS NULL OR p_fiId <= 0 THEN
    IF EXISTS (SELECT 1 FROM categoria WHERE fcCodigo = p_fcCodigo) THEN
      ROLLBACK; SELECT 409 AS fiCodigo, 'Ya existe una categoría con ese código' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    INSERT INTO categoria (fcCodigo, fcNombre, fiOrden, fiCreadoPor, fbActivo)
    VALUES (TRIM(p_fcCodigo), TRIM(p_fcNombre), IFNULL(p_fiOrden,0), p_fiUsuarioId, 1);
    SET v_id = LAST_INSERT_ID(); COMMIT;
    SELECT 201 AS fiCodigo, 'Categoría creada correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('categoria', v_id) AS fjData;
  ELSE
    IF NOT EXISTS (SELECT 1 FROM categoria WHERE fiId = p_fiId) THEN
      ROLLBACK; SELECT 404 AS fiCodigo, 'La categoría no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    IF EXISTS (SELECT 1 FROM categoria WHERE fcCodigo = p_fcCodigo AND fiId <> p_fiId) THEN
      ROLLBACK; SELECT 409 AS fiCodigo, 'Ya existe una categoría con ese código' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    UPDATE categoria SET fcCodigo = TRIM(p_fcCodigo), fcNombre = TRIM(p_fcNombre), fiOrden = IFNULL(p_fiOrden,0),
      fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId WHERE fiId = p_fiId;
    SET v_id = p_fiId; COMMIT;
    SELECT 200 AS fiCodigo, 'Categoría guardada correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('categoria', v_id) AS fjData;
  END IF;
END$$

CREATE PROCEDURE sp_catalogo_categoria_activar(IN p_fiId INT, IN p_fbActivo TINYINT, IN p_fiUsuarioId INT)
proc: BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; SELECT 500 AS fiCodigo, 'Ocurrió un error al actualizar la categoría' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM categoria WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'La categoría no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  START TRANSACTION;
  UPDATE categoria SET fbActivo = IF(IFNULL(p_fbActivo,0)=1,1,0), fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId WHERE fiId = p_fiId;
  COMMIT;
  SELECT 200 AS fiCodigo, IF(IFNULL(p_fbActivo,0)=1,'Categoría activada correctamente','Categoría desactivada correctamente') AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('categoria', p_fiId) AS fjData;
END$$

CREATE PROCEDURE sp_catalogo_prioridad_listar(IN p_fbSoloActivos TINYINT)
BEGIN
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;
  SELECT p.fiId, p.fcCodigo, p.fcNombre, p.fiHorasRespuesta, p.fiHorasSolucion, p.fcColor, p.fiOrden, p.fbActivo, p.fdCreado, p.fdModificado
  FROM prioridad p
  WHERE (IFNULL(p_fbSoloActivos, 1) = 0 OR p.fbActivo = 1)
  ORDER BY p.fiOrden, p.fcNombre;
END$$

CREATE PROCEDURE sp_catalogo_prioridad_obtener(IN p_fiId INT)
proc: BEGIN
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM prioridad WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'La prioridad no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('prioridad', p_fiId) AS fjData;
  SELECT p.fiId, p.fcCodigo, p.fcNombre, p.fiHorasRespuesta, p.fiHorasSolucion, p.fcColor, p.fiOrden, p.fbActivo,
         p.fdCreado, p.fiCreadoPor, p.fdModificado, p.fiModificadoPor
  FROM prioridad p WHERE p.fiId = p_fiId;
END$$

CREATE PROCEDURE sp_catalogo_prioridad_guardar(
  IN p_fiId INT, IN p_fcCodigo VARCHAR(30), IN p_fcNombre VARCHAR(50),
  IN p_fiHorasRespuesta INT, IN p_fiHorasSolucion INT, IN p_fcColor VARCHAR(20), IN p_fiOrden INT, IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_id INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; SELECT 500 AS fiCodigo, 'Ocurrió un error al guardar la prioridad' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;
  IF TRIM(IFNULL(p_fcCodigo,'')) = '' THEN SELECT 400 AS fiCodigo, 'El código es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc; END IF;
  IF TRIM(IFNULL(p_fcNombre,'')) = '' THEN SELECT 400 AS fiCodigo, 'El nombre es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc; END IF;
  IF p_fiHorasRespuesta IS NULL OR p_fiHorasRespuesta <= 0 OR p_fiHorasSolucion IS NULL OR p_fiHorasSolucion <= 0 THEN
    SELECT 400 AS fiCodigo, 'Las horas de respuesta y solución deben ser mayores a cero' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  START TRANSACTION;
  IF p_fiId IS NULL OR p_fiId <= 0 THEN
    IF EXISTS (SELECT 1 FROM prioridad WHERE fcCodigo = p_fcCodigo) THEN
      ROLLBACK; SELECT 409 AS fiCodigo, 'Ya existe una prioridad con ese código' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    INSERT INTO prioridad (fcCodigo, fcNombre, fiHorasRespuesta, fiHorasSolucion, fcColor, fiOrden, fiCreadoPor, fbActivo)
    VALUES (TRIM(p_fcCodigo), TRIM(p_fcNombre), p_fiHorasRespuesta, p_fiHorasSolucion, IFNULL(NULLIF(TRIM(p_fcColor),''),'#6c757d'), IFNULL(p_fiOrden,0), p_fiUsuarioId, 1);
    SET v_id = LAST_INSERT_ID(); COMMIT;
    SELECT 201 AS fiCodigo, 'Prioridad creada correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('prioridad', v_id) AS fjData;
  ELSE
    IF NOT EXISTS (SELECT 1 FROM prioridad WHERE fiId = p_fiId) THEN
      ROLLBACK; SELECT 404 AS fiCodigo, 'La prioridad no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    IF EXISTS (SELECT 1 FROM prioridad WHERE fcCodigo = p_fcCodigo AND fiId <> p_fiId) THEN
      ROLLBACK; SELECT 409 AS fiCodigo, 'Ya existe una prioridad con ese código' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    UPDATE prioridad SET fcCodigo = TRIM(p_fcCodigo), fcNombre = TRIM(p_fcNombre),
      fiHorasRespuesta = p_fiHorasRespuesta, fiHorasSolucion = p_fiHorasSolucion,
      fcColor = IFNULL(NULLIF(TRIM(p_fcColor),''),'#6c757d'), fiOrden = IFNULL(p_fiOrden,0),
      fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId WHERE fiId = p_fiId;
    SET v_id = p_fiId; COMMIT;
    SELECT 200 AS fiCodigo, 'Prioridad guardada correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('prioridad', v_id) AS fjData;
  END IF;
END$$

CREATE PROCEDURE sp_catalogo_prioridad_activar(IN p_fiId INT, IN p_fbActivo TINYINT, IN p_fiUsuarioId INT)
proc: BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; SELECT 500 AS fiCodigo, 'Ocurrió un error al actualizar la prioridad' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM prioridad WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'La prioridad no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  START TRANSACTION;
  UPDATE prioridad SET fbActivo = IF(IFNULL(p_fbActivo,0)=1,1,0), fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId WHERE fiId = p_fiId;
  COMMIT;
  SELECT 200 AS fiCodigo, IF(IFNULL(p_fbActivo,0)=1,'Prioridad activada correctamente','Prioridad desactivada correctamente') AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('prioridad', p_fiId) AS fjData;
END$$

DELIMITER ;
