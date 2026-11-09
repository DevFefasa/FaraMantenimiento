-- 18_sp_catalogo_parametro.sql
-- Callers: docker exec MariaLocal; CatalogoRepositorio (futuro)
-- API: sp_catalogo_parametro_listar, sp_catalogo_parametro_obtener, sp_catalogo_parametro_guardar, sp_catalogo_parametro_activar
-- Schema: parametro(fiId, fcClave UNIQUE, fcValor, fcDescripcion, fbActivo)
-- User instruction: "sp_catalogo_parametro_listar/guardar"
-- Aplicar: docker exec -i MariaLocal sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" faramantenimiento' < db/migrations/18_sp_catalogo_parametro.sql

SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_catalogo_parametro_listar;
DROP PROCEDURE IF EXISTS sp_catalogo_parametro_obtener;
DROP PROCEDURE IF EXISTS sp_catalogo_parametro_guardar;
DROP PROCEDURE IF EXISTS sp_catalogo_parametro_activar;

DELIMITER $$

CREATE PROCEDURE sp_catalogo_parametro_listar(IN p_fbSoloActivos TINYINT)
BEGIN
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;
  SELECT p.fiId, p.fcClave, p.fcValor, p.fcDescripcion, p.fbActivo, p.fdCreado, p.fdModificado
  FROM parametro p
  WHERE (IFNULL(p_fbSoloActivos, 1) = 0 OR p.fbActivo = 1)
  ORDER BY p.fcClave;
END$$

CREATE PROCEDURE sp_catalogo_parametro_obtener(IN p_fiId INT)
proc: BEGIN
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM parametro WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'El parámetro no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('parametro', p_fiId) AS fjData;
  SELECT p.fiId, p.fcClave, p.fcValor, p.fcDescripcion, p.fbActivo,
         p.fdCreado, p.fiCreadoPor, p.fdModificado, p.fiModificadoPor
  FROM parametro p
  WHERE p.fiId = p_fiId;
END$$

CREATE PROCEDURE sp_catalogo_parametro_guardar(
  IN p_fiId INT,
  IN p_fcClave VARCHAR(50),
  IN p_fcValor VARCHAR(250),
  IN p_fcDescripcion VARCHAR(250),
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_id INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al guardar el parámetro' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  IF TRIM(IFNULL(p_fcClave, '')) = '' THEN
    SELECT 400 AS fiCodigo, 'La clave es obligatoria' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;
  IF TRIM(IFNULL(p_fcValor, '')) = '' THEN
    SELECT 400 AS fiCodigo, 'El valor es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  START TRANSACTION;
  IF p_fiId IS NULL OR p_fiId <= 0 THEN
    IF EXISTS (SELECT 1 FROM parametro WHERE fcClave = p_fcClave) THEN
      ROLLBACK;
      SELECT 409 AS fiCodigo, 'Ya existe un parámetro con esa clave' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
    INSERT INTO parametro (fcClave, fcValor, fcDescripcion, fiCreadoPor, fbActivo)
    VALUES (TRIM(p_fcClave), TRIM(p_fcValor), NULLIF(TRIM(p_fcDescripcion), ''), p_fiUsuarioId, 1);
    SET v_id = LAST_INSERT_ID();
    COMMIT;
    SELECT 201 AS fiCodigo, 'Parámetro creado correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('parametro', v_id) AS fjData;
  ELSE
    IF NOT EXISTS (SELECT 1 FROM parametro WHERE fiId = p_fiId) THEN
      ROLLBACK;
      SELECT 404 AS fiCodigo, 'El parámetro no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
    IF EXISTS (SELECT 1 FROM parametro WHERE fcClave = p_fcClave AND fiId <> p_fiId) THEN
      ROLLBACK;
      SELECT 409 AS fiCodigo, 'Ya existe un parámetro con esa clave' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
    UPDATE parametro
    SET fcClave = TRIM(p_fcClave),
        fcValor = TRIM(p_fcValor),
        fcDescripcion = NULLIF(TRIM(p_fcDescripcion), ''),
        fdModificado = NOW(),
        fiModificadoPor = p_fiUsuarioId
    WHERE fiId = p_fiId;
    SET v_id = p_fiId;
    COMMIT;
    SELECT 200 AS fiCodigo, 'Parámetro guardado correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('parametro', v_id) AS fjData;
  END IF;
END$$

CREATE PROCEDURE sp_catalogo_parametro_activar(
  IN p_fiId INT,
  IN p_fbActivo TINYINT,
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al actualizar el parámetro' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM parametro WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'El parámetro no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  START TRANSACTION;
  UPDATE parametro
  SET fbActivo = IF(IFNULL(p_fbActivo, 0) = 1, 1, 0),
      fdModificado = NOW(),
      fiModificadoPor = p_fiUsuarioId
  WHERE fiId = p_fiId;
  COMMIT;
  SELECT 200 AS fiCodigo,
         IF(IFNULL(p_fbActivo, 0) = 1, 'Parámetro activado correctamente', 'Parámetro desactivado correctamente') AS fcMensaje,
         1 AS fbSucces,
         JSON_OBJECT('parametro', p_fiId) AS fjData;
END$$

DELIMITER ;
