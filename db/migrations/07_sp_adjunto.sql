-- 07_sp_adjunto.sql
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_adjunto_guardar;
DROP PROCEDURE IF EXISTS sp_adjunto_listar;
DROP PROCEDURE IF EXISTS sp_adjunto_obtener;
DROP PROCEDURE IF EXISTS sp_adjunto_eliminar;

DELIMITER $$

CREATE PROCEDURE sp_adjunto_guardar(
  IN p_fcEntidad VARCHAR(50),
  IN p_fiEntidadId INT,
  IN p_fcEtapa VARCHAR(20),
  IN p_fcNombreOriginal VARCHAR(255),
  IN p_fcRuta VARCHAR(500),
  IN p_fcTipoMime VARCHAR(100),
  IN p_fiTamanoBytes BIGINT,
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_id INT;
  DECLARE v_etapa VARCHAR(20);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al guardar el adjunto' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  SET v_etapa = UPPER(TRIM(IFNULL(p_fcEtapa,'')));
  IF TRIM(IFNULL(p_fcEntidad,'')) = '' OR p_fiEntidadId IS NULL OR p_fiEntidadId <= 0 THEN
    SELECT 400 AS fiCodigo, 'La entidad del adjunto es obligatoria' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF v_etapa NOT IN ('SOLICITUD','ANTES','DESPUES') THEN
    SELECT 400 AS fiCodigo, 'La etapa debe ser SOLICITUD, ANTES o DESPUES' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF TRIM(IFNULL(p_fcNombreOriginal,'')) = '' OR TRIM(IFNULL(p_fcRuta,'')) = '' THEN
    SELECT 400 AS fiCodigo, 'El nombre y la ruta del archivo son obligatorios' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;

  START TRANSACTION;
  INSERT INTO adjunto (fcEntidad, fiEntidadId, fcEtapa, fcNombreOriginal, fcRuta, fcTipoMime, fiTamanoBytes, fiCreadoPor, fbActivo)
  VALUES (TRIM(p_fcEntidad), p_fiEntidadId, v_etapa, TRIM(p_fcNombreOriginal), TRIM(p_fcRuta),
          NULLIF(TRIM(p_fcTipoMime),''), IFNULL(p_fiTamanoBytes,0), p_fiUsuarioId, 1);
  SET v_id = LAST_INSERT_ID();
  COMMIT;
  SELECT 201 AS fiCodigo, 'Adjunto guardado correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('adjunto', v_id) AS fjData;
END$$

CREATE PROCEDURE sp_adjunto_listar(IN p_fcEntidad VARCHAR(50), IN p_fiEntidadId INT, IN p_fcEtapa VARCHAR(20))
proc: BEGIN
  IF TRIM(IFNULL(p_fcEntidad,'')) = '' OR p_fiEntidadId IS NULL OR p_fiEntidadId <= 0 THEN
    SELECT 400 AS fiCodigo, 'La entidad del adjunto es obligatoria' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;
  SELECT a.fiId, a.fcEntidad, a.fiEntidadId, a.fcEtapa, a.fcNombreOriginal, a.fcRuta,
         a.fcTipoMime, a.fiTamanoBytes, a.fdCreado, a.fiCreadoPor, a.fbActivo
  FROM adjunto a
  WHERE a.fbActivo = 1
    AND a.fcEntidad = TRIM(p_fcEntidad)
    AND a.fiEntidadId = p_fiEntidadId
    AND (p_fcEtapa IS NULL OR TRIM(p_fcEtapa) = '' OR a.fcEtapa = UPPER(TRIM(p_fcEtapa)))
  ORDER BY a.fdCreado DESC, a.fiId DESC;
END$$

CREATE PROCEDURE sp_adjunto_obtener(IN p_fiId INT)
proc: BEGIN
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM adjunto WHERE fiId = p_fiId AND fbActivo = 1) THEN
    SELECT 404 AS fiCodigo, 'El adjunto no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('adjunto', p_fiId) AS fjData;
  SELECT a.fiId, a.fcEntidad, a.fiEntidadId, a.fcEtapa, a.fcNombreOriginal, a.fcRuta,
         a.fcTipoMime, a.fiTamanoBytes, a.fdCreado, a.fiCreadoPor, a.fbActivo
  FROM adjunto a WHERE a.fiId = p_fiId;
END$$

CREATE PROCEDURE sp_adjunto_eliminar(IN p_fiId INT, IN p_fiUsuarioId INT)
proc: BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN ROLLBACK; SELECT 500 AS fiCodigo, 'Ocurrió un error al eliminar el adjunto' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM adjunto WHERE fiId = p_fiId AND fbActivo = 1) THEN
    SELECT 404 AS fiCodigo, 'El adjunto no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  START TRANSACTION;
  UPDATE adjunto SET fbActivo = 0, fdModificado = NOW(), fiModificadoPor = p_fiUsuarioId WHERE fiId = p_fiId;
  COMMIT;
  SELECT 200 AS fiCodigo, 'Adjunto eliminado correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('adjunto', p_fiId) AS fjData;
END$$

DELIMITER ;
