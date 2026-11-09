-- 13_sp_catalogo_region_sucursal.sql
-- SP CRUD región y sucursal (respuesta estándar fiCodigo/fcMensaje/fbSucces/fjData)
-- Callers: docker exec MariaLocal (aplicación manual); FM.OrigenDatos/Repositorios/CatalogoRepositorio (futuro)
-- Affected API: sp_catalogo_region_*, sp_catalogo_sucursal_*
-- Data schema: region(fiId,fcCodigo,fcNombre,fbActivo); sucursal(fiId,fcCodigo,fcNombre,fcTipo,fiRegionId,fcDireccion,fcTelefono,fbActivo)
-- User instruction: "SP de catalogos con respuesta estandar: para cada catalogo listar... obtener, guardar... activar/desactivar"
-- Aplicar: docker exec -i MariaLocal sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" faramantenimiento' < db/migrations/13_sp_catalogo_region_sucursal.sql

SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_catalogo_region_listar;
DROP PROCEDURE IF EXISTS sp_catalogo_region_obtener;
DROP PROCEDURE IF EXISTS sp_catalogo_region_guardar;
DROP PROCEDURE IF EXISTS sp_catalogo_region_activar;
DROP PROCEDURE IF EXISTS sp_catalogo_sucursal_listar;
DROP PROCEDURE IF EXISTS sp_catalogo_sucursal_obtener;
DROP PROCEDURE IF EXISTS sp_catalogo_sucursal_guardar;
DROP PROCEDURE IF EXISTS sp_catalogo_sucursal_activar;

DELIMITER $$

CREATE PROCEDURE sp_catalogo_region_listar(IN p_fbSoloActivos TINYINT)
BEGIN
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;
  SELECT r.fiId, r.fcCodigo, r.fcNombre, r.fbActivo, r.fdCreado, r.fdModificado
  FROM region r
  WHERE (IFNULL(p_fbSoloActivos, 1) = 0 OR r.fbActivo = 1)
  ORDER BY r.fcNombre;
END$$

CREATE PROCEDURE sp_catalogo_region_obtener(IN p_fiId INT)
proc: BEGIN
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM region WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'La región no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('region', p_fiId) AS fjData;
  SELECT r.fiId, r.fcCodigo, r.fcNombre, r.fbActivo, r.fdCreado, r.fiCreadoPor, r.fdModificado, r.fiModificadoPor
  FROM region r
  WHERE r.fiId = p_fiId;
END$$

CREATE PROCEDURE sp_catalogo_region_guardar(
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
    SELECT 500 AS fiCodigo, 'Ocurrió un error al guardar la región' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
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
    IF EXISTS (SELECT 1 FROM region WHERE fcCodigo = p_fcCodigo) THEN
      ROLLBACK;
      SELECT 409 AS fiCodigo, 'Ya existe una región con ese código' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
    INSERT INTO region (fcCodigo, fcNombre, fiCreadoPor, fbActivo)
    VALUES (TRIM(p_fcCodigo), TRIM(p_fcNombre), p_fiUsuarioId, 1);
    SET v_id = LAST_INSERT_ID();
    COMMIT;
    SELECT 201 AS fiCodigo, 'Región creada correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('region', v_id) AS fjData;
  ELSE
    IF NOT EXISTS (SELECT 1 FROM region WHERE fiId = p_fiId) THEN
      ROLLBACK;
      SELECT 404 AS fiCodigo, 'La región no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
    IF EXISTS (SELECT 1 FROM region WHERE fcCodigo = p_fcCodigo AND fiId <> p_fiId) THEN
      ROLLBACK;
      SELECT 409 AS fiCodigo, 'Ya existe una región con ese código' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
    UPDATE region
    SET fcCodigo = TRIM(p_fcCodigo),
        fcNombre = TRIM(p_fcNombre),
        fdModificado = NOW(),
        fiModificadoPor = p_fiUsuarioId
    WHERE fiId = p_fiId;
    SET v_id = p_fiId;
    COMMIT;
    SELECT 200 AS fiCodigo, 'Región guardada correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('region', v_id) AS fjData;
  END IF;
END$$

CREATE PROCEDURE sp_catalogo_region_activar(
  IN p_fiId INT,
  IN p_fbActivo TINYINT,
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al actualizar la región' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM region WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'La región no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  START TRANSACTION;
  UPDATE region
  SET fbActivo = IF(IFNULL(p_fbActivo, 0) = 1, 1, 0),
      fdModificado = NOW(),
      fiModificadoPor = p_fiUsuarioId
  WHERE fiId = p_fiId;
  COMMIT;
  SELECT 200 AS fiCodigo,
         IF(IFNULL(p_fbActivo, 0) = 1, 'Región activada correctamente', 'Región desactivada correctamente') AS fcMensaje,
         1 AS fbSucces,
         JSON_OBJECT('region', p_fiId) AS fjData;
END$$

CREATE PROCEDURE sp_catalogo_sucursal_listar(IN p_fbSoloActivos TINYINT, IN p_fiRegionId INT)
BEGIN
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;
  SELECT s.fiId, s.fcCodigo, s.fcNombre, s.fcTipo, s.fiRegionId, r.fcNombre AS fcRegionNombre,
         s.fcDireccion, s.fcTelefono, s.fbActivo, s.fdCreado, s.fdModificado
  FROM sucursal s
  INNER JOIN region r ON r.fiId = s.fiRegionId
  WHERE (IFNULL(p_fbSoloActivos, 1) = 0 OR s.fbActivo = 1)
    AND (p_fiRegionId IS NULL OR p_fiRegionId <= 0 OR s.fiRegionId = p_fiRegionId)
  ORDER BY s.fcNombre;
END$$

CREATE PROCEDURE sp_catalogo_sucursal_obtener(IN p_fiId INT)
proc: BEGIN
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM sucursal WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'La sucursal no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('sucursal', p_fiId) AS fjData;
  SELECT s.fiId, s.fcCodigo, s.fcNombre, s.fcTipo, s.fiRegionId, r.fcNombre AS fcRegionNombre,
         s.fcDireccion, s.fcTelefono, s.fbActivo, s.fdCreado, s.fiCreadoPor, s.fdModificado, s.fiModificadoPor
  FROM sucursal s
  INNER JOIN region r ON r.fiId = s.fiRegionId
  WHERE s.fiId = p_fiId;
END$$

CREATE PROCEDURE sp_catalogo_sucursal_guardar(
  IN p_fiId INT,
  IN p_fcCodigo VARCHAR(30),
  IN p_fcNombre VARCHAR(150),
  IN p_fcTipo VARCHAR(20),
  IN p_fiRegionId INT,
  IN p_fcDireccion VARCHAR(250),
  IN p_fcTelefono VARCHAR(40),
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_id INT;
  DECLARE v_tipo VARCHAR(20);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al guardar la sucursal' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  SET v_tipo = UPPER(TRIM(IFNULL(p_fcTipo, '')));
  IF TRIM(IFNULL(p_fcCodigo, '')) = '' THEN
    SELECT 400 AS fiCodigo, 'El código es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;
  IF TRIM(IFNULL(p_fcNombre, '')) = '' THEN
    SELECT 400 AS fiCodigo, 'El nombre es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;
  IF v_tipo NOT IN ('SUCURSAL', 'AREA', 'DEPARTAMENTO') THEN
    SELECT 400 AS fiCodigo, 'El tipo debe ser SUCURSAL, AREA o DEPARTAMENTO' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;
  IF p_fiRegionId IS NULL OR p_fiRegionId <= 0 OR NOT EXISTS (SELECT 1 FROM region WHERE fiId = p_fiRegionId AND fbActivo = 1) THEN
    SELECT 400 AS fiCodigo, 'La región no es válida' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  START TRANSACTION;
  IF p_fiId IS NULL OR p_fiId <= 0 THEN
    IF EXISTS (SELECT 1 FROM sucursal WHERE fcCodigo = p_fcCodigo) THEN
      ROLLBACK;
      SELECT 409 AS fiCodigo, 'Ya existe una sucursal con ese código' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
    INSERT INTO sucursal (fcCodigo, fcNombre, fcTipo, fiRegionId, fcDireccion, fcTelefono, fiCreadoPor, fbActivo)
    VALUES (TRIM(p_fcCodigo), TRIM(p_fcNombre), v_tipo, p_fiRegionId, NULLIF(TRIM(p_fcDireccion), ''), NULLIF(TRIM(p_fcTelefono), ''), p_fiUsuarioId, 1);
    SET v_id = LAST_INSERT_ID();
    COMMIT;
    SELECT 201 AS fiCodigo, 'Sucursal creada correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('sucursal', v_id) AS fjData;
  ELSE
    IF NOT EXISTS (SELECT 1 FROM sucursal WHERE fiId = p_fiId) THEN
      ROLLBACK;
      SELECT 404 AS fiCodigo, 'La sucursal no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
    IF EXISTS (SELECT 1 FROM sucursal WHERE fcCodigo = p_fcCodigo AND fiId <> p_fiId) THEN
      ROLLBACK;
      SELECT 409 AS fiCodigo, 'Ya existe una sucursal con ese código' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
    UPDATE sucursal
    SET fcCodigo = TRIM(p_fcCodigo),
        fcNombre = TRIM(p_fcNombre),
        fcTipo = v_tipo,
        fiRegionId = p_fiRegionId,
        fcDireccion = NULLIF(TRIM(p_fcDireccion), ''),
        fcTelefono = NULLIF(TRIM(p_fcTelefono), ''),
        fdModificado = NOW(),
        fiModificadoPor = p_fiUsuarioId
    WHERE fiId = p_fiId;
    SET v_id = p_fiId;
    COMMIT;
    SELECT 200 AS fiCodigo, 'Sucursal guardada correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('sucursal', v_id) AS fjData;
  END IF;
END$$

CREATE PROCEDURE sp_catalogo_sucursal_activar(
  IN p_fiId INT,
  IN p_fbActivo TINYINT,
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al actualizar la sucursal' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM sucursal WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'La sucursal no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  START TRANSACTION;
  UPDATE sucursal
  SET fbActivo = IF(IFNULL(p_fbActivo, 0) = 1, 1, 0),
      fdModificado = NOW(),
      fiModificadoPor = p_fiUsuarioId
  WHERE fiId = p_fiId;
  COMMIT;
  SELECT 200 AS fiCodigo,
         IF(IFNULL(p_fbActivo, 0) = 1, 'Sucursal activada correctamente', 'Sucursal desactivada correctamente') AS fcMensaje,
         1 AS fbSucces,
         JSON_OBJECT('sucursal', p_fiId) AS fjData;
END$$

DELIMITER ;
