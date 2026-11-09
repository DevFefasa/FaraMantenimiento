-- 21_sp_ticket_crear.sql
SET NAMES utf8mb4;
DROP PROCEDURE IF EXISTS sp_ticket_crear;
DELIMITER $$
CREATE PROCEDURE sp_ticket_crear(
  IN p_fiUsuarioId INT,
  IN p_fiSucursalId INT,
  IN p_fiUbicacionId INT,
  IN p_fcUbicacionDetalle VARCHAR(250),
  IN p_fiActivoId INT,
  IN p_fiTipoMantenimientoId INT,
  IN p_fiCategoriaId INT,
  IN p_fiPrioridadId INT,
  IN p_fcDescripcion TEXT,
  IN p_fdFechaSugerida DATETIME
)
proc: BEGIN
  DECLARE v_prefijo VARCHAR(20) DEFAULT 'TK';
  DECLARE v_anio INT;
  DECLARE v_ult INT DEFAULT 0;
  DECLARE v_numero VARCHAR(30);
  DECLARE v_estadoId INT;
  DECLARE v_estadoCodigo VARCHAR(30);
  DECLARE v_requiereAprob TINYINT DEFAULT 1;
  DECLARE v_requiereFecha TINYINT DEFAULT 0;
  DECLARE v_horasResp INT;
  DECLARE v_horasSol INT;
  DECLARE v_diasReinc INT DEFAULT 90;
  DECLARE v_ticketId INT;
  DECLARE v_histId INT;
  DECLARE v_reincId INT;
  DECLARE v_nombre VARCHAR(150);
  DECLARE v_cargo VARCHAR(100);
  DECLARE v_correo VARCHAR(150);
  DECLARE v_tel VARCHAR(40);
  DECLARE v_limResp DATETIME;
  DECLARE v_limSol DATETIME;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al crear el ticket' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  IF p_fiUsuarioId IS NULL OR p_fiUsuarioId <= 0 THEN
    SELECT 400 AS fiCodigo, 'El solicitante es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM usuario WHERE fiId = p_fiUsuarioId AND fbActivo = 1) THEN
    SELECT 404 AS fiCodigo, 'El solicitante no existe o está inactivo' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF p_fiSucursalId IS NULL OR p_fiSucursalId <= 0 OR NOT EXISTS (SELECT 1 FROM sucursal WHERE fiId = p_fiSucursalId AND fbActivo = 1) THEN
    SELECT 400 AS fiCodigo, 'La sucursal no es válida' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF p_fiTipoMantenimientoId IS NULL OR NOT EXISTS (SELECT 1 FROM tipomantenimiento WHERE fiId = p_fiTipoMantenimientoId AND fbActivo = 1) THEN
    SELECT 400 AS fiCodigo, 'El tipo de mantenimiento no es válido' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF p_fiCategoriaId IS NULL OR NOT EXISTS (SELECT 1 FROM categoria WHERE fiId = p_fiCategoriaId AND fbActivo = 1) THEN
    SELECT 400 AS fiCodigo, 'La categoría no es válida' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF p_fiPrioridadId IS NULL OR NOT EXISTS (SELECT 1 FROM prioridad WHERE fiId = p_fiPrioridadId AND fbActivo = 1) THEN
    SELECT 400 AS fiCodigo, 'La prioridad no es válida' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF TRIM(IFNULL(p_fcDescripcion,'')) = '' THEN
    SELECT 400 AS fiCodigo, 'La descripción es obligatoria' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
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

  SELECT fbRequiereAprobacion, fbRequiereFechaSugerida INTO v_requiereAprob, v_requiereFecha
  FROM tipomantenimiento WHERE fiId = p_fiTipoMantenimientoId;

  IF v_requiereFecha = 1 AND p_fdFechaSugerida IS NULL THEN
    SELECT 400 AS fiCodigo, 'La fecha sugerida es obligatoria para este tipo' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;

  SELECT fiHorasRespuesta, fiHorasSolucion INTO v_horasResp, v_horasSol FROM prioridad WHERE fiId = p_fiPrioridadId;
  SELECT fcNombre, fcCargo, fcCorreo, fcTelefono INTO v_nombre, v_cargo, v_correo, v_tel FROM usuario WHERE fiId = p_fiUsuarioId;

  SELECT IFNULL(NULLIF(TRIM(fcValor),''),'TK') INTO v_prefijo FROM parametro WHERE fcClave = 'PREFIJO_TICKET' AND fbActivo = 1 LIMIT 1;
  SELECT CAST(IFNULL(NULLIF(TRIM(fcValor),''),'90') AS UNSIGNED) INTO v_diasReinc FROM parametro WHERE fcClave = 'DIAS_REINCIDENCIA' AND fbActivo = 1 LIMIT 1;

  IF v_requiereAprob = 0 THEN
    SET v_estadoCodigo = 'ASIGNADO';
  ELSE
    SET v_estadoCodigo = 'RECIBIDO';
  END IF;
  SELECT fiId INTO v_estadoId FROM estado WHERE fcCodigo = v_estadoCodigo AND fbActivo = 1 LIMIT 1;
  IF v_estadoId IS NULL THEN
    SELECT 500 AS fiCodigo, 'No está configurado el estado inicial del ticket' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;

  SET v_limResp = DATE_ADD(NOW(), INTERVAL v_horasResp HOUR);
  SET v_limSol = DATE_ADD(NOW(), INTERVAL v_horasSol HOUR);
  SET v_anio = YEAR(NOW());
  SET v_reincId = NULL;

  IF p_fiActivoId IS NOT NULL AND p_fiActivoId > 0 THEN
    SELECT t.fiId INTO v_reincId
    FROM ticket t
    WHERE t.fiActivoId = p_fiActivoId
      AND t.fiCategoriaId = p_fiCategoriaId
      AND t.fbActivo = 1
      AND t.fdFechaIngreso >= DATE_SUB(NOW(), INTERVAL v_diasReinc DAY)
    ORDER BY t.fdFechaIngreso DESC
    LIMIT 1;
  END IF;

  START TRANSACTION;

  INSERT INTO ticketsecuencia (fiAnio, fiUltimo)
  VALUES (v_anio, 0)
  ON DUPLICATE KEY UPDATE fiAnio = fiAnio;

  SELECT fiUltimo INTO v_ult FROM ticketsecuencia WHERE fiAnio = v_anio FOR UPDATE;
  SET v_ult = IFNULL(v_ult, 0) + 1;
  UPDATE ticketsecuencia SET fiUltimo = v_ult WHERE fiAnio = v_anio;
  SET v_numero = CONCAT(v_prefijo, '-', v_anio, '-', LPAD(v_ult, 6, '0'));

  INSERT INTO ticket (
    fcNumero, fdFechaIngreso, fiSolicitanteId, fcSolicitanteNombre, fcCargo, fcCorreo, fcTelefono,
    fiSucursalId, fiUbicacionId, fcUbicacionDetalle, fiActivoId, fiTipoMantenimientoId, fiCategoriaId, fiPrioridadId,
    fcDescripcion, fdFechaSugerida, fiEstadoId, fbReincidencia, fiTicketReincidenteId,
    fdLimiteRespuesta, fdLimiteSolucion, fiCreadoPor, fbActivo
  ) VALUES (
    v_numero, NOW(), p_fiUsuarioId, v_nombre, v_cargo, v_correo, v_tel,
    p_fiSucursalId,
    IF(p_fiUbicacionId IS NULL OR p_fiUbicacionId <= 0, NULL, p_fiUbicacionId),
    NULLIF(TRIM(p_fcUbicacionDetalle),''),
    IF(p_fiActivoId IS NULL OR p_fiActivoId <= 0, NULL, p_fiActivoId),
    p_fiTipoMantenimientoId, p_fiCategoriaId, p_fiPrioridadId,
    TRIM(p_fcDescripcion), p_fdFechaSugerida, v_estadoId,
    IF(v_reincId IS NULL, 0, 1), v_reincId,
    v_limResp, v_limSol, p_fiUsuarioId, 1
  );
  SET v_ticketId = LAST_INSERT_ID();

  INSERT INTO ticketestado (fiTicketId, fiEstadoAnteriorId, fiEstadoId, fcComentario, fiUsuarioId, fdFecha)
  VALUES (v_ticketId, NULL, v_estadoId, 'Ticket creado', p_fiUsuarioId, NOW());
  SET v_histId = LAST_INSERT_ID();

  COMMIT;

  SELECT 201 AS fiCodigo, 'Ticket creado correctamente' AS fcMensaje, 1 AS fbSucces,
         JSON_OBJECT('ticket', v_ticketId, 'ticketestado', JSON_ARRAY(v_histId), 'numero', v_numero, 'reincidencia', IF(v_reincId IS NULL, 0, 1)) AS fjData;
END$$
DELIMITER ;
