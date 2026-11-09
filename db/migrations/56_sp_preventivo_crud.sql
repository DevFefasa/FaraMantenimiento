-- 56_sp_preventivo_crud.sql
-- Callers: PreventivoRepositorio (Listar/Obtener/Guardar/Activar); PreventivosController
-- API: sp_preventivo_listar, sp_preventivo_obtener, sp_preventivo_guardar, sp_preventivo_activar
-- Schema: fila estándar fiCodigo/fcMensaje/fbSucces/fjData + result sets de planpreventivo
-- User instruction: "SP: listar/obtener/guardar/activar plan"
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_preventivo_listar;
DROP PROCEDURE IF EXISTS sp_preventivo_obtener;
DROP PROCEDURE IF EXISTS sp_preventivo_guardar;
DROP PROCEDURE IF EXISTS sp_preventivo_activar;

DELIMITER $$

CREATE PROCEDURE sp_preventivo_listar(
  IN p_fiSucursalId INT,
  IN p_fbSoloActivos TINYINT
)
BEGIN
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;

  SELECT
    p.fiId, p.fcNombre, p.fiActivoId, a.fcNombre AS fcActivoNombre, a.fcCodigo AS fcActivoCodigo,
    p.fiSucursalId, s.fcNombre AS fcSucursalNombre,
    p.fiUbicacionId, u.fcNombre AS fcUbicacionNombre,
    p.fiCategoriaId, c.fcNombre AS fcCategoriaNombre,
    p.fiPrioridadId, pr.fcNombre AS fcPrioridadNombre, pr.fcColor AS fcPrioridadColor,
    p.fcDescripcion, p.fiFrecuenciaDias, p.fdProximaFecha, p.fiDiasAnticipacion,
    p.fiTecnicoId, t.fcNombre AS fcTecnicoNombre,
    p.fiProveedorId, pv.fcNombre AS fcProveedorNombre,
    p.fbActivo, p.fdCreado, p.fdModificado
  FROM planpreventivo p
  JOIN sucursal s ON s.fiId = p.fiSucursalId
  JOIN categoria c ON c.fiId = p.fiCategoriaId
  JOIN prioridad pr ON pr.fiId = p.fiPrioridadId
  LEFT JOIN activo a ON a.fiId = p.fiActivoId
  LEFT JOIN ubicacion u ON u.fiId = p.fiUbicacionId
  LEFT JOIN tecnico t ON t.fiId = p.fiTecnicoId
  LEFT JOIN proveedor pv ON pv.fiId = p.fiProveedorId
  WHERE (p_fiSucursalId IS NULL OR p_fiSucursalId <= 0 OR p.fiSucursalId = p_fiSucursalId)
    AND (IFNULL(p_fbSoloActivos, 0) = 0 OR p.fbActivo = 1)
  ORDER BY p.fdProximaFecha, p.fcNombre;
END$$

CREATE PROCEDURE sp_preventivo_obtener(IN p_fiId INT)
proc: BEGIN
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM planpreventivo WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'El plan preventivo no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('planpreventivo', p_fiId) AS fjData;

  SELECT
    p.fiId, p.fcNombre, p.fiActivoId, a.fcNombre AS fcActivoNombre, a.fcCodigo AS fcActivoCodigo,
    p.fiSucursalId, s.fcNombre AS fcSucursalNombre,
    p.fiUbicacionId, u.fcNombre AS fcUbicacionNombre,
    p.fiCategoriaId, c.fcNombre AS fcCategoriaNombre,
    p.fiPrioridadId, pr.fcNombre AS fcPrioridadNombre, pr.fcColor AS fcPrioridadColor,
    p.fcDescripcion, p.fiFrecuenciaDias, p.fdProximaFecha, p.fiDiasAnticipacion,
    p.fiTecnicoId, t.fcNombre AS fcTecnicoNombre,
    p.fiProveedorId, pv.fcNombre AS fcProveedorNombre,
    p.fbActivo, p.fdCreado, p.fiCreadoPor, p.fdModificado, p.fiModificadoPor
  FROM planpreventivo p
  JOIN sucursal s ON s.fiId = p.fiSucursalId
  JOIN categoria c ON c.fiId = p.fiCategoriaId
  JOIN prioridad pr ON pr.fiId = p.fiPrioridadId
  LEFT JOIN activo a ON a.fiId = p.fiActivoId
  LEFT JOIN ubicacion u ON u.fiId = p.fiUbicacionId
  LEFT JOIN tecnico t ON t.fiId = p.fiTecnicoId
  LEFT JOIN proveedor pv ON pv.fiId = p.fiProveedorId
  WHERE p.fiId = p_fiId;

  SELECT e.fiId, e.fiPlanId, e.fdFechaProgramada, e.fiTicketId, e.fdGenerado,
         tk.fcNumero AS fcTicketNumero, est.fcCodigo AS fcEstadoCodigo, est.fcNombre AS fcEstadoNombre
  FROM planpreventivoejecucion e
  LEFT JOIN ticket tk ON tk.fiId = e.fiTicketId
  LEFT JOIN estado est ON est.fiId = tk.fiEstadoId
  WHERE e.fiPlanId = p_fiId
  ORDER BY e.fdFechaProgramada DESC
  LIMIT 50;
END$$

CREATE PROCEDURE sp_preventivo_guardar(
  IN p_fiId INT,
  IN p_fcNombre VARCHAR(150),
  IN p_fiActivoId INT,
  IN p_fiSucursalId INT,
  IN p_fiUbicacionId INT,
  IN p_fiCategoriaId INT,
  IN p_fiPrioridadId INT,
  IN p_fcDescripcion TEXT,
  IN p_fiFrecuenciaDias INT,
  IN p_fdProximaFecha DATE,
  IN p_fiDiasAnticipacion INT,
  IN p_fiTecnicoId INT,
  IN p_fiProveedorId INT,
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_id INT;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al guardar el plan preventivo' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  IF TRIM(IFNULL(p_fcNombre,'')) = '' THEN
    SELECT 400 AS fiCodigo, 'El nombre es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF p_fiSucursalId IS NULL OR p_fiSucursalId <= 0 OR NOT EXISTS (SELECT 1 FROM sucursal WHERE fiId = p_fiSucursalId AND fbActivo = 1) THEN
    SELECT 400 AS fiCodigo, 'La sucursal no es válida' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF p_fiCategoriaId IS NULL OR NOT EXISTS (SELECT 1 FROM categoria WHERE fiId = p_fiCategoriaId AND fbActivo = 1) THEN
    SELECT 400 AS fiCodigo, 'La categoría no es válida' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF p_fiPrioridadId IS NULL OR NOT EXISTS (SELECT 1 FROM prioridad WHERE fiId = p_fiPrioridadId AND fbActivo = 1) THEN
    SELECT 400 AS fiCodigo, 'La prioridad no es válida' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF p_fiFrecuenciaDias IS NULL OR p_fiFrecuenciaDias <= 0 THEN
    SELECT 400 AS fiCodigo, 'La frecuencia en días debe ser mayor a cero' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF p_fdProximaFecha IS NULL THEN
    SELECT 400 AS fiCodigo, 'La próxima fecha es obligatoria' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF p_fiDiasAnticipacion IS NULL OR p_fiDiasAnticipacion < 0 THEN
    SELECT 400 AS fiCodigo, 'Los días de anticipación no son válidos' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF p_fiUbicacionId IS NOT NULL AND p_fiUbicacionId > 0 THEN
    IF NOT EXISTS (SELECT 1 FROM ubicacion WHERE fiId = p_fiUbicacionId AND fiSucursalId = p_fiSucursalId AND fbActivo = 1) THEN
      SELECT 400 AS fiCodigo, 'La ubicación no es válida para la sucursal' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
  END IF;
  IF p_fiActivoId IS NOT NULL AND p_fiActivoId > 0 THEN
    IF NOT EXISTS (SELECT 1 FROM activo WHERE fiId = p_fiActivoId AND fiSucursalId = p_fiSucursalId AND fbActivo = 1) THEN
      SELECT 400 AS fiCodigo, 'El activo no es válido para la sucursal' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
  END IF;
  IF p_fiTecnicoId IS NOT NULL AND p_fiTecnicoId > 0 AND NOT EXISTS (SELECT 1 FROM tecnico WHERE fiId = p_fiTecnicoId AND fbActivo = 1) THEN
    SELECT 400 AS fiCodigo, 'El técnico no es válido' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF p_fiProveedorId IS NOT NULL AND p_fiProveedorId > 0 AND NOT EXISTS (SELECT 1 FROM proveedor WHERE fiId = p_fiProveedorId AND fbActivo = 1) THEN
    SELECT 400 AS fiCodigo, 'El proveedor no es válido' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF (p_fiTecnicoId IS NOT NULL AND p_fiTecnicoId > 0) AND (p_fiProveedorId IS NOT NULL AND p_fiProveedorId > 0) THEN
    SELECT 400 AS fiCodigo, 'Indique técnico o proveedor, no ambos' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF IFNULL(p_fiId, 0) > 0 AND NOT EXISTS (SELECT 1 FROM planpreventivo WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'El plan preventivo no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;

  START TRANSACTION;

  IF IFNULL(p_fiId, 0) <= 0 THEN
    INSERT INTO planpreventivo (
      fcNombre, fiActivoId, fiSucursalId, fiUbicacionId, fiCategoriaId, fiPrioridadId, fcDescripcion,
      fiFrecuenciaDias, fdProximaFecha, fiDiasAnticipacion, fiTecnicoId, fiProveedorId,
      fiCreadoPor, fbActivo
    ) VALUES (
      TRIM(p_fcNombre),
      IF(p_fiActivoId IS NULL OR p_fiActivoId <= 0, NULL, p_fiActivoId),
      p_fiSucursalId,
      IF(p_fiUbicacionId IS NULL OR p_fiUbicacionId <= 0, NULL, p_fiUbicacionId),
      p_fiCategoriaId, p_fiPrioridadId, NULLIF(TRIM(p_fcDescripcion),''),
      p_fiFrecuenciaDias, p_fdProximaFecha, p_fiDiasAnticipacion,
      IF(p_fiTecnicoId IS NULL OR p_fiTecnicoId <= 0, NULL, p_fiTecnicoId),
      IF(p_fiProveedorId IS NULL OR p_fiProveedorId <= 0, NULL, p_fiProveedorId),
      p_fiUsuarioId, 1
    );
    SET v_id = LAST_INSERT_ID();
    COMMIT;
    SELECT 201 AS fiCodigo, 'Plan preventivo creado correctamente' AS fcMensaje, 1 AS fbSucces,
           JSON_OBJECT('planpreventivo', v_id) AS fjData;
  ELSE
    UPDATE planpreventivo SET
      fcNombre = TRIM(p_fcNombre),
      fiActivoId = IF(p_fiActivoId IS NULL OR p_fiActivoId <= 0, NULL, p_fiActivoId),
      fiSucursalId = p_fiSucursalId,
      fiUbicacionId = IF(p_fiUbicacionId IS NULL OR p_fiUbicacionId <= 0, NULL, p_fiUbicacionId),
      fiCategoriaId = p_fiCategoriaId,
      fiPrioridadId = p_fiPrioridadId,
      fcDescripcion = NULLIF(TRIM(p_fcDescripcion),''),
      fiFrecuenciaDias = p_fiFrecuenciaDias,
      fdProximaFecha = p_fdProximaFecha,
      fiDiasAnticipacion = p_fiDiasAnticipacion,
      fiTecnicoId = IF(p_fiTecnicoId IS NULL OR p_fiTecnicoId <= 0, NULL, p_fiTecnicoId),
      fiProveedorId = IF(p_fiProveedorId IS NULL OR p_fiProveedorId <= 0, NULL, p_fiProveedorId),
      fdModificado = NOW(),
      fiModificadoPor = p_fiUsuarioId
    WHERE fiId = p_fiId;
    SET v_id = p_fiId;
    COMMIT;
    SELECT 200 AS fiCodigo, 'Plan preventivo actualizado correctamente' AS fcMensaje, 1 AS fbSucces,
           JSON_OBJECT('planpreventivo', v_id) AS fjData;
  END IF;
END$$

CREATE PROCEDURE sp_preventivo_activar(
  IN p_fiId INT,
  IN p_fbActivo TINYINT,
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al cambiar el estado del plan' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  IF p_fiId IS NULL OR NOT EXISTS (SELECT 1 FROM planpreventivo WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'El plan preventivo no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;

  START TRANSACTION;
  UPDATE planpreventivo
  SET fbActivo = IF(IFNULL(p_fbActivo, 0) = 1, 1, 0),
      fdModificado = NOW(),
      fiModificadoPor = p_fiUsuarioId
  WHERE fiId = p_fiId;
  COMMIT;

  SELECT 200 AS fiCodigo,
         IF(IFNULL(p_fbActivo, 0) = 1, 'Plan activado correctamente', 'Plan desactivado correctamente') AS fcMensaje,
         1 AS fbSucces,
         JSON_OBJECT('planpreventivo', p_fiId, 'activo', IF(IFNULL(p_fbActivo, 0) = 1, 1, 0)) AS fjData;
END$$

DELIMITER ;
