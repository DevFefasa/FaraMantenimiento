-- 97_usuario_ticket_area_departamento.sql
-- Callers: SeguridadRepositorio; TicketRepositorio.Crear; CatalogoRepositorio.ObtenerCombos; ReporteRepositorio.Param
-- API: sp_seguridad_usuario_*; sp_ticket_crear; sp_catalogo_combos; sp_reporte_* (+área/depto)
-- Schema: SELECT/UPDATE fiAreaId,fiDepartamentoId,fcAreaNombre,fcDepartamentoNombre
-- User instruction: "ajuste de los SP de usuario (listar/obtener/guardar, incluido el login...) y del SP de crear ticket para copiar área/departamento del solicitante" + filtro reportes
-- Confirm: no 97 previa; no borra sucursal AREA Oficina Central

SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_seguridad_usuario_listar;
DROP PROCEDURE IF EXISTS sp_seguridad_usuario_obtener;
DROP PROCEDURE IF EXISTS sp_seguridad_usuario_guardar;
DROP PROCEDURE IF EXISTS sp_seguridad_usuario_por_login;
DROP PROCEDURE IF EXISTS sp_seguridad_login_ad_alta;

DELIMITER $$

CREATE PROCEDURE sp_seguridad_usuario_listar(IN p_fbSoloActivos TINYINT)
BEGIN
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;
  SELECT u.fiId, u.fcUsuario, u.fcActiveDirectory, u.fcNombre, u.fcCargo, u.fcCorreo, u.fcTelefono,
         u.fiRolId, r.fcCodigo AS fcRolCodigo, r.fcNombre AS fcRolNombre,
         u.fiSucursalId, s.fcNombre AS fcSucursalNombre,
         u.fiAreaId, a.fcNombre AS fcAreaNombre,
         u.fiDepartamentoId, d.fcNombre AS fcDepartamentoNombre,
         u.fbEsLocal, u.fbDebeCambiarClave, u.fbActivo, u.fdUltimoAcceso, u.fdCreado, u.fdModificado,
         CASE WHEN u.fcClaveHash IS NULL OR u.fcClaveHash = '' THEN 0 ELSE 1 END AS fbTieneClave
  FROM usuario u
  INNER JOIN rol r ON r.fiId = u.fiRolId
  LEFT JOIN sucursal s ON s.fiId = u.fiSucursalId
  LEFT JOIN area a ON a.fiId = u.fiAreaId
  LEFT JOIN departamento d ON d.fiId = u.fiDepartamentoId
  WHERE (IFNULL(p_fbSoloActivos, 1) = 0 OR u.fbActivo = 1)
  ORDER BY u.fcNombre;
END$$

CREATE PROCEDURE sp_seguridad_usuario_obtener(IN p_fiId INT)
proc: BEGIN
  IF p_fiId IS NULL OR p_fiId <= 0 OR NOT EXISTS (SELECT 1 FROM usuario WHERE fiId = p_fiId) THEN
    SELECT 404 AS fiCodigo, 'El usuario no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('usuario', p_fiId) AS fjData;
  SELECT u.fiId, u.fcUsuario, u.fcActiveDirectory, u.fcNombre, u.fcCargo, u.fcCorreo, u.fcTelefono,
         u.fiRolId, r.fcCodigo AS fcRolCodigo, r.fcNombre AS fcRolNombre,
         u.fiSucursalId, s.fcNombre AS fcSucursalNombre,
         u.fiAreaId, a.fcNombre AS fcAreaNombre,
         u.fiDepartamentoId, d.fcNombre AS fcDepartamentoNombre,
         u.fbEsLocal, u.fbDebeCambiarClave, u.fbActivo, u.fdUltimoAcceso,
         u.fdCreado, u.fiCreadoPor, u.fdModificado, u.fiModificadoPor,
         CASE WHEN u.fcClaveHash IS NULL OR u.fcClaveHash = '' THEN 0 ELSE 1 END AS fbTieneClave
  FROM usuario u
  INNER JOIN rol r ON r.fiId = u.fiRolId
  LEFT JOIN sucursal s ON s.fiId = u.fiSucursalId
  LEFT JOIN area a ON a.fiId = u.fiAreaId
  LEFT JOIN departamento d ON d.fiId = u.fiDepartamentoId
  WHERE u.fiId = p_fiId;
END$$

CREATE PROCEDURE sp_seguridad_usuario_guardar(
  IN p_fiId INT,
  IN p_fcUsuario VARCHAR(100),
  IN p_fcActiveDirectory VARCHAR(100),
  IN p_fcNombre VARCHAR(150),
  IN p_fcCargo VARCHAR(100),
  IN p_fcCorreo VARCHAR(150),
  IN p_fcTelefono VARCHAR(40),
  IN p_fiRolId INT,
  IN p_fiSucursalId INT,
  IN p_fiAreaId INT,
  IN p_fiDepartamentoId INT,
  IN p_fbEsLocal TINYINT,
  IN p_fcClaveHash VARCHAR(128),
  IN p_fbDebeCambiarClave TINYINT,
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_id INT;
  DECLARE v_ad VARCHAR(100);
  DECLARE v_otroUsuario VARCHAR(100);
  DECLARE v_suc INT;
  DECLARE v_area INT;
  DECLARE v_depto INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al guardar el usuario' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  SET v_ad = NULLIF(TRIM(IFNULL(p_fcActiveDirectory,'')), '');
  SET v_suc = IF(p_fiSucursalId IS NULL OR p_fiSucursalId <= 0, NULL, p_fiSucursalId);
  SET v_area = IF(p_fiAreaId IS NULL OR p_fiAreaId <= 0, NULL, p_fiAreaId);
  SET v_depto = IF(p_fiDepartamentoId IS NULL OR p_fiDepartamentoId <= 0, NULL, p_fiDepartamentoId);

  IF TRIM(IFNULL(p_fcUsuario,'')) = '' THEN
    SELECT 400 AS fiCodigo, 'El usuario es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF TRIM(IFNULL(p_fcNombre,'')) = '' THEN
    SELECT 400 AS fiCodigo, 'El nombre es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF p_fiRolId IS NULL OR p_fiRolId <= 0 OR NOT EXISTS (SELECT 1 FROM rol WHERE fiId = p_fiRolId AND fbActivo = 1) THEN
    SELECT 400 AS fiCodigo, 'El rol no es válido' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF v_suc IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sucursal WHERE fiId = v_suc AND fbActivo = 1) THEN
    SELECT 400 AS fiCodigo, 'La sucursal no es válida' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF v_area IS NOT NULL AND NOT EXISTS (SELECT 1 FROM area WHERE fiId = v_area AND fbActivo = 1) THEN
    SELECT 400 AS fiCodigo, 'El área no es válida' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF v_depto IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM departamento WHERE fiId = v_depto AND fbActivo = 1) THEN
      SELECT 400 AS fiCodigo, 'El departamento no es válido' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
    IF v_area IS NULL OR NOT EXISTS (SELECT 1 FROM departamento WHERE fiId = v_depto AND fiAreaId = v_area) THEN
      SELECT 400 AS fiCodigo, 'El departamento no pertenece al área seleccionada' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
    END IF;
  END IF;

  IF v_ad IS NOT NULL THEN
    SELECT fcUsuario INTO v_otroUsuario
    FROM usuario
    WHERE LOWER(fcActiveDirectory) = LOWER(v_ad)
      AND (p_fiId IS NULL OR p_fiId <= 0 OR fiId <> p_fiId)
    LIMIT 1;
    IF v_otroUsuario IS NOT NULL THEN
      SELECT 409 AS fiCodigo,
             CONCAT('El usuario de AD ', v_ad, ' ya está vinculado a ', v_otroUsuario) AS fcMensaje,
             0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
  END IF;

  START TRANSACTION;
  IF p_fiId IS NULL OR p_fiId <= 0 THEN
    IF EXISTS (SELECT 1 FROM usuario WHERE LOWER(fcUsuario) = LOWER(TRIM(p_fcUsuario))) THEN
      ROLLBACK;
      SELECT 409 AS fiCodigo, 'Ya existe un usuario con ese nombre' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
    INSERT INTO usuario (fcUsuario, fcActiveDirectory, fcNombre, fcCargo, fcCorreo, fcTelefono, fiRolId, fiSucursalId, fiAreaId, fiDepartamentoId, fbEsLocal, fcClaveHash, fbDebeCambiarClave, fiCreadoPor, fbActivo)
    VALUES (
      TRIM(p_fcUsuario), v_ad, TRIM(p_fcNombre), NULLIF(TRIM(p_fcCargo),''), NULLIF(TRIM(p_fcCorreo),''), NULLIF(TRIM(p_fcTelefono),''),
      p_fiRolId, v_suc, v_area, v_depto,
      IF(IFNULL(p_fbEsLocal,0)=1,1,0),
      NULLIF(TRIM(p_fcClaveHash),''),
      IF(IFNULL(p_fbDebeCambiarClave,0)=1,1,0),
      p_fiUsuarioId, 1
    );
    SET v_id = LAST_INSERT_ID();
    COMMIT;
    SELECT 201 AS fiCodigo, 'Usuario creado correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('usuario', v_id) AS fjData;
  ELSE
    IF NOT EXISTS (SELECT 1 FROM usuario WHERE fiId = p_fiId) THEN
      ROLLBACK;
      SELECT 404 AS fiCodigo, 'El usuario no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
    IF EXISTS (SELECT 1 FROM usuario WHERE LOWER(fcUsuario) = LOWER(TRIM(p_fcUsuario)) AND fiId <> p_fiId) THEN
      ROLLBACK;
      SELECT 409 AS fiCodigo, 'Ya existe un usuario con ese nombre' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
    UPDATE usuario SET
      fcUsuario = TRIM(p_fcUsuario),
      fcActiveDirectory = v_ad,
      fcNombre = TRIM(p_fcNombre),
      fcCargo = IF(p_fcCargo IS NULL, fcCargo, NULLIF(TRIM(p_fcCargo),'')),
      fcCorreo = NULLIF(TRIM(p_fcCorreo),''),
      fcTelefono = NULLIF(TRIM(p_fcTelefono),''),
      fiRolId = p_fiRolId,
      fiSucursalId = v_suc,
      fiAreaId = v_area,
      fiDepartamentoId = v_depto,
      fbEsLocal = IF(NULLIF(TRIM(p_fcClaveHash),'') IS NOT NULL, 1, fbEsLocal),
      fcClaveHash = IF(NULLIF(TRIM(p_fcClaveHash),'') IS NULL, fcClaveHash, TRIM(p_fcClaveHash)),
      fbDebeCambiarClave = IF(p_fbDebeCambiarClave IS NULL, fbDebeCambiarClave, IF(p_fbDebeCambiarClave=1,1,0)),
      fdModificado = NOW(),
      fiModificadoPor = p_fiUsuarioId
    WHERE fiId = p_fiId;
    SET v_id = p_fiId;
    COMMIT;
    SELECT 200 AS fiCodigo, 'Usuario guardado correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('usuario', v_id) AS fjData;
  END IF;
END$$

CREATE PROCEDURE sp_seguridad_usuario_por_login(IN p_fcUsuario VARCHAR(100))
proc: BEGIN
  DECLARE v_id INT;
  DECLARE v_campo VARCHAR(30);
  DECLARE v_login VARCHAR(100);

  IF TRIM(IFNULL(p_fcUsuario,'')) = '' THEN
    SELECT 400 AS fiCodigo, 'El usuario es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  SET v_login = TRIM(p_fcUsuario);

  SELECT u.fiId, 'fcUsuario' INTO v_id, v_campo
  FROM usuario u
  WHERE LOWER(u.fcUsuario) = LOWER(v_login) AND u.fbActivo = 1
  LIMIT 1;

  IF v_id IS NULL THEN
    SELECT u.fiId, 'fcActiveDirectory' INTO v_id, v_campo
    FROM usuario u
    WHERE u.fcActiveDirectory IS NOT NULL
      AND LOWER(u.fcActiveDirectory) = LOWER(v_login)
      AND u.fbActivo = 1
    LIMIT 1;
  END IF;

  IF v_id IS NULL THEN
    SELECT 404 AS fiCodigo, 'Usuario no encontrado o inactivo' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces,
         JSON_OBJECT('usuario', v_id, 'fcCampoCoincide', v_campo) AS fjData;
  SELECT u.fiId, u.fcUsuario, u.fcActiveDirectory, u.fcNombre, u.fcCargo, u.fcCorreo, u.fcTelefono,
         u.fiRolId, r.fcCodigo AS fcRolCodigo, r.fcNombre AS fcRolNombre,
         u.fiSucursalId, u.fiAreaId, u.fiDepartamentoId,
         u.fbEsLocal, u.fcClaveHash, u.fbDebeCambiarClave, u.fbActivo, u.fdUltimoAcceso,
         v_campo AS fcCampoCoincide
  FROM usuario u
  INNER JOIN rol r ON r.fiId = u.fiRolId
  WHERE u.fiId = v_id;
END$$

CREATE PROCEDURE sp_seguridad_login_ad_alta(
  IN p_fcUsuario VARCHAR(100),
  IN p_fcNombre VARCHAR(150),
  IN p_fcCorreo VARCHAR(150),
  IN p_fcCargo VARCHAR(100),
  IN p_fcTelefono VARCHAR(40)
)
proc: BEGIN
  DECLARE v_id INT;
  DECLARE v_rolId INT;
  DECLARE v_ad VARCHAR(100);
  DECLARE v_localAd VARCHAR(100);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al registrar el usuario de dominio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  IF TRIM(IFNULL(p_fcUsuario,'')) = '' THEN
    SELECT 400 AS fiCodigo, 'El usuario es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  SET v_ad = TRIM(p_fcUsuario);

  SELECT fiId INTO v_id
  FROM usuario
  WHERE fcActiveDirectory IS NOT NULL AND LOWER(fcActiveDirectory) = LOWER(v_ad)
  LIMIT 1;

  IF v_id IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM usuario WHERE fiId = v_id AND fbActivo = 0) THEN
      SELECT 403 AS fiCodigo, 'El usuario está inactivo' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
      LEAVE proc;
    END IF;
    UPDATE usuario
    SET fcNombre = IFNULL(NULLIF(TRIM(p_fcNombre),''), fcNombre),
        fcCorreo = IFNULL(NULLIF(TRIM(p_fcCorreo),''), fcCorreo),
        fcCargo = IFNULL(NULLIF(TRIM(p_fcCargo),''), fcCargo),
        fcTelefono = IFNULL(NULLIF(TRIM(p_fcTelefono),''), fcTelefono),
        fdUltimoAcceso = NOW()
    WHERE fiId = v_id;
    SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('usuario', v_id) AS fjData;
    SELECT u.fiId, u.fcUsuario, u.fcActiveDirectory, u.fcNombre, u.fcCargo, u.fcCorreo, u.fcTelefono,
           u.fiRolId, r.fcCodigo AS fcRolCodigo, r.fcNombre AS fcRolNombre,
           u.fiSucursalId, u.fiAreaId, u.fiDepartamentoId,
           u.fbEsLocal, u.fcClaveHash, u.fbDebeCambiarClave, u.fbActivo, u.fdUltimoAcceso
    FROM usuario u INNER JOIN rol r ON r.fiId = u.fiRolId WHERE u.fiId = v_id;
    LEAVE proc;
  END IF;

  SELECT fiId, fcActiveDirectory INTO v_id, v_localAd
  FROM usuario
  WHERE LOWER(fcUsuario) = LOWER(v_ad)
  LIMIT 1;

  IF v_id IS NOT NULL THEN
    SELECT 409 AS fiCodigo,
           'Existe un usuario local con ese nombre; vincúlelo desde Seguridad' AS fcMensaje,
           0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  SELECT fiId INTO v_rolId FROM rol WHERE fcCodigo = 'SOLICITANTE' AND fbActivo = 1 LIMIT 1;
  IF v_rolId IS NULL THEN
    SELECT 500 AS fiCodigo, 'No está configurado el rol solicitante' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  START TRANSACTION;
  INSERT INTO usuario (fcUsuario, fcActiveDirectory, fcNombre, fcCargo, fcCorreo, fcTelefono, fiRolId, fbEsLocal, fcClaveHash, fbActivo, fdUltimoAcceso)
  VALUES (
    v_ad, v_ad,
    IFNULL(NULLIF(TRIM(p_fcNombre),''), v_ad),
    NULLIF(TRIM(p_fcCargo),''),
    NULLIF(TRIM(p_fcCorreo),''),
    NULLIF(TRIM(p_fcTelefono),''),
    v_rolId, 0, NULL, 1, NOW()
  );
  SET v_id = LAST_INSERT_ID();
  COMMIT;

  SELECT 201 AS fiCodigo, 'Usuario de dominio registrado' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('usuario', v_id) AS fjData;
  SELECT u.fiId, u.fcUsuario, u.fcActiveDirectory, u.fcNombre, u.fcCargo, u.fcCorreo, u.fcTelefono,
         u.fiRolId, r.fcCodigo AS fcRolCodigo, r.fcNombre AS fcRolNombre,
         u.fiSucursalId, u.fiAreaId, u.fiDepartamentoId,
         u.fbEsLocal, u.fcClaveHash, u.fbDebeCambiarClave, u.fbActivo, u.fdUltimoAcceso
  FROM usuario u INNER JOIN rol r ON r.fiId = u.fiRolId WHERE u.fiId = v_id;
END$$

DELIMITER ;

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
  DECLARE v_areaId INT;
  DECLARE v_deptoId INT;
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
  SELECT fcNombre, fcCargo, fcCorreo, fcTelefono, fiAreaId, fiDepartamentoId
  INTO v_nombre, v_cargo, v_correo, v_tel, v_areaId, v_deptoId
  FROM usuario WHERE fiId = p_fiUsuarioId;

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
    INNER JOIN estado e ON e.fiId = t.fiEstadoId
    WHERE t.fiActivoId = p_fiActivoId
      AND t.fiCategoriaId = p_fiCategoriaId
      AND t.fbActivo = 1
      AND e.fcCodigo <> 'RECHAZADO'
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
    fiSucursalId, fiAreaId, fiDepartamentoId, fiUbicacionId, fcUbicacionDetalle, fiActivoId, fiTipoMantenimientoId, fiCategoriaId, fiPrioridadId,
    fcDescripcion, fdFechaSugerida, fiEstadoId, fbReincidencia, fiTicketReincidenteId,
    fdLimiteRespuesta, fdLimiteSolucion, fiCreadoPor, fbActivo
  ) VALUES (
    v_numero, NOW(), p_fiUsuarioId, v_nombre, v_cargo, v_correo, v_tel,
    p_fiSucursalId, v_areaId, v_deptoId,
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

-- Combos: añade Areas y Departamentos al final (result sets 13-14)
SET NAMES utf8mb4;
DROP PROCEDURE IF EXISTS sp_catalogo_combos;
DELIMITER $$
CREATE PROCEDURE sp_catalogo_combos()
BEGIN
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;
  SELECT r.fiId, r.fcCodigo, r.fcNombre FROM region r WHERE r.fbActivo = 1 ORDER BY r.fcNombre;
  SELECT s.fiId, s.fcCodigo, s.fcNombre, s.fcTipo, s.fiRegionId FROM sucursal s WHERE s.fbActivo = 1 ORDER BY s.fcNombre;
  SELECT u.fiId, u.fcCodigo, u.fcNombre, u.fiSucursalId FROM ubicacion u WHERE u.fbActivo = 1 ORDER BY u.fcNombre;
  SELECT a.fiId, a.fcCodigo, a.fcNombre, a.fiSucursalId, a.fiUbicacionId, a.fiCategoriaId FROM activo a WHERE a.fbActivo = 1 ORDER BY a.fcNombre;
  SELECT t.fiId, t.fcCodigo, t.fcNombre, t.fbRequiereAprobacion, t.fbEsPreventivo, t.fbEsPostFalla, t.fbRequiereFechaSugerida, t.fiOrden
  FROM tipomantenimiento t WHERE t.fbActivo = 1 ORDER BY t.fiOrden, t.fcNombre;
  SELECT c.fiId, c.fcCodigo, c.fcNombre, c.fiOrden FROM categoria c WHERE c.fbActivo = 1 ORDER BY c.fiOrden, c.fcNombre;
  SELECT p.fiId, p.fcCodigo, p.fcNombre, p.fiHorasRespuesta, p.fiHorasSolucion, p.fcColor, p.fiOrden FROM prioridad p WHERE p.fbActivo = 1 ORDER BY p.fiOrden, p.fcNombre;
  SELECT e.fiId, e.fcCodigo, e.fcNombre, e.fiOrden, e.fcColor, e.fbFinal FROM estado e WHERE e.fbActivo = 1 ORDER BY e.fiOrden, e.fcNombre;
  SELECT m.fiId, m.fcCodigo, m.fcNombre, m.fiOrden FROM motivoespera m WHERE m.fbActivo = 1 ORDER BY m.fiOrden, m.fcNombre;
  SELECT pr.fiId, pr.fcCodigo, pr.fcNombre, pr.fcEspecialidad FROM proveedor pr WHERE pr.fbActivo = 1 ORDER BY pr.fcNombre;
  SELECT te.fiId, te.fcCodigo, te.fcNombre, te.fiCategoriaId, te.fcTelefono FROM tecnico te WHERE te.fbActivo = 1 ORDER BY te.fcNombre;
  SELECT ar.fiId, ar.fcCodigo, ar.fcNombre FROM area ar WHERE ar.fbActivo = 1 ORDER BY ar.fcNombre;
  SELECT d.fiId, d.fcCodigo, d.fcNombre, d.fiAreaId FROM departamento d WHERE d.fbActivo = 1 ORDER BY d.fcNombre;
END$$
DELIMITER ;

-- Reportes: filtros área/departamento
-- 40_sp_reporte_resumen.sql
-- Callers: ReporteRepositorio.ResumenAsync / Dashboard
-- Filtros: fecha, sucursal, región, tipo, categoría, prioridad, estado, técnico, proveedor
-- Aplicar: docker exec -i MariaLocal sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" faramantenimiento' < db/migrations/40_sp_reporte_resumen.sql

SET NAMES utf8mb4;
DROP PROCEDURE IF EXISTS sp_reporte_resumen;
DELIMITER $$
CREATE PROCEDURE sp_reporte_resumen(
  IN p_fdDesde DATETIME,
  IN p_fdHasta DATETIME,
  IN p_fiSucursalId INT,
  IN p_fiRegionId INT,
  IN p_fiTipoMantenimientoId INT,
  IN p_fiCategoriaId INT,
  IN p_fiPrioridadId INT,
  IN p_fiEstadoId INT,
  IN p_fiTecnicoId INT,
  IN p_fiProveedorId INT,
  IN p_fiAreaId INT,
  IN p_fiDepartamentoId INT
)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    SELECT 500 AS fiCodigo, 'Ocurrió un error al consultar el resumen' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;

  SELECT
    COUNT(*) AS fiRecibidos,
    SUM(CASE WHEN e.fbFinal = 0 THEN 1 ELSE 0 END) AS fiAbiertos,
    SUM(CASE WHEN e.fcCodigo IN ('CERRADO','VALIDADO') THEN 1 ELSE 0 END) AS fiCerrados,
    SUM(CASE WHEN e.fbFinal = 0 THEN 1 ELSE 0 END) AS fiBacklog,
    SUM(CASE WHEN t.fbReincidencia = 1 THEN 1 ELSE 0 END) AS fiReincidentes,
    ROUND(AVG(
      CASE WHEN t.fdPrimeraRespuesta IS NOT NULL
        THEN TIMESTAMPDIFF(MINUTE, t.fdFechaIngreso, t.fdPrimeraRespuesta) / 60.0
      END
    ), 2) AS fnHorasRespuestaPromedio,
    ROUND(AVG(
      CASE WHEN t.fdResuelto IS NOT NULL
        THEN GREATEST(0, TIMESTAMPDIFF(MINUTE, t.fdFechaIngreso, t.fdResuelto) - IFNULL(t.fiMinutosEnEspera, 0)) / 60.0
      END
    ), 2) AS fnHorasSolucionPromedio,
    ROUND(
      100.0 * SUM(CASE WHEN t.fbSlaSolucionCumplido = 1 THEN 1 ELSE 0 END)
      / NULLIF(SUM(CASE WHEN t.fbSlaSolucionCumplido IS NOT NULL THEN 1 ELSE 0 END), 0)
    , 2) AS fnPctSlaSolucion,
    ROUND(AVG(CASE WHEN en.fiCalificacion IS NOT NULL THEN en.fiCalificacion END), 2) AS fnSatisfaccionPromedio
  FROM ticket t
  INNER JOIN sucursal s ON s.fiId = t.fiSucursalId
  INNER JOIN estado e ON e.fiId = t.fiEstadoId
  LEFT JOIN ticketencuesta en ON en.fiTicketId = t.fiId
  WHERE t.fbActivo = 1
    AND (p_fdDesde IS NULL OR t.fdFechaIngreso >= p_fdDesde)
    AND (p_fdHasta IS NULL OR t.fdFechaIngreso < DATE_ADD(DATE(p_fdHasta), INTERVAL 1 DAY))
    AND (p_fiSucursalId IS NULL OR t.fiSucursalId = p_fiSucursalId)
    AND (p_fiRegionId IS NULL OR s.fiRegionId = p_fiRegionId)
    AND (p_fiTipoMantenimientoId IS NULL OR t.fiTipoMantenimientoId = p_fiTipoMantenimientoId)
    AND (p_fiCategoriaId IS NULL OR t.fiCategoriaId = p_fiCategoriaId)
    AND (p_fiPrioridadId IS NULL OR t.fiPrioridadId = p_fiPrioridadId)
    AND (p_fiEstadoId IS NULL OR t.fiEstadoId = p_fiEstadoId)
    AND (p_fiTecnicoId IS NULL OR t.fiTecnicoId = p_fiTecnicoId)
    AND (p_fiProveedorId IS NULL OR t.fiProveedorId = p_fiProveedorId)
    AND (p_fiAreaId IS NULL OR p_fiAreaId <= 0 OR t.fiAreaId = p_fiAreaId)
    AND (p_fiDepartamentoId IS NULL OR p_fiDepartamentoId <= 0 OR t.fiDepartamentoId = p_fiDepartamentoId);
END$$
DELIMITER ;


-- 41_sp_reporte_tiempos.sql
SET NAMES utf8mb4;
DROP PROCEDURE IF EXISTS sp_reporte_tiempos;
DELIMITER $$
CREATE PROCEDURE sp_reporte_tiempos(
  IN p_fdDesde DATETIME, IN p_fdHasta DATETIME, IN p_fiSucursalId INT, IN p_fiRegionId INT,
  IN p_fiTipoMantenimientoId INT, IN p_fiCategoriaId INT, IN p_fiPrioridadId INT, IN p_fiEstadoId INT,
  IN p_fiTecnicoId INT, IN p_fiProveedorId INT, IN p_fiAreaId INT, IN p_fiDepartamentoId INT
)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN SELECT 500 AS fiCodigo, 'Ocurrió un error al consultar tiempos' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;

  SELECT
    p.fcCodigo AS fcPrioridadCodigo,
    p.fcNombre AS fcPrioridadNombre,
    COUNT(*) AS fiTickets,
    ROUND(AVG(CASE WHEN t.fdPrimeraRespuesta IS NOT NULL
      THEN TIMESTAMPDIFF(MINUTE, t.fdFechaIngreso, t.fdPrimeraRespuesta) / 60.0 END), 2) AS fnHorasRespuestaPromedio,
    ROUND(AVG(CASE WHEN t.fdResuelto IS NOT NULL
      THEN GREATEST(0, TIMESTAMPDIFF(MINUTE, t.fdFechaIngreso, t.fdResuelto) - IFNULL(t.fiMinutosEnEspera,0)) / 60.0 END), 2) AS fnHorasSolucionPromedio,
    ROUND(AVG(CASE WHEN t.fdResuelto IS NOT NULL
      THEN GREATEST(0, TIMESTAMPDIFF(MINUTE, t.fdFechaIngreso, t.fdResuelto) - IFNULL(t.fiMinutosEnEspera,0)) / 60.0 END), 2) AS fnMttrHoras
  FROM ticket t
  INNER JOIN sucursal s ON s.fiId = t.fiSucursalId
  INNER JOIN prioridad p ON p.fiId = t.fiPrioridadId
  WHERE t.fbActivo = 1
    AND (p_fdDesde IS NULL OR t.fdFechaIngreso >= p_fdDesde)
    AND (p_fdHasta IS NULL OR t.fdFechaIngreso < DATE_ADD(DATE(p_fdHasta), INTERVAL 1 DAY))
    AND (p_fiSucursalId IS NULL OR t.fiSucursalId = p_fiSucursalId)
    AND (p_fiRegionId IS NULL OR s.fiRegionId = p_fiRegionId)
    AND (p_fiTipoMantenimientoId IS NULL OR t.fiTipoMantenimientoId = p_fiTipoMantenimientoId)
    AND (p_fiCategoriaId IS NULL OR t.fiCategoriaId = p_fiCategoriaId)
    AND (p_fiPrioridadId IS NULL OR t.fiPrioridadId = p_fiPrioridadId)
    AND (p_fiEstadoId IS NULL OR t.fiEstadoId = p_fiEstadoId)
    AND (p_fiTecnicoId IS NULL OR t.fiTecnicoId = p_fiTecnicoId)
    AND (p_fiProveedorId IS NULL OR t.fiProveedorId = p_fiProveedorId)
    AND (p_fiAreaId IS NULL OR p_fiAreaId <= 0 OR t.fiAreaId = p_fiAreaId)
    AND (p_fiDepartamentoId IS NULL OR p_fiDepartamentoId <= 0 OR t.fiDepartamentoId = p_fiDepartamentoId)
  GROUP BY p.fiId, p.fcCodigo, p.fcNombre, p.fiOrden
  ORDER BY p.fiOrden;
END$$
DELIMITER ;


-- 42_sp_reporte_sla.sql
SET NAMES utf8mb4;
DROP PROCEDURE IF EXISTS sp_reporte_sla;
DELIMITER $$
CREATE PROCEDURE sp_reporte_sla(
  IN p_fdDesde DATETIME, IN p_fdHasta DATETIME, IN p_fiSucursalId INT, IN p_fiRegionId INT,
  IN p_fiTipoMantenimientoId INT, IN p_fiCategoriaId INT, IN p_fiPrioridadId INT, IN p_fiEstadoId INT,
  IN p_fiTecnicoId INT, IN p_fiProveedorId INT, IN p_fiAreaId INT, IN p_fiDepartamentoId INT
)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN SELECT 500 AS fiCodigo, 'Ocurrió un error al consultar SLA' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;

  SELECT
    p.fcCodigo AS fcPrioridadCodigo,
    p.fcNombre AS fcPrioridadNombre,
    COUNT(*) AS fiTickets,
    SUM(CASE WHEN t.fbSlaRespuestaCumplido = 1 THEN 1 ELSE 0 END) AS fiSlaRespuestaOk,
    SUM(CASE WHEN t.fbSlaRespuestaCumplido = 0 THEN 1 ELSE 0 END) AS fiSlaRespuestaNo,
    ROUND(100.0 * SUM(CASE WHEN t.fbSlaRespuestaCumplido = 1 THEN 1 ELSE 0 END)
      / NULLIF(SUM(CASE WHEN t.fbSlaRespuestaCumplido IS NOT NULL THEN 1 ELSE 0 END), 0), 2) AS fnPctSlaRespuesta,
    SUM(CASE WHEN t.fbSlaSolucionCumplido = 1 THEN 1 ELSE 0 END) AS fiSlaSolucionOk,
    SUM(CASE WHEN t.fbSlaSolucionCumplido = 0 THEN 1 ELSE 0 END) AS fiSlaSolucionNo,
    ROUND(100.0 * SUM(CASE WHEN t.fbSlaSolucionCumplido = 1 THEN 1 ELSE 0 END)
      / NULLIF(SUM(CASE WHEN t.fbSlaSolucionCumplido IS NOT NULL THEN 1 ELSE 0 END), 0), 2) AS fnPctSlaSolucion
  FROM ticket t
  INNER JOIN sucursal s ON s.fiId = t.fiSucursalId
  INNER JOIN prioridad p ON p.fiId = t.fiPrioridadId
  WHERE t.fbActivo = 1
    AND (p_fdDesde IS NULL OR t.fdFechaIngreso >= p_fdDesde)
    AND (p_fdHasta IS NULL OR t.fdFechaIngreso < DATE_ADD(DATE(p_fdHasta), INTERVAL 1 DAY))
    AND (p_fiSucursalId IS NULL OR t.fiSucursalId = p_fiSucursalId)
    AND (p_fiRegionId IS NULL OR s.fiRegionId = p_fiRegionId)
    AND (p_fiTipoMantenimientoId IS NULL OR t.fiTipoMantenimientoId = p_fiTipoMantenimientoId)
    AND (p_fiCategoriaId IS NULL OR t.fiCategoriaId = p_fiCategoriaId)
    AND (p_fiPrioridadId IS NULL OR t.fiPrioridadId = p_fiPrioridadId)
    AND (p_fiEstadoId IS NULL OR t.fiEstadoId = p_fiEstadoId)
    AND (p_fiTecnicoId IS NULL OR t.fiTecnicoId = p_fiTecnicoId)
    AND (p_fiProveedorId IS NULL OR t.fiProveedorId = p_fiProveedorId)
    AND (p_fiAreaId IS NULL OR p_fiAreaId <= 0 OR t.fiAreaId = p_fiAreaId)
    AND (p_fiDepartamentoId IS NULL OR p_fiDepartamentoId <= 0 OR t.fiDepartamentoId = p_fiDepartamentoId)
  GROUP BY p.fiId, p.fcCodigo, p.fcNombre, p.fiOrden
  ORDER BY p.fiOrden;
END$$
DELIMITER ;


-- 43_sp_reporte_tipo.sql (preventivo vs correctivo)
SET NAMES utf8mb4;
DROP PROCEDURE IF EXISTS sp_reporte_tipo;
DELIMITER $$
CREATE PROCEDURE sp_reporte_tipo(
  IN p_fdDesde DATETIME, IN p_fdHasta DATETIME, IN p_fiSucursalId INT, IN p_fiRegionId INT,
  IN p_fiTipoMantenimientoId INT, IN p_fiCategoriaId INT, IN p_fiPrioridadId INT, IN p_fiEstadoId INT,
  IN p_fiTecnicoId INT, IN p_fiProveedorId INT, IN p_fiAreaId INT, IN p_fiDepartamentoId INT
)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN SELECT 500 AS fiCodigo, 'Ocurrió un error al consultar tipos' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;

  SELECT
    tm.fcCodigo AS fcTipoCodigo,
    tm.fcNombre AS fcTipoNombre,
    tm.fbEsPreventivo,
    COUNT(*) AS fiTickets,
    ROUND(100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0), 2) AS fnPorcentaje
  FROM ticket t
  INNER JOIN sucursal s ON s.fiId = t.fiSucursalId
  INNER JOIN tipomantenimiento tm ON tm.fiId = t.fiTipoMantenimientoId
  WHERE t.fbActivo = 1
    AND (p_fdDesde IS NULL OR t.fdFechaIngreso >= p_fdDesde)
    AND (p_fdHasta IS NULL OR t.fdFechaIngreso < DATE_ADD(DATE(p_fdHasta), INTERVAL 1 DAY))
    AND (p_fiSucursalId IS NULL OR t.fiSucursalId = p_fiSucursalId)
    AND (p_fiRegionId IS NULL OR s.fiRegionId = p_fiRegionId)
    AND (p_fiTipoMantenimientoId IS NULL OR t.fiTipoMantenimientoId = p_fiTipoMantenimientoId)
    AND (p_fiCategoriaId IS NULL OR t.fiCategoriaId = p_fiCategoriaId)
    AND (p_fiPrioridadId IS NULL OR t.fiPrioridadId = p_fiPrioridadId)
    AND (p_fiEstadoId IS NULL OR t.fiEstadoId = p_fiEstadoId)
    AND (p_fiTecnicoId IS NULL OR t.fiTecnicoId = p_fiTecnicoId)
    AND (p_fiProveedorId IS NULL OR t.fiProveedorId = p_fiProveedorId)
    AND (p_fiAreaId IS NULL OR p_fiAreaId <= 0 OR t.fiAreaId = p_fiAreaId)
    AND (p_fiDepartamentoId IS NULL OR p_fiDepartamentoId <= 0 OR t.fiDepartamentoId = p_fiDepartamentoId)
  GROUP BY tm.fiId, tm.fcCodigo, tm.fcNombre, tm.fbEsPreventivo, tm.fiOrden
  ORDER BY tm.fiOrden;
END$$
DELIMITER ;


-- 51_sp_reporte_mtbf_activo_id.sql (recrea sp_reporte_mtbf con fiActivoId)
SET NAMES utf8mb4;
DROP PROCEDURE IF EXISTS sp_reporte_mtbf;
DELIMITER $$
CREATE PROCEDURE sp_reporte_mtbf(
  IN p_fdDesde DATETIME, IN p_fdHasta DATETIME, IN p_fiSucursalId INT, IN p_fiRegionId INT,
  IN p_fiTipoMantenimientoId INT, IN p_fiCategoriaId INT, IN p_fiPrioridadId INT, IN p_fiEstadoId INT,
  IN p_fiTecnicoId INT, IN p_fiProveedorId INT, IN p_fiAreaId INT, IN p_fiDepartamentoId INT
)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN SELECT 500 AS fiCodigo, 'Ocurrió un error al consultar MTBF' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;

  SELECT
    'ACTIVO' AS fcAgrupacion,
    a.fiId AS fiActivoId,
    IFNULL(a.fcCodigo, 'SIN_ACTIVO') AS fcCodigo,
    IFNULL(a.fcNombre, 'Sin activo') AS fcNombre,
    s.fcNombre AS fcSucursalNombre,
    COUNT(*) AS fiFallos,
    ROUND(
      CASE WHEN COUNT(*) <= 1 THEN NULL
      ELSE TIMESTAMPDIFF(HOUR, MIN(t.fdFechaIngreso), MAX(t.fdFechaIngreso)) / NULLIF(COUNT(*) - 1, 0)
      END
    , 2) AS fnMtbfHoras
  FROM ticket t
  INNER JOIN sucursal s ON s.fiId = t.fiSucursalId
  INNER JOIN tipomantenimiento tm ON tm.fiId = t.fiTipoMantenimientoId
  LEFT JOIN activo a ON a.fiId = t.fiActivoId
  WHERE t.fbActivo = 1
    AND tm.fbEsPreventivo = 0
    AND (p_fdDesde IS NULL OR t.fdFechaIngreso >= p_fdDesde)
    AND (p_fdHasta IS NULL OR t.fdFechaIngreso < DATE_ADD(DATE(p_fdHasta), INTERVAL 1 DAY))
    AND (p_fiSucursalId IS NULL OR t.fiSucursalId = p_fiSucursalId)
    AND (p_fiRegionId IS NULL OR s.fiRegionId = p_fiRegionId)
    AND (p_fiTipoMantenimientoId IS NULL OR t.fiTipoMantenimientoId = p_fiTipoMantenimientoId)
    AND (p_fiCategoriaId IS NULL OR t.fiCategoriaId = p_fiCategoriaId)
    AND (p_fiPrioridadId IS NULL OR t.fiPrioridadId = p_fiPrioridadId)
    AND (p_fiEstadoId IS NULL OR t.fiEstadoId = p_fiEstadoId)
    AND (p_fiTecnicoId IS NULL OR t.fiTecnicoId = p_fiTecnicoId)
    AND (p_fiProveedorId IS NULL OR t.fiProveedorId = p_fiProveedorId)
    AND (p_fiAreaId IS NULL OR p_fiAreaId <= 0 OR t.fiAreaId = p_fiAreaId)
    AND (p_fiDepartamentoId IS NULL OR p_fiDepartamentoId <= 0 OR t.fiDepartamentoId = p_fiDepartamentoId)
  GROUP BY a.fiId, a.fcCodigo, a.fcNombre, s.fcNombre
  HAVING COUNT(*) >= 1
  ORDER BY fiFallos DESC, fcNombre
  LIMIT 200;

  SELECT
    'SUCURSAL' AS fcAgrupacion,
    NULL AS fiActivoId,
    s.fcCodigo AS fcCodigo,
    s.fcNombre AS fcNombre,
    s.fcNombre AS fcSucursalNombre,
    COUNT(*) AS fiFallos,
    ROUND(
      CASE WHEN COUNT(*) <= 1 THEN NULL
      ELSE TIMESTAMPDIFF(HOUR, MIN(t.fdFechaIngreso), MAX(t.fdFechaIngreso)) / NULLIF(COUNT(*) - 1, 0)
      END
    , 2) AS fnMtbfHoras
  FROM ticket t
  INNER JOIN sucursal s ON s.fiId = t.fiSucursalId
  INNER JOIN tipomantenimiento tm ON tm.fiId = t.fiTipoMantenimientoId
  WHERE t.fbActivo = 1
    AND tm.fbEsPreventivo = 0
    AND (p_fdDesde IS NULL OR t.fdFechaIngreso >= p_fdDesde)
    AND (p_fdHasta IS NULL OR t.fdFechaIngreso < DATE_ADD(DATE(p_fdHasta), INTERVAL 1 DAY))
    AND (p_fiSucursalId IS NULL OR t.fiSucursalId = p_fiSucursalId)
    AND (p_fiRegionId IS NULL OR s.fiRegionId = p_fiRegionId)
    AND (p_fiTipoMantenimientoId IS NULL OR t.fiTipoMantenimientoId = p_fiTipoMantenimientoId)
    AND (p_fiCategoriaId IS NULL OR t.fiCategoriaId = p_fiCategoriaId)
    AND (p_fiPrioridadId IS NULL OR t.fiPrioridadId = p_fiPrioridadId)
    AND (p_fiEstadoId IS NULL OR t.fiEstadoId = p_fiEstadoId)
    AND (p_fiTecnicoId IS NULL OR t.fiTecnicoId = p_fiTecnicoId)
    AND (p_fiProveedorId IS NULL OR t.fiProveedorId = p_fiProveedorId)
    AND (p_fiAreaId IS NULL OR p_fiAreaId <= 0 OR t.fiAreaId = p_fiAreaId)
    AND (p_fiDepartamentoId IS NULL OR p_fiDepartamentoId <= 0 OR t.fiDepartamentoId = p_fiDepartamentoId)
  GROUP BY s.fiId, s.fcCodigo, s.fcNombre
  ORDER BY fiFallos DESC, s.fcNombre;
END$$
DELIMITER ;


-- 45_sp_reporte_reincidencia.sql
SET NAMES utf8mb4;
DROP PROCEDURE IF EXISTS sp_reporte_reincidencia;
DELIMITER $$
CREATE PROCEDURE sp_reporte_reincidencia(
  IN p_fdDesde DATETIME, IN p_fdHasta DATETIME, IN p_fiSucursalId INT, IN p_fiRegionId INT,
  IN p_fiTipoMantenimientoId INT, IN p_fiCategoriaId INT, IN p_fiPrioridadId INT, IN p_fiEstadoId INT,
  IN p_fiTecnicoId INT, IN p_fiProveedorId INT, IN p_fiAreaId INT, IN p_fiDepartamentoId INT
)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN SELECT 500 AS fiCodigo, 'Ocurrió un error al consultar reincidencia' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;

  SELECT
    COUNT(*) AS fiTickets,
    SUM(CASE WHEN t.fbReincidencia = 1 THEN 1 ELSE 0 END) AS fiReincidentes,
    ROUND(100.0 * SUM(CASE WHEN t.fbReincidencia = 1 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS fnTasaReincidencia
  FROM ticket t
  INNER JOIN sucursal s ON s.fiId = t.fiSucursalId
  WHERE t.fbActivo = 1
    AND (p_fdDesde IS NULL OR t.fdFechaIngreso >= p_fdDesde)
    AND (p_fdHasta IS NULL OR t.fdFechaIngreso < DATE_ADD(DATE(p_fdHasta), INTERVAL 1 DAY))
    AND (p_fiSucursalId IS NULL OR t.fiSucursalId = p_fiSucursalId)
    AND (p_fiRegionId IS NULL OR s.fiRegionId = p_fiRegionId)
    AND (p_fiTipoMantenimientoId IS NULL OR t.fiTipoMantenimientoId = p_fiTipoMantenimientoId)
    AND (p_fiCategoriaId IS NULL OR t.fiCategoriaId = p_fiCategoriaId)
    AND (p_fiPrioridadId IS NULL OR t.fiPrioridadId = p_fiPrioridadId)
    AND (p_fiEstadoId IS NULL OR t.fiEstadoId = p_fiEstadoId)
    AND (p_fiTecnicoId IS NULL OR t.fiTecnicoId = p_fiTecnicoId)
    AND (p_fiProveedorId IS NULL OR t.fiProveedorId = p_fiProveedorId)
    AND (p_fiAreaId IS NULL OR p_fiAreaId <= 0 OR t.fiAreaId = p_fiAreaId)
    AND (p_fiDepartamentoId IS NULL OR p_fiDepartamentoId <= 0 OR t.fiDepartamentoId = p_fiDepartamentoId);

  SELECT
    IFNULL(a.fcCodigo, 'SIN_ACTIVO') AS fcActivoCodigo,
    IFNULL(a.fcNombre, 'Sin activo') AS fcActivoNombre,
    c.fcNombre AS fcCategoriaNombre,
    s.fcNombre AS fcSucursalNombre,
    COUNT(*) AS fiTickets,
    SUM(CASE WHEN t.fbReincidencia = 1 THEN 1 ELSE 0 END) AS fiReincidentes
  FROM ticket t
  INNER JOIN sucursal s ON s.fiId = t.fiSucursalId
  INNER JOIN categoria c ON c.fiId = t.fiCategoriaId
  LEFT JOIN activo a ON a.fiId = t.fiActivoId
  WHERE t.fbActivo = 1
    AND t.fbReincidencia = 1
    AND (p_fdDesde IS NULL OR t.fdFechaIngreso >= p_fdDesde)
    AND (p_fdHasta IS NULL OR t.fdFechaIngreso < DATE_ADD(DATE(p_fdHasta), INTERVAL 1 DAY))
    AND (p_fiSucursalId IS NULL OR t.fiSucursalId = p_fiSucursalId)
    AND (p_fiRegionId IS NULL OR s.fiRegionId = p_fiRegionId)
    AND (p_fiTipoMantenimientoId IS NULL OR t.fiTipoMantenimientoId = p_fiTipoMantenimientoId)
    AND (p_fiCategoriaId IS NULL OR t.fiCategoriaId = p_fiCategoriaId)
    AND (p_fiPrioridadId IS NULL OR t.fiPrioridadId = p_fiPrioridadId)
    AND (p_fiEstadoId IS NULL OR t.fiEstadoId = p_fiEstadoId)
    AND (p_fiTecnicoId IS NULL OR t.fiTecnicoId = p_fiTecnicoId)
    AND (p_fiProveedorId IS NULL OR t.fiProveedorId = p_fiProveedorId)
    AND (p_fiAreaId IS NULL OR p_fiAreaId <= 0 OR t.fiAreaId = p_fiAreaId)
    AND (p_fiDepartamentoId IS NULL OR p_fiDepartamentoId <= 0 OR t.fiDepartamentoId = p_fiDepartamentoId)
  GROUP BY a.fiId, a.fcCodigo, a.fcNombre, c.fcNombre, s.fcNombre
  ORDER BY fiReincidentes DESC
  LIMIT 100;
END$$
DELIMITER ;


-- 52_sp_reporte_costos_activo_id.sql (recrea sp_reporte_costos con fiActivoId)
SET NAMES utf8mb4;
DROP PROCEDURE IF EXISTS sp_reporte_costos;
DELIMITER $$
CREATE PROCEDURE sp_reporte_costos(
  IN p_fdDesde DATETIME, IN p_fdHasta DATETIME, IN p_fiSucursalId INT, IN p_fiRegionId INT,
  IN p_fiTipoMantenimientoId INT, IN p_fiCategoriaId INT, IN p_fiPrioridadId INT, IN p_fiEstadoId INT,
  IN p_fiTecnicoId INT, IN p_fiProveedorId INT, IN p_fiAreaId INT, IN p_fiDepartamentoId INT
)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN SELECT 500 AS fiCodigo, 'Ocurrió un error al consultar costos' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;

  SELECT 'SUCURSAL' AS fcAgrupacion, NULL AS fiActivoId, s.fcCodigo AS fcCodigo, s.fcNombre AS fcNombre,
    COUNT(*) AS fiTickets,
    ROUND(SUM(IFNULL(t.fnCostoManoObra,0)), 2) AS fnCostoManoObra,
    ROUND(SUM(IFNULL(t.fnCostoMateriales,0)), 2) AS fnCostoMateriales,
    ROUND(SUM(IFNULL(t.fnCostoProveedor,0)), 2) AS fnCostoProveedor,
    ROUND(SUM(IFNULL(t.fnCostoManoObra,0)+IFNULL(t.fnCostoMateriales,0)+IFNULL(t.fnCostoProveedor,0)), 2) AS fnCostoTotal
  FROM ticket t
  INNER JOIN sucursal s ON s.fiId = t.fiSucursalId
  WHERE t.fbActivo = 1
    AND (p_fdDesde IS NULL OR t.fdFechaIngreso >= p_fdDesde)
    AND (p_fdHasta IS NULL OR t.fdFechaIngreso < DATE_ADD(DATE(p_fdHasta), INTERVAL 1 DAY))
    AND (p_fiSucursalId IS NULL OR t.fiSucursalId = p_fiSucursalId)
    AND (p_fiRegionId IS NULL OR s.fiRegionId = p_fiRegionId)
    AND (p_fiTipoMantenimientoId IS NULL OR t.fiTipoMantenimientoId = p_fiTipoMantenimientoId)
    AND (p_fiCategoriaId IS NULL OR t.fiCategoriaId = p_fiCategoriaId)
    AND (p_fiPrioridadId IS NULL OR t.fiPrioridadId = p_fiPrioridadId)
    AND (p_fiEstadoId IS NULL OR t.fiEstadoId = p_fiEstadoId)
    AND (p_fiTecnicoId IS NULL OR t.fiTecnicoId = p_fiTecnicoId)
    AND (p_fiProveedorId IS NULL OR t.fiProveedorId = p_fiProveedorId)
    AND (p_fiAreaId IS NULL OR p_fiAreaId <= 0 OR t.fiAreaId = p_fiAreaId)
    AND (p_fiDepartamentoId IS NULL OR p_fiDepartamentoId <= 0 OR t.fiDepartamentoId = p_fiDepartamentoId)
  GROUP BY s.fiId, s.fcCodigo, s.fcNombre
  ORDER BY fnCostoTotal DESC;

  SELECT 'CATEGORIA' AS fcAgrupacion, NULL AS fiActivoId, c.fcCodigo AS fcCodigo, c.fcNombre AS fcNombre,
    COUNT(*) AS fiTickets,
    ROUND(SUM(IFNULL(t.fnCostoManoObra,0)), 2) AS fnCostoManoObra,
    ROUND(SUM(IFNULL(t.fnCostoMateriales,0)), 2) AS fnCostoMateriales,
    ROUND(SUM(IFNULL(t.fnCostoProveedor,0)), 2) AS fnCostoProveedor,
    ROUND(SUM(IFNULL(t.fnCostoManoObra,0)+IFNULL(t.fnCostoMateriales,0)+IFNULL(t.fnCostoProveedor,0)), 2) AS fnCostoTotal
  FROM ticket t
  INNER JOIN sucursal s ON s.fiId = t.fiSucursalId
  INNER JOIN categoria c ON c.fiId = t.fiCategoriaId
  WHERE t.fbActivo = 1
    AND (p_fdDesde IS NULL OR t.fdFechaIngreso >= p_fdDesde)
    AND (p_fdHasta IS NULL OR t.fdFechaIngreso < DATE_ADD(DATE(p_fdHasta), INTERVAL 1 DAY))
    AND (p_fiSucursalId IS NULL OR t.fiSucursalId = p_fiSucursalId)
    AND (p_fiRegionId IS NULL OR s.fiRegionId = p_fiRegionId)
    AND (p_fiTipoMantenimientoId IS NULL OR t.fiTipoMantenimientoId = p_fiTipoMantenimientoId)
    AND (p_fiCategoriaId IS NULL OR t.fiCategoriaId = p_fiCategoriaId)
    AND (p_fiPrioridadId IS NULL OR t.fiPrioridadId = p_fiPrioridadId)
    AND (p_fiEstadoId IS NULL OR t.fiEstadoId = p_fiEstadoId)
    AND (p_fiTecnicoId IS NULL OR t.fiTecnicoId = p_fiTecnicoId)
    AND (p_fiProveedorId IS NULL OR t.fiProveedorId = p_fiProveedorId)
    AND (p_fiAreaId IS NULL OR p_fiAreaId <= 0 OR t.fiAreaId = p_fiAreaId)
    AND (p_fiDepartamentoId IS NULL OR p_fiDepartamentoId <= 0 OR t.fiDepartamentoId = p_fiDepartamentoId)
  GROUP BY c.fiId, c.fcCodigo, c.fcNombre
  ORDER BY fnCostoTotal DESC;

  SELECT 'ACTIVO' AS fcAgrupacion, a.fiId AS fiActivoId, IFNULL(a.fcCodigo,'SIN_ACTIVO') AS fcCodigo, IFNULL(a.fcNombre,'Sin activo') AS fcNombre,
    COUNT(*) AS fiTickets,
    ROUND(SUM(IFNULL(t.fnCostoManoObra,0)), 2) AS fnCostoManoObra,
    ROUND(SUM(IFNULL(t.fnCostoMateriales,0)), 2) AS fnCostoMateriales,
    ROUND(SUM(IFNULL(t.fnCostoProveedor,0)), 2) AS fnCostoProveedor,
    ROUND(SUM(IFNULL(t.fnCostoManoObra,0)+IFNULL(t.fnCostoMateriales,0)+IFNULL(t.fnCostoProveedor,0)), 2) AS fnCostoTotal
  FROM ticket t
  INNER JOIN sucursal s ON s.fiId = t.fiSucursalId
  LEFT JOIN activo a ON a.fiId = t.fiActivoId
  WHERE t.fbActivo = 1
    AND (p_fdDesde IS NULL OR t.fdFechaIngreso >= p_fdDesde)
    AND (p_fdHasta IS NULL OR t.fdFechaIngreso < DATE_ADD(DATE(p_fdHasta), INTERVAL 1 DAY))
    AND (p_fiSucursalId IS NULL OR t.fiSucursalId = p_fiSucursalId)
    AND (p_fiRegionId IS NULL OR s.fiRegionId = p_fiRegionId)
    AND (p_fiTipoMantenimientoId IS NULL OR t.fiTipoMantenimientoId = p_fiTipoMantenimientoId)
    AND (p_fiCategoriaId IS NULL OR t.fiCategoriaId = p_fiCategoriaId)
    AND (p_fiPrioridadId IS NULL OR t.fiPrioridadId = p_fiPrioridadId)
    AND (p_fiEstadoId IS NULL OR t.fiEstadoId = p_fiEstadoId)
    AND (p_fiTecnicoId IS NULL OR t.fiTecnicoId = p_fiTecnicoId)
    AND (p_fiProveedorId IS NULL OR t.fiProveedorId = p_fiProveedorId)
    AND (p_fiAreaId IS NULL OR p_fiAreaId <= 0 OR t.fiAreaId = p_fiAreaId)
    AND (p_fiDepartamentoId IS NULL OR p_fiDepartamentoId <= 0 OR t.fiDepartamentoId = p_fiDepartamentoId)
  GROUP BY a.fiId, a.fcCodigo, a.fcNombre
  ORDER BY fnCostoTotal DESC
  LIMIT 100;
END$$
DELIMITER ;


-- 47_sp_reporte_productividad.sql
SET NAMES utf8mb4;
DROP PROCEDURE IF EXISTS sp_reporte_productividad;
DELIMITER $$
CREATE PROCEDURE sp_reporte_productividad(
  IN p_fdDesde DATETIME, IN p_fdHasta DATETIME, IN p_fiSucursalId INT, IN p_fiRegionId INT,
  IN p_fiTipoMantenimientoId INT, IN p_fiCategoriaId INT, IN p_fiPrioridadId INT, IN p_fiEstadoId INT,
  IN p_fiTecnicoId INT, IN p_fiProveedorId INT, IN p_fiAreaId INT, IN p_fiDepartamentoId INT
)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN SELECT 500 AS fiCodigo, 'Ocurrió un error al consultar productividad' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;

  SELECT
    'TECNICO' AS fcTipoResponsable,
    te.fcCodigo AS fcCodigo,
    te.fcNombre AS fcNombre,
    COUNT(*) AS fiTickets,
    ROUND(SUM(IFNULL(t.fnHorasTrabajadas,0)), 2) AS fnHorasTrabajadas,
    ROUND(AVG(CASE WHEN t.fdResuelto IS NOT NULL
      THEN GREATEST(0, TIMESTAMPDIFF(MINUTE, t.fdFechaIngreso, t.fdResuelto) - IFNULL(t.fiMinutosEnEspera,0)) / 60.0 END), 2) AS fnHorasSolucionPromedio
  FROM ticket t
  INNER JOIN sucursal s ON s.fiId = t.fiSucursalId
  INNER JOIN tecnico te ON te.fiId = t.fiTecnicoId
  WHERE t.fbActivo = 1
    AND t.fiTecnicoId IS NOT NULL
    AND (p_fdDesde IS NULL OR t.fdFechaIngreso >= p_fdDesde)
    AND (p_fdHasta IS NULL OR t.fdFechaIngreso < DATE_ADD(DATE(p_fdHasta), INTERVAL 1 DAY))
    AND (p_fiSucursalId IS NULL OR t.fiSucursalId = p_fiSucursalId)
    AND (p_fiRegionId IS NULL OR s.fiRegionId = p_fiRegionId)
    AND (p_fiTipoMantenimientoId IS NULL OR t.fiTipoMantenimientoId = p_fiTipoMantenimientoId)
    AND (p_fiCategoriaId IS NULL OR t.fiCategoriaId = p_fiCategoriaId)
    AND (p_fiPrioridadId IS NULL OR t.fiPrioridadId = p_fiPrioridadId)
    AND (p_fiEstadoId IS NULL OR t.fiEstadoId = p_fiEstadoId)
    AND (p_fiTecnicoId IS NULL OR t.fiTecnicoId = p_fiTecnicoId)
    AND (p_fiProveedorId IS NULL OR t.fiProveedorId = p_fiProveedorId)
    AND (p_fiAreaId IS NULL OR p_fiAreaId <= 0 OR t.fiAreaId = p_fiAreaId)
    AND (p_fiDepartamentoId IS NULL OR p_fiDepartamentoId <= 0 OR t.fiDepartamentoId = p_fiDepartamentoId)
  GROUP BY te.fiId, te.fcCodigo, te.fcNombre
  ORDER BY fiTickets DESC;

  SELECT
    'PROVEEDOR' AS fcTipoResponsable,
    pr.fcCodigo AS fcCodigo,
    pr.fcNombre AS fcNombre,
    COUNT(*) AS fiTickets,
    ROUND(SUM(IFNULL(t.fnHorasTrabajadas,0)), 2) AS fnHorasTrabajadas,
    ROUND(AVG(CASE WHEN t.fdResuelto IS NOT NULL
      THEN GREATEST(0, TIMESTAMPDIFF(MINUTE, t.fdFechaIngreso, t.fdResuelto) - IFNULL(t.fiMinutosEnEspera,0)) / 60.0 END), 2) AS fnHorasSolucionPromedio
  FROM ticket t
  INNER JOIN sucursal s ON s.fiId = t.fiSucursalId
  INNER JOIN proveedor pr ON pr.fiId = t.fiProveedorId
  WHERE t.fbActivo = 1
    AND t.fiProveedorId IS NOT NULL
    AND (p_fdDesde IS NULL OR t.fdFechaIngreso >= p_fdDesde)
    AND (p_fdHasta IS NULL OR t.fdFechaIngreso < DATE_ADD(DATE(p_fdHasta), INTERVAL 1 DAY))
    AND (p_fiSucursalId IS NULL OR t.fiSucursalId = p_fiSucursalId)
    AND (p_fiRegionId IS NULL OR s.fiRegionId = p_fiRegionId)
    AND (p_fiTipoMantenimientoId IS NULL OR t.fiTipoMantenimientoId = p_fiTipoMantenimientoId)
    AND (p_fiCategoriaId IS NULL OR t.fiCategoriaId = p_fiCategoriaId)
    AND (p_fiPrioridadId IS NULL OR t.fiPrioridadId = p_fiPrioridadId)
    AND (p_fiEstadoId IS NULL OR t.fiEstadoId = p_fiEstadoId)
    AND (p_fiTecnicoId IS NULL OR t.fiTecnicoId = p_fiTecnicoId)
    AND (p_fiProveedorId IS NULL OR t.fiProveedorId = p_fiProveedorId)
    AND (p_fiAreaId IS NULL OR p_fiAreaId <= 0 OR t.fiAreaId = p_fiAreaId)
    AND (p_fiDepartamentoId IS NULL OR p_fiDepartamentoId <= 0 OR t.fiDepartamentoId = p_fiDepartamentoId)
  GROUP BY pr.fiId, pr.fcCodigo, pr.fcNombre
  ORDER BY fiTickets DESC;
END$$
DELIMITER ;


-- 49_sp_reporte_tendencia.sql
SET NAMES utf8mb4;
DROP PROCEDURE IF EXISTS sp_reporte_tendencia;
DELIMITER $$
CREATE PROCEDURE sp_reporte_tendencia(
  IN p_fdDesde DATETIME, IN p_fdHasta DATETIME, IN p_fiSucursalId INT, IN p_fiRegionId INT,
  IN p_fiTipoMantenimientoId INT, IN p_fiCategoriaId INT, IN p_fiPrioridadId INT, IN p_fiEstadoId INT,
  IN p_fiTecnicoId INT, IN p_fiProveedorId INT, IN p_fiAreaId INT, IN p_fiDepartamentoId INT
)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN SELECT 500 AS fiCodigo, 'Ocurrió un error al consultar la tendencia' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;

  SELECT
    DATE_FORMAT(t.fdFechaIngreso, '%Y-%m') AS fcPeriodo,
    DATE_FORMAT(t.fdFechaIngreso, '%m/%Y') AS fcPeriodoEtiqueta,
    COUNT(*) AS fiRecibidos,
    SUM(CASE WHEN e.fcCodigo IN ('CERRADO','VALIDADO') THEN 1 ELSE 0 END) AS fiCerrados,
    SUM(CASE WHEN e.fbFinal = 0 THEN 1 ELSE 0 END) AS fiAbiertos,
    ROUND(AVG(CASE WHEN t.fdResuelto IS NOT NULL
      THEN GREATEST(0, TIMESTAMPDIFF(MINUTE, t.fdFechaIngreso, t.fdResuelto) - IFNULL(t.fiMinutosEnEspera,0)) / 60.0 END), 2) AS fnMttrHoras
  FROM ticket t
  INNER JOIN sucursal s ON s.fiId = t.fiSucursalId
  INNER JOIN estado e ON e.fiId = t.fiEstadoId
  WHERE t.fbActivo = 1
    AND (p_fdDesde IS NULL OR t.fdFechaIngreso >= p_fdDesde)
    AND (p_fdHasta IS NULL OR t.fdFechaIngreso < DATE_ADD(DATE(p_fdHasta), INTERVAL 1 DAY))
    AND (p_fiSucursalId IS NULL OR t.fiSucursalId = p_fiSucursalId)
    AND (p_fiRegionId IS NULL OR s.fiRegionId = p_fiRegionId)
    AND (p_fiTipoMantenimientoId IS NULL OR t.fiTipoMantenimientoId = p_fiTipoMantenimientoId)
    AND (p_fiCategoriaId IS NULL OR t.fiCategoriaId = p_fiCategoriaId)
    AND (p_fiPrioridadId IS NULL OR t.fiPrioridadId = p_fiPrioridadId)
    AND (p_fiEstadoId IS NULL OR t.fiEstadoId = p_fiEstadoId)
    AND (p_fiTecnicoId IS NULL OR t.fiTecnicoId = p_fiTecnicoId)
    AND (p_fiProveedorId IS NULL OR t.fiProveedorId = p_fiProveedorId)
    AND (p_fiAreaId IS NULL OR p_fiAreaId <= 0 OR t.fiAreaId = p_fiAreaId)
    AND (p_fiDepartamentoId IS NULL OR p_fiDepartamentoId <= 0 OR t.fiDepartamentoId = p_fiDepartamentoId)
  GROUP BY DATE_FORMAT(t.fdFechaIngreso, '%Y-%m'), DATE_FORMAT(t.fdFechaIngreso, '%m/%Y')
  ORDER BY fcPeriodo;
END$$
DELIMITER ;


DROP PROCEDURE IF EXISTS sp_reporte_satisfaccion;
DELIMITER $$
CREATE PROCEDURE sp_reporte_satisfaccion(
  IN p_fdDesde DATETIME, IN p_fdHasta DATETIME, IN p_fiSucursalId INT, IN p_fiRegionId INT,
  IN p_fiTipoMantenimientoId INT, IN p_fiCategoriaId INT, IN p_fiPrioridadId INT, IN p_fiEstadoId INT,
  IN p_fiTecnicoId INT, IN p_fiProveedorId INT, IN p_fiAreaId INT, IN p_fiDepartamentoId INT
)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN SELECT 500 AS fiCodigo, 'Ocurrió un error al consultar satisfacción' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;

  SELECT
    COUNT(*) AS fiEncuestas,
    ROUND(AVG(en.fiCalificacion), 2) AS fnCalificacionPromedio,
    SUM(CASE WHEN en.fbConforme = 1 THEN 1 ELSE 0 END) AS fiConformes,
    ROUND(100.0 * SUM(CASE WHEN en.fbConforme = 1 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS fnPctConformes
  FROM ticketencuesta en
  INNER JOIN (
    SELECT fiTicketId, MAX(fiCiclo) AS fiCiclo FROM ticketencuesta GROUP BY fiTicketId
  ) ult ON ult.fiTicketId = en.fiTicketId AND ult.fiCiclo = en.fiCiclo
  INNER JOIN ticket t ON t.fiId = en.fiTicketId
  INNER JOIN sucursal s ON s.fiId = t.fiSucursalId
  WHERE t.fbActivo = 1
    AND (p_fdDesde IS NULL OR t.fdFechaIngreso >= p_fdDesde)
    AND (p_fdHasta IS NULL OR t.fdFechaIngreso < DATE_ADD(DATE(p_fdHasta), INTERVAL 1 DAY))
    AND (p_fiSucursalId IS NULL OR t.fiSucursalId = p_fiSucursalId)
    AND (p_fiRegionId IS NULL OR s.fiRegionId = p_fiRegionId)
    AND (p_fiTipoMantenimientoId IS NULL OR t.fiTipoMantenimientoId = p_fiTipoMantenimientoId)
    AND (p_fiCategoriaId IS NULL OR t.fiCategoriaId = p_fiCategoriaId)
    AND (p_fiPrioridadId IS NULL OR t.fiPrioridadId = p_fiPrioridadId)
    AND (p_fiEstadoId IS NULL OR t.fiEstadoId = p_fiEstadoId)
    AND (p_fiTecnicoId IS NULL OR t.fiTecnicoId = p_fiTecnicoId)
    AND (p_fiProveedorId IS NULL OR t.fiProveedorId = p_fiProveedorId)
    AND (p_fiAreaId IS NULL OR p_fiAreaId <= 0 OR t.fiAreaId = p_fiAreaId)
    AND (p_fiDepartamentoId IS NULL OR p_fiDepartamentoId <= 0 OR t.fiDepartamentoId = p_fiDepartamentoId);

  SELECT
    en.fiCalificacion,
    COUNT(*) AS fiCantidad,
    ROUND(100.0 * COUNT(*) / NULLIF(SUM(COUNT(*)) OVER (), 0), 2) AS fnPorcentaje
  FROM ticketencuesta en
  INNER JOIN (
    SELECT fiTicketId, MAX(fiCiclo) AS fiCiclo FROM ticketencuesta GROUP BY fiTicketId
  ) ult ON ult.fiTicketId = en.fiTicketId AND ult.fiCiclo = en.fiCiclo
  INNER JOIN ticket t ON t.fiId = en.fiTicketId
  INNER JOIN sucursal s ON s.fiId = t.fiSucursalId
  WHERE t.fbActivo = 1
    AND (p_fdDesde IS NULL OR t.fdFechaIngreso >= p_fdDesde)
    AND (p_fdHasta IS NULL OR t.fdFechaIngreso < DATE_ADD(DATE(p_fdHasta), INTERVAL 1 DAY))
    AND (p_fiSucursalId IS NULL OR t.fiSucursalId = p_fiSucursalId)
    AND (p_fiRegionId IS NULL OR s.fiRegionId = p_fiRegionId)
    AND (p_fiTipoMantenimientoId IS NULL OR t.fiTipoMantenimientoId = p_fiTipoMantenimientoId)
    AND (p_fiCategoriaId IS NULL OR t.fiCategoriaId = p_fiCategoriaId)
    AND (p_fiPrioridadId IS NULL OR t.fiPrioridadId = p_fiPrioridadId)
    AND (p_fiEstadoId IS NULL OR t.fiEstadoId = p_fiEstadoId)
    AND (p_fiTecnicoId IS NULL OR t.fiTecnicoId = p_fiTecnicoId)
    AND (p_fiProveedorId IS NULL OR t.fiProveedorId = p_fiProveedorId)
    AND (p_fiAreaId IS NULL OR p_fiAreaId <= 0 OR t.fiAreaId = p_fiAreaId)
    AND (p_fiDepartamentoId IS NULL OR p_fiDepartamentoId <= 0 OR t.fiDepartamentoId = p_fiDepartamentoId)
  GROUP BY en.fiCalificacion
  ORDER BY en.fiCalificacion;
END$$
DELIMITER ;