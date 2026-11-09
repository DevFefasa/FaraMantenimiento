-- 16_sp_catalogo_estado_motivoespera.sql
-- Callers: docker exec MariaLocal; CatalogoRepositorio (futuro)
-- API: sp_catalogo_estado_*, sp_catalogo_motivoespera_*
-- Schema: estado(fiId,fcCodigo,fcNombre,fiOrden,fcColor,fbFinal,fbActivo); motivoespera(fiId,fcCodigo,fcNombre,fiOrden,fbActivo)
-- User instruction: "SP de catalogos con respuesta estandar: para cada catalogo listar, obtener, guardar, activar/desactivar"
-- Aplicar: docker exec -i MariaLocal sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" faramantenimiento' < db/migrations/16_sp_catalogo_estado_motivoespera.sql

SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_catalogo_estado_listar;
DROP PROCEDURE IF EXISTS sp_catalogo_estado_obtener;
DROP PROCEDURE IF EXISTS sp_catalogo_estado_guardar;
DROP PROCEDURE IF EXISTS sp_catalogo_estado_activar;
DROP PROCEDURE IF EXISTS sp_catalogo_motivoespera_listar;
DROP PROCEDURE IF EXISTS sp_catalogo_motivoespera_obtener;
DROP PROCEDURE IF EXISTS sp_catalogo_motivoespera_guardar;
DROP PROCEDURE IF EXISTS sp_catalogo_motivoespera_activar;

DELIMITER $$

CREATE PROCEDURE sp_catalogo_estado_listar(IN p_fbSoloActivos TINYINT)
BEGIN
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;
  SELECT e.fiId, e.fcCodigo, e.fcNombre, e.fiOrden, e.fcColor, e.fbFinal, e.fbActivo, e.fdCreado, e.fdModificado
  FROM estado e
  WHERE (IFNULL(p_fbSoloActivos, 1) = 0 OR e.fbActivo = 1)
  ORDER BY e.fiOrden, e.fcNombre;
END$$

CREATE PROCEDURE sp_catalogo_estado_obtener(IN p_fiId INT)
proc: BEGIN
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM estado WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'El estado no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('estado', p_fiId) AS fjData;
  SELECT e.fiId, e.fcCodigo, e.fcNombre, e.fiOrden, e.fcColor, e.fbFinal, e.fbActivo,
         e.fdCreado, e.fiCreadoPor, e.fdModificado, e.fiModificadoPor
  FROM estado e WHERE e.fiId = p_fiId;
END$$

CREATE PROCEDURE sp_catalogo_estado_guardar(
  IN p_fiId INT, IN p_fcCodigo VARCHAR(30), IN p_fcNombre VARCHAR(80),
  IN p_fiOrden INT, IN p_fcColor VARCHAR(20), IN p_fbFinal TINYINT, IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_id INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; SELECT 500 AS fiCodigo, 'Ocurrió un error al guardar el estado' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;
  IF TRIM(IFNULL(p_fcCodigo,'')) = '' THEN SELECT 400 AS fiCodigo, 'El código es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc; END IF;
  IF TRIM(IFNULL(p_fcNombre,'')) = '' THEN SELECT 400 AS fiCodigo, 'El nombre es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc; END IF;
  START TRANSACTION;
  IF p_fiId IS NULL OR p_fiId <= 0 THEN
    IF EXISTS (SELECT 1 FROM estado WHERE fcCodigo = p_fcCodigo) THEN
      ROLLBACK; SELECT 409 AS fiCodigo, 'Ya existe un estado con ese código' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    INSERT INTO estado (fcCodigo, fcNombre, fiOrden, fcColor, fbFinal, fiCreadoPor, fbActivo)
    VALUES (TRIM(p_fcCodigo), TRIM(p_fcNombre), IFNULL(p_fiOrden,0), IFNULL(NULLIF(TRIM(p_fcColor),''),'#6c757d'), IF(IFNULL(p_fbFinal,0)=1,1,0), p_fiUsuarioId, 1);
    SET v_id = LAST_INSERT_ID(); COMMIT;
    SELECT 201 AS fiCodigo, 'Estado creado correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('estado', v_id) AS fjData;
  ELSE
    IF NOT EXISTS (SELECT 1 FROM estado WHERE fiId = p_fiId) THEN
      ROLLBACK; SELECT 404 AS fiCodigo, 'El estado no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    IF EXISTS (SELECT 1 FROM estado WHERE fcCodigo = p_fcCodigo AND fiId <> p_fiId) THEN
      ROLLBACK; SELECT 409 AS fiCodigo, 'Ya existe un estado con ese código' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    UPDATE estado SET fcCodigo = TRIM(p_fcCodigo), fcNombre = TRIM(p_fcNombre), fiOrden = IFNULL(p_fiOrden,0),
      fcColor = IFNULL(NULLIF(TRIM(p_fcColor),''),'#6c757d'), fbFinal = IF(IFNULL(p_fbFinal,0)=1,1,0),
      fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId WHERE fiId = p_fiId;
    SET v_id = p_fiId; COMMIT;
    SELECT 200 AS fiCodigo, 'Estado guardado correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('estado', v_id) AS fjData;
  END IF;
END$$

CREATE PROCEDURE sp_catalogo_estado_activar(IN p_fiId INT, IN p_fbActivo TINYINT, IN p_fiUsuarioId INT)
proc: BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; SELECT 500 AS fiCodigo, 'Ocurrió un error al actualizar el estado' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM estado WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'El estado no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  START TRANSACTION;
  UPDATE estado SET fbActivo = IF(IFNULL(p_fbActivo,0)=1,1,0), fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId WHERE fiId = p_fiId;
  COMMIT;
  SELECT 200 AS fiCodigo, IF(IFNULL(p_fbActivo,0)=1,'Estado activado correctamente','Estado desactivado correctamente') AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('estado', p_fiId) AS fjData;
END$$

CREATE PROCEDURE sp_catalogo_motivoespera_listar(IN p_fbSoloActivos TINYINT)
BEGIN
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;
  SELECT m.fiId, m.fcCodigo, m.fcNombre, m.fiOrden, m.fbActivo, m.fdCreado, m.fdModificado
  FROM motivoespera m
  WHERE (IFNULL(p_fbSoloActivos, 1) = 0 OR m.fbActivo = 1)
  ORDER BY m.fiOrden, m.fcNombre;
END$$

CREATE PROCEDURE sp_catalogo_motivoespera_obtener(IN p_fiId INT)
proc: BEGIN
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM motivoespera WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'El motivo de espera no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('motivoespera', p_fiId) AS fjData;
  SELECT m.fiId, m.fcCodigo, m.fcNombre, m.fiOrden, m.fbActivo, m.fdCreado, m.fiCreadoPor, m.fdModificado, m.fiModificadoPor
  FROM motivoespera m WHERE m.fiId = p_fiId;
END$$

CREATE PROCEDURE sp_catalogo_motivoespera_guardar(
  IN p_fiId INT, IN p_fcCodigo VARCHAR(30), IN p_fcNombre VARCHAR(100), IN p_fiOrden INT, IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_id INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; SELECT 500 AS fiCodigo, 'Ocurrió un error al guardar el motivo de espera' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;
  IF TRIM(IFNULL(p_fcCodigo,'')) = '' THEN SELECT 400 AS fiCodigo, 'El código es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc; END IF;
  IF TRIM(IFNULL(p_fcNombre,'')) = '' THEN SELECT 400 AS fiCodigo, 'El nombre es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc; END IF;
  START TRANSACTION;
  IF p_fiId IS NULL OR p_fiId <= 0 THEN
    IF EXISTS (SELECT 1 FROM motivoespera WHERE fcCodigo = p_fcCodigo) THEN
      ROLLBACK; SELECT 409 AS fiCodigo, 'Ya existe un motivo de espera con ese código' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    INSERT INTO motivoespera (fcCodigo, fcNombre, fiOrden, fiCreadoPor, fbActivo)
    VALUES (TRIM(p_fcCodigo), TRIM(p_fcNombre), IFNULL(p_fiOrden,0), p_fiUsuarioId, 1);
    SET v_id = LAST_INSERT_ID(); COMMIT;
    SELECT 201 AS fiCodigo, 'Motivo de espera creado correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('motivoespera', v_id) AS fjData;
  ELSE
    IF NOT EXISTS (SELECT 1 FROM motivoespera WHERE fiId = p_fiId) THEN
      ROLLBACK; SELECT 404 AS fiCodigo, 'El motivo de espera no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    IF EXISTS (SELECT 1 FROM motivoespera WHERE fcCodigo = p_fcCodigo AND fiId <> p_fiId) THEN
      ROLLBACK; SELECT 409 AS fiCodigo, 'Ya existe un motivo de espera con ese código' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    UPDATE motivoespera SET fcCodigo = TRIM(p_fcCodigo), fcNombre = TRIM(p_fcNombre), fiOrden = IFNULL(p_fiOrden,0),
      fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId WHERE fiId = p_fiId;
    SET v_id = p_fiId; COMMIT;
    SELECT 200 AS fiCodigo, 'Motivo de espera guardado correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('motivoespera', v_id) AS fjData;
  END IF;
END$$

CREATE PROCEDURE sp_catalogo_motivoespera_activar(IN p_fiId INT, IN p_fbActivo TINYINT, IN p_fiUsuarioId INT)
proc: BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; SELECT 500 AS fiCodigo, 'Ocurrió un error al actualizar el motivo de espera' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM motivoespera WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'El motivo de espera no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  START TRANSACTION;
  UPDATE motivoespera SET fbActivo = IF(IFNULL(p_fbActivo,0)=1,1,0), fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId WHERE fiId = p_fiId;
  COMMIT;
  SELECT 200 AS fiCodigo, IF(IFNULL(p_fbActivo,0)=1,'Motivo de espera activado correctamente','Motivo de espera desactivado correctamente') AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('motivoespera', p_fiId) AS fjData;
END$$

DELIMITER ;
