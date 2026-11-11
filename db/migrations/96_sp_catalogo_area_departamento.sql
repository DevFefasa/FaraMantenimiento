-- 96_sp_catalogo_area_departamento.sql
-- Callers: CatalogoRepositorio.Area*/Departamento*; CatalogoServicio; CatalogosController
-- API: sp_catalogo_area_listar/obtener/guardar/activar; sp_catalogo_departamento_*
-- Schema: area(fiId,fcCodigo,fcNombre,fbActivo); departamento(+fiAreaId,fcAreaNombre en listar)
-- Confirm: Glob 96*.sql = 0; patrón 13_sp_catalogo_region_sucursal.sql
-- User instruction: "SP CRUD de área y departamento con respuesta estándar"

SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_catalogo_area_listar;
DROP PROCEDURE IF EXISTS sp_catalogo_area_obtener;
DROP PROCEDURE IF EXISTS sp_catalogo_area_guardar;
DROP PROCEDURE IF EXISTS sp_catalogo_area_activar;
DROP PROCEDURE IF EXISTS sp_catalogo_departamento_listar;
DROP PROCEDURE IF EXISTS sp_catalogo_departamento_obtener;
DROP PROCEDURE IF EXISTS sp_catalogo_departamento_guardar;
DROP PROCEDURE IF EXISTS sp_catalogo_departamento_activar;

DELIMITER $$

CREATE PROCEDURE sp_catalogo_area_listar(IN p_fbSoloActivos TINYINT)
BEGIN
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;
  SELECT a.fiId, a.fcCodigo, a.fcNombre, a.fbActivo, a.fdCreado, a.fdModificado
  FROM area a
  WHERE (IFNULL(p_fbSoloActivos, 1) = 0 OR a.fbActivo = 1)
  ORDER BY a.fcNombre;
END$$

CREATE PROCEDURE sp_catalogo_area_obtener(IN p_fiId INT)
proc: BEGIN
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM area WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'El área no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('area', p_fiId) AS fjData;
  SELECT a.fiId, a.fcCodigo, a.fcNombre, a.fbActivo, a.fdCreado, a.fiCreadoPor, a.fdModificado, a.fiModificadoPor
  FROM area a
  WHERE a.fiId = p_fiId;
END$$

CREATE PROCEDURE sp_catalogo_area_guardar(
  IN p_fiId INT,
  IN p_fcCodigo VARCHAR(30),
  IN p_fcNombre VARCHAR(100),
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_id INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al guardar el área' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  IF TRIM(IFNULL(p_fcCodigo, '')) = '' THEN
    SELECT 400 AS fiCodigo, 'El código es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;
  IF TRIM(IFNULL(p_fcNombre, '')) = '' THEN
    SELECT 400 AS fiCodigo, 'El nombre es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  START TRANSACTION;
  IF p_fiId IS NULL OR p_fiId <= 0 THEN
    IF EXISTS (SELECT 1 FROM area WHERE fcCodigo = p_fcCodigo) THEN
      ROLLBACK;
      SELECT 409 AS fiCodigo, 'Ya existe un área con ese código' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
    INSERT INTO area (fcCodigo, fcNombre, fiCreadoPor, fbActivo)
    VALUES (TRIM(p_fcCodigo), TRIM(p_fcNombre), p_fiUsuarioId, 1);
    SET v_id = LAST_INSERT_ID();
    COMMIT;
    SELECT 201 AS fiCodigo, 'Área creada correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('area', v_id) AS fjData;
  ELSE
    IF NOT EXISTS (SELECT 1 FROM area WHERE fiId = p_fiId) THEN
      ROLLBACK;
      SELECT 404 AS fiCodigo, 'El área no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
    IF EXISTS (SELECT 1 FROM area WHERE fcCodigo = p_fcCodigo AND fiId <> p_fiId) THEN
      ROLLBACK;
      SELECT 409 AS fiCodigo, 'Ya existe un área con ese código' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
    UPDATE area
    SET fcCodigo = TRIM(p_fcCodigo),
        fcNombre = TRIM(p_fcNombre),
        fdModificado = NOW(),
        fiModificadoPor = p_fiUsuarioId
    WHERE fiId = p_fiId;
    SET v_id = p_fiId;
    COMMIT;
    SELECT 200 AS fiCodigo, 'Área guardada correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('area', v_id) AS fjData;
  END IF;
END$$

CREATE PROCEDURE sp_catalogo_area_activar(
  IN p_fiId INT,
  IN p_fbActivo TINYINT,
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al actualizar el área' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM area WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'El área no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  START TRANSACTION;
  UPDATE area
  SET fbActivo = IF(IFNULL(p_fbActivo, 0) = 1, 1, 0),
      fdModificado = NOW(),
      fiModificadoPor = p_fiUsuarioId
  WHERE fiId = p_fiId;
  COMMIT;
  SELECT 200 AS fiCodigo,
         IF(IFNULL(p_fbActivo, 0) = 1, 'Área activada correctamente', 'Área desactivada correctamente') AS fcMensaje,
         1 AS fbSucces,
         JSON_OBJECT('area', p_fiId) AS fjData;
END$$

CREATE PROCEDURE sp_catalogo_departamento_listar(IN p_fbSoloActivos TINYINT, IN p_fiAreaId INT)
BEGIN
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;
  SELECT d.fiId, d.fcCodigo, d.fcNombre, d.fiAreaId, a.fcNombre AS fcAreaNombre,
         d.fbActivo, d.fdCreado, d.fdModificado
  FROM departamento d
  INNER JOIN area a ON a.fiId = d.fiAreaId
  WHERE (IFNULL(p_fbSoloActivos, 1) = 0 OR d.fbActivo = 1)
    AND (p_fiAreaId IS NULL OR p_fiAreaId <= 0 OR d.fiAreaId = p_fiAreaId)
  ORDER BY a.fcNombre, d.fcNombre;
END$$

CREATE PROCEDURE sp_catalogo_departamento_obtener(IN p_fiId INT)
proc: BEGIN
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM departamento WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'El departamento no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('departamento', p_fiId) AS fjData;
  SELECT d.fiId, d.fcCodigo, d.fcNombre, d.fiAreaId, a.fcNombre AS fcAreaNombre,
         d.fbActivo, d.fdCreado, d.fiCreadoPor, d.fdModificado, d.fiModificadoPor
  FROM departamento d
  INNER JOIN area a ON a.fiId = d.fiAreaId
  WHERE d.fiId = p_fiId;
END$$

CREATE PROCEDURE sp_catalogo_departamento_guardar(
  IN p_fiId INT,
  IN p_fcCodigo VARCHAR(30),
  IN p_fcNombre VARCHAR(100),
  IN p_fiAreaId INT,
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_id INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al guardar el departamento' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  IF TRIM(IFNULL(p_fcCodigo, '')) = '' THEN
    SELECT 400 AS fiCodigo, 'El código es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;
  IF TRIM(IFNULL(p_fcNombre, '')) = '' THEN
    SELECT 400 AS fiCodigo, 'El nombre es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;
  IF p_fiAreaId IS NULL OR p_fiAreaId <= 0 OR NOT EXISTS (SELECT 1 FROM area WHERE fiId = p_fiAreaId AND fbActivo = 1) THEN
    SELECT 400 AS fiCodigo, 'El área no es válida' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  START TRANSACTION;
  IF p_fiId IS NULL OR p_fiId <= 0 THEN
    IF EXISTS (SELECT 1 FROM departamento WHERE fcCodigo = p_fcCodigo) THEN
      ROLLBACK;
      SELECT 409 AS fiCodigo, 'Ya existe un departamento con ese código' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
    INSERT INTO departamento (fcCodigo, fcNombre, fiAreaId, fiCreadoPor, fbActivo)
    VALUES (TRIM(p_fcCodigo), TRIM(p_fcNombre), p_fiAreaId, p_fiUsuarioId, 1);
    SET v_id = LAST_INSERT_ID();
    COMMIT;
    SELECT 201 AS fiCodigo, 'Departamento creado correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('departamento', v_id) AS fjData;
  ELSE
    IF NOT EXISTS (SELECT 1 FROM departamento WHERE fiId = p_fiId) THEN
      ROLLBACK;
      SELECT 404 AS fiCodigo, 'El departamento no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
    IF EXISTS (SELECT 1 FROM departamento WHERE fcCodigo = p_fcCodigo AND fiId <> p_fiId) THEN
      ROLLBACK;
      SELECT 409 AS fiCodigo, 'Ya existe un departamento con ese código' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
    UPDATE departamento
    SET fcCodigo = TRIM(p_fcCodigo),
        fcNombre = TRIM(p_fcNombre),
        fiAreaId = p_fiAreaId,
        fdModificado = NOW(),
        fiModificadoPor = p_fiUsuarioId
    WHERE fiId = p_fiId;
    SET v_id = p_fiId;
    COMMIT;
    SELECT 200 AS fiCodigo, 'Departamento guardado correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('departamento', v_id) AS fjData;
  END IF;
END$$

CREATE PROCEDURE sp_catalogo_departamento_activar(
  IN p_fiId INT,
  IN p_fbActivo TINYINT,
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al actualizar el departamento' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM departamento WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'El departamento no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  START TRANSACTION;
  UPDATE departamento
  SET fbActivo = IF(IFNULL(p_fbActivo, 0) = 1, 1, 0),
      fdModificado = NOW(),
      fiModificadoPor = p_fiUsuarioId
  WHERE fiId = p_fiId;
  COMMIT;
  SELECT 200 AS fiCodigo,
         IF(IFNULL(p_fbActivo, 0) = 1, 'Departamento activado correctamente', 'Departamento desactivado correctamente') AS fcMensaje,
         1 AS fbSucces,
         JSON_OBJECT('departamento', p_fiId) AS fjData;
END$$

DELIMITER ;
