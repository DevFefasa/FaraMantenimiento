-- 14_sp_catalogo_ubicacion_activo.sql
-- Callers: docker exec MariaLocal; FM.OrigenDatos/Repositorios/CatalogoRepositorio (futuro)
-- Affected API: sp_catalogo_ubicacion_*, sp_catalogo_activo_*
-- Schema: ubicacion(fiId,fcCodigo,fcNombre,fiSucursalId,fbActivo); activo(fiId,fcCodigo,fcNombre,fcMarca,fcModelo,fcSerie,fiSucursalId,fiUbicacionId,fiCategoriaId,fdFechaInstalacion,fbActivo)
-- User instruction: "SP de catalogos con respuesta estandar: para cada catalogo listar (con filtro de activos), obtener, guardar... activar/desactivar"
-- Aplicar: docker exec -i MariaLocal sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" faramantenimiento' < db/migrations/14_sp_catalogo_ubicacion_activo.sql

SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_catalogo_ubicacion_listar;
DROP PROCEDURE IF EXISTS sp_catalogo_ubicacion_obtener;
DROP PROCEDURE IF EXISTS sp_catalogo_ubicacion_guardar;
DROP PROCEDURE IF EXISTS sp_catalogo_ubicacion_activar;
DROP PROCEDURE IF EXISTS sp_catalogo_activo_listar;
DROP PROCEDURE IF EXISTS sp_catalogo_activo_obtener;
DROP PROCEDURE IF EXISTS sp_catalogo_activo_guardar;
DROP PROCEDURE IF EXISTS sp_catalogo_activo_activar;

DELIMITER $$

CREATE PROCEDURE sp_catalogo_ubicacion_listar(IN p_fbSoloActivos TINYINT, IN p_fiSucursalId INT)
BEGIN
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;
  SELECT u.fiId, u.fcCodigo, u.fcNombre, u.fiSucursalId, s.fcNombre AS fcSucursalNombre,
         u.fbActivo, u.fdCreado, u.fdModificado
  FROM ubicacion u
  INNER JOIN sucursal s ON s.fiId = u.fiSucursalId
  WHERE (IFNULL(p_fbSoloActivos, 1) = 0 OR u.fbActivo = 1)
    AND (p_fiSucursalId IS NULL OR p_fiSucursalId <= 0 OR u.fiSucursalId = p_fiSucursalId)
  ORDER BY u.fcNombre;
END$$

CREATE PROCEDURE sp_catalogo_ubicacion_obtener(IN p_fiId INT)
proc: BEGIN
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM ubicacion WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'La ubicación no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('ubicacion', p_fiId) AS fjData;
  SELECT u.fiId, u.fcCodigo, u.fcNombre, u.fiSucursalId, s.fcNombre AS fcSucursalNombre,
         u.fbActivo, u.fdCreado, u.fiCreadoPor, u.fdModificado, u.fiModificadoPor
  FROM ubicacion u
  INNER JOIN sucursal s ON s.fiId = u.fiSucursalId
  WHERE u.fiId = p_fiId;
END$$

CREATE PROCEDURE sp_catalogo_ubicacion_guardar(
  IN p_fiId INT,
  IN p_fcCodigo VARCHAR(30),
  IN p_fcNombre VARCHAR(150),
  IN p_fiSucursalId INT,
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_id INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al guardar la ubicación' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  IF TRIM(IFNULL(p_fcCodigo, '')) = '' THEN
    SELECT 400 AS fiCodigo, 'El código es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;
  IF TRIM(IFNULL(p_fcNombre, '')) = '' THEN
    SELECT 400 AS fiCodigo, 'El nombre es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;
  IF p_fiSucursalId IS NULL OR p_fiSucursalId <= 0 OR NOT EXISTS (SELECT 1 FROM sucursal WHERE fiId = p_fiSucursalId AND fbActivo = 1) THEN
    SELECT 400 AS fiCodigo, 'La sucursal no es válida' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  START TRANSACTION;
  IF p_fiId IS NULL OR p_fiId <= 0 THEN
    IF EXISTS (SELECT 1 FROM ubicacion WHERE fcCodigo = p_fcCodigo) THEN
      ROLLBACK;
      SELECT 409 AS fiCodigo, 'Ya existe una ubicación con ese código' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
    INSERT INTO ubicacion (fcCodigo, fcNombre, fiSucursalId, fiCreadoPor, fbActivo)
    VALUES (TRIM(p_fcCodigo), TRIM(p_fcNombre), p_fiSucursalId, p_fiUsuarioId, 1);
    SET v_id = LAST_INSERT_ID();
    COMMIT;
    SELECT 201 AS fiCodigo, 'Ubicación creada correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('ubicacion', v_id) AS fjData;
  ELSE
    IF NOT EXISTS (SELECT 1 FROM ubicacion WHERE fiId = p_fiId) THEN
      ROLLBACK;
      SELECT 404 AS fiCodigo, 'La ubicación no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
    IF EXISTS (SELECT 1 FROM ubicacion WHERE fcCodigo = p_fcCodigo AND fiId <> p_fiId) THEN
      ROLLBACK;
      SELECT 409 AS fiCodigo, 'Ya existe una ubicación con ese código' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
    UPDATE ubicacion
    SET fcCodigo = TRIM(p_fcCodigo),
        fcNombre = TRIM(p_fcNombre),
        fiSucursalId = p_fiSucursalId,
        fdModificado = NOW(),
        fiModificadoPor = p_fiUsuarioId
    WHERE fiId = p_fiId;
    SET v_id = p_fiId;
    COMMIT;
    SELECT 200 AS fiCodigo, 'Ubicación guardada correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('ubicacion', v_id) AS fjData;
  END IF;
END$$

CREATE PROCEDURE sp_catalogo_ubicacion_activar(
  IN p_fiId INT,
  IN p_fbActivo TINYINT,
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al actualizar la ubicación' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM ubicacion WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'La ubicación no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;
  START TRANSACTION;
  UPDATE ubicacion
  SET fbActivo = IF(IFNULL(p_fbActivo, 0) = 1, 1, 0),
      fdModificado = NOW(),
      fiModificadoPor = p_fiUsuarioId
  WHERE fiId = p_fiId;
  COMMIT;
  SELECT 200 AS fiCodigo,
         IF(IFNULL(p_fbActivo, 0) = 1, 'Ubicación activada correctamente', 'Ubicación desactivada correctamente') AS fcMensaje,
         1 AS fbSucces, JSON_OBJECT('ubicacion', p_fiId) AS fjData;
END$$

CREATE PROCEDURE sp_catalogo_activo_listar(IN p_fbSoloActivos TINYINT, IN p_fiSucursalId INT, IN p_fiCategoriaId INT)
BEGIN
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;
  SELECT a.fiId, a.fcCodigo, a.fcNombre, a.fcMarca, a.fcModelo, a.fcSerie,
         a.fiSucursalId, s.fcNombre AS fcSucursalNombre,
         a.fiUbicacionId, u.fcNombre AS fcUbicacionNombre,
         a.fiCategoriaId, c.fcNombre AS fcCategoriaNombre,
         a.fdFechaInstalacion, a.fbActivo, a.fdCreado, a.fdModificado
  FROM activo a
  INNER JOIN sucursal s ON s.fiId = a.fiSucursalId
  LEFT JOIN ubicacion u ON u.fiId = a.fiUbicacionId
  LEFT JOIN categoria c ON c.fiId = a.fiCategoriaId
  WHERE (IFNULL(p_fbSoloActivos, 1) = 0 OR a.fbActivo = 1)
    AND (p_fiSucursalId IS NULL OR p_fiSucursalId <= 0 OR a.fiSucursalId = p_fiSucursalId)
    AND (p_fiCategoriaId IS NULL OR p_fiCategoriaId <= 0 OR a.fiCategoriaId = p_fiCategoriaId)
  ORDER BY a.fcNombre;
END$$

CREATE PROCEDURE sp_catalogo_activo_obtener(IN p_fiId INT)
proc: BEGIN
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM activo WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'El activo no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('activo', p_fiId) AS fjData;
  SELECT a.fiId, a.fcCodigo, a.fcNombre, a.fcMarca, a.fcModelo, a.fcSerie,
         a.fiSucursalId, s.fcNombre AS fcSucursalNombre,
         a.fiUbicacionId, u.fcNombre AS fcUbicacionNombre,
         a.fiCategoriaId, c.fcNombre AS fcCategoriaNombre,
         a.fdFechaInstalacion, a.fbActivo, a.fdCreado, a.fiCreadoPor, a.fdModificado, a.fiModificadoPor
  FROM activo a
  INNER JOIN sucursal s ON s.fiId = a.fiSucursalId
  LEFT JOIN ubicacion u ON u.fiId = a.fiUbicacionId
  LEFT JOIN categoria c ON c.fiId = a.fiCategoriaId
  WHERE a.fiId = p_fiId;
END$$

CREATE PROCEDURE sp_catalogo_activo_guardar(
  IN p_fiId INT,
  IN p_fcCodigo VARCHAR(30),
  IN p_fcNombre VARCHAR(150),
  IN p_fcMarca VARCHAR(80),
  IN p_fcModelo VARCHAR(80),
  IN p_fcSerie VARCHAR(80),
  IN p_fiSucursalId INT,
  IN p_fiUbicacionId INT,
  IN p_fiCategoriaId INT,
  IN p_fdFechaInstalacion DATE,
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_id INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al guardar el activo' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  IF TRIM(IFNULL(p_fcCodigo, '')) = '' THEN
    SELECT 400 AS fiCodigo, 'El código es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;
  IF TRIM(IFNULL(p_fcNombre, '')) = '' THEN
    SELECT 400 AS fiCodigo, 'El nombre es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;
  IF p_fiSucursalId IS NULL OR p_fiSucursalId <= 0 OR NOT EXISTS (SELECT 1 FROM sucursal WHERE fiId = p_fiSucursalId AND fbActivo = 1) THEN
    SELECT 400 AS fiCodigo, 'La sucursal no es válida' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;
  IF p_fiUbicacionId IS NOT NULL AND p_fiUbicacionId > 0 THEN
    IF NOT EXISTS (SELECT 1 FROM ubicacion WHERE fiId = p_fiUbicacionId AND fiSucursalId = p_fiSucursalId AND fbActivo = 1) THEN
      SELECT 400 AS fiCodigo, 'La ubicación no es válida para la sucursal' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
  END IF;
  IF p_fiCategoriaId IS NOT NULL AND p_fiCategoriaId > 0 THEN
    IF NOT EXISTS (SELECT 1 FROM categoria WHERE fiId = p_fiCategoriaId AND fbActivo = 1) THEN
      SELECT 400 AS fiCodigo, 'La categoría no es válida' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
  END IF;

  START TRANSACTION;
  IF p_fiId IS NULL OR p_fiId <= 0 THEN
    IF EXISTS (SELECT 1 FROM activo WHERE fcCodigo = p_fcCodigo) THEN
      ROLLBACK;
      SELECT 409 AS fiCodigo, 'Ya existe un activo con ese código' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
    INSERT INTO activo (fcCodigo, fcNombre, fcMarca, fcModelo, fcSerie, fiSucursalId, fiUbicacionId, fiCategoriaId, fdFechaInstalacion, fiCreadoPor, fbActivo)
    VALUES (
      TRIM(p_fcCodigo), TRIM(p_fcNombre), NULLIF(TRIM(p_fcMarca), ''), NULLIF(TRIM(p_fcModelo), ''), NULLIF(TRIM(p_fcSerie), ''),
      p_fiSucursalId,
      IF(p_fiUbicacionId IS NULL OR p_fiUbicacionId <= 0, NULL, p_fiUbicacionId),
      IF(p_fiCategoriaId IS NULL OR p_fiCategoriaId <= 0, NULL, p_fiCategoriaId),
      p_fdFechaInstalacion, p_fiUsuarioId, 1
    );
    SET v_id = LAST_INSERT_ID();
    COMMIT;
    SELECT 201 AS fiCodigo, 'Activo creado correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('activo', v_id) AS fjData;
  ELSE
    IF NOT EXISTS (SELECT 1 FROM activo WHERE fiId = p_fiId) THEN
      ROLLBACK;
      SELECT 404 AS fiCodigo, 'El activo no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
    IF EXISTS (SELECT 1 FROM activo WHERE fcCodigo = p_fcCodigo AND fiId <> p_fiId) THEN
      ROLLBACK;
      SELECT 409 AS fiCodigo, 'Ya existe un activo con ese código' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
    UPDATE activo
    SET fcCodigo = TRIM(p_fcCodigo),
        fcNombre = TRIM(p_fcNombre),
        fcMarca = NULLIF(TRIM(p_fcMarca), ''),
        fcModelo = NULLIF(TRIM(p_fcModelo), ''),
        fcSerie = NULLIF(TRIM(p_fcSerie), ''),
        fiSucursalId = p_fiSucursalId,
        fiUbicacionId = IF(p_fiUbicacionId IS NULL OR p_fiUbicacionId <= 0, NULL, p_fiUbicacionId),
        fiCategoriaId = IF(p_fiCategoriaId IS NULL OR p_fiCategoriaId <= 0, NULL, p_fiCategoriaId),
        fdFechaInstalacion = p_fdFechaInstalacion,
        fdModificado = NOW(),
        fiModificadoPor = p_fiUsuarioId
    WHERE fiId = p_fiId;
    SET v_id = p_fiId;
    COMMIT;
    SELECT 200 AS fiCodigo, 'Activo guardado correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('activo', v_id) AS fjData;
  END IF;
END$$

CREATE PROCEDURE sp_catalogo_activo_activar(
  IN p_fiId INT,
  IN p_fbActivo TINYINT,
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al actualizar el activo' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM activo WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'El activo no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;
  START TRANSACTION;
  UPDATE activo
  SET fbActivo = IF(IFNULL(p_fbActivo, 0) = 1, 1, 0),
      fdModificado = NOW(),
      fiModificadoPor = p_fiUsuarioId
  WHERE fiId = p_fiId;
  COMMIT;
  SELECT 200 AS fiCodigo,
         IF(IFNULL(p_fbActivo, 0) = 1, 'Activo activado correctamente', 'Activo desactivado correctamente') AS fcMensaje,
         1 AS fbSucces, JSON_OBJECT('activo', p_fiId) AS fjData;
END$$

DELIMITER ;
