-- 86_sp_correo.sql
-- SP del módulo de correos (bandeja correopendiente + datos para plantillas de ticket y SLA).
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_correo_encolar;
DROP PROCEDURE IF EXISTS sp_correo_pendientes_listar;
DROP PROCEDURE IF EXISTS sp_correo_marcar_enviado;
DROP PROCEDURE IF EXISTS sp_correo_marcar_error;
DROP PROCEDURE IF EXISTS sp_correo_ticket_datos;
DROP PROCEDURE IF EXISTS sp_correo_sla_alertas_pendientes;
DROP PROCEDURE IF EXISTS sp_correo_sla_alerta_marcar;

DELIMITER $$

-- Encola un correo. El cuerpo llega cifrado desde C# (Data Protection).
CREATE PROCEDURE sp_correo_encolar(
  IN p_fcPara VARCHAR(150),
  IN p_fcAsunto VARCHAR(250),
  IN p_fcCuerpoCifrado MEDIUMTEXT,
  IN p_fcTipo VARCHAR(40),
  IN p_fcFormato VARCHAR(10),
  IN p_fiTicketId INT,
  IN p_fiUsuarioId INT
)
proc: BEGIN
  DECLARE v_id INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SELECT 500 AS fiCodigo, 'Ocurrió un error al encolar el correo' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
  END;

  IF TRIM(IFNULL(p_fcPara,'')) = '' THEN
    SELECT 400 AS fiCodigo, 'El destinatario es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF TRIM(IFNULL(p_fcAsunto,'')) = '' THEN
    SELECT 400 AS fiCodigo, 'El asunto es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF TRIM(IFNULL(p_fcCuerpoCifrado,'')) = '' THEN
    SELECT 400 AS fiCodigo, 'El cuerpo del correo es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;

  START TRANSACTION;
  INSERT INTO correopendiente (fcPara, fcAsunto, fcCuerpoCifrado, fcTipo, fcFormato, fiTicketId, fbEnviado, fiIntentos, fiCreadoPor)
  VALUES (TRIM(p_fcPara), LEFT(TRIM(p_fcAsunto), 250), p_fcCuerpoCifrado,
          IFNULL(NULLIF(TRIM(p_fcTipo),''), 'GENERAL'),
          IF(UPPER(IFNULL(p_fcFormato,'')) = 'JSON', 'JSON', 'TEXTO'),
          IF(IFNULL(p_fiTicketId,0) <= 0, NULL, p_fiTicketId),
          0, 0,
          IF(IFNULL(p_fiUsuarioId,0) <= 0, NULL, p_fiUsuarioId));
  SET v_id = LAST_INSERT_ID();
  COMMIT;
  SELECT 201 AS fiCodigo, 'Correo encolado correctamente' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('correopendiente', v_id) AS fjData;
END$$

-- Pendientes de envío: sin enviar, con intentos disponibles y con espera creciente entre reintentos.
CREATE PROCEDURE sp_correo_pendientes_listar(IN p_fiLimite INT, IN p_fiMaxIntentos INT)
BEGIN
  DECLARE v_lim INT;
  DECLARE v_max INT;
  SET v_lim = IF(IFNULL(p_fiLimite,0) < 1, 50, LEAST(p_fiLimite, 500));
  SET v_max = IF(IFNULL(p_fiMaxIntentos,0) < 1, 5, p_fiMaxIntentos);

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;

  SELECT fiId, fcPara, fcAsunto, fcCuerpoCifrado, fcTipo, fcFormato, fiTicketId, fiIntentos, fdCreado
  FROM correopendiente
  WHERE fbEnviado = 0
    AND fiIntentos < v_max
    AND (fdUltimoIntento IS NULL OR fdUltimoIntento <= NOW() - INTERVAL (fiIntentos * 2) MINUTE)
  ORDER BY fiId
  LIMIT v_lim;
END$$

CREATE PROCEDURE sp_correo_marcar_enviado(IN p_fiId INT)
proc: BEGIN
  UPDATE correopendiente
     SET fbEnviado = 1, fdEnviado = NOW(), fdUltimoIntento = NOW(), fcError = NULL
   WHERE fiId = p_fiId AND fbEnviado = 0;
  IF ROW_COUNT() = 0 THEN
    SELECT 404 AS fiCodigo, 'El correo no existe o ya estaba enviado' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  SELECT 200 AS fiCodigo, 'Correo marcado como enviado' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('correopendiente', p_fiId) AS fjData;
END$$

-- Suma un intento y guarda el error. fjData.errorDefinitivo = 1 cuando ya no se reintentará.
CREATE PROCEDURE sp_correo_marcar_error(IN p_fiId INT, IN p_fcError VARCHAR(500), IN p_fiMaxIntentos INT)
proc: BEGIN
  DECLARE v_int INT DEFAULT NULL;
  DECLARE v_max INT;
  SET v_max = IF(IFNULL(p_fiMaxIntentos,0) < 1, 5, p_fiMaxIntentos);

  UPDATE correopendiente
     SET fiIntentos = fiIntentos + 1, fcError = LEFT(IFNULL(p_fcError,'Error desconocido'), 500), fdUltimoIntento = NOW()
   WHERE fiId = p_fiId AND fbEnviado = 0;
  IF ROW_COUNT() = 0 THEN
    SELECT 404 AS fiCodigo, 'El correo no existe o ya estaba enviado' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  SELECT fiIntentos INTO v_int FROM correopendiente WHERE fiId = p_fiId;
  SELECT 200 AS fiCodigo, 'Error registrado' AS fcMensaje, 1 AS fbSucces,
         JSON_OBJECT('correopendiente', p_fiId, 'intentos', v_int, 'errorDefinitivo', IF(v_int >= v_max, 1, 0)) AS fjData;
END$$

-- Datos del ticket para la plantilla (2.º result set) y destinatarios por grupo (3.º):
-- SOLICITANTE, RESPONSABLE (técnico o proveedor), JEFATURA (de la sucursal o sin sucursal) y MANTENIMIENTO (MANTENIMIENTO y ADMIN).
CREATE PROCEDURE sp_correo_ticket_datos(IN p_fiTicketId INT)
proc: BEGIN
  IF NOT EXISTS (SELECT 1 FROM ticket WHERE fiId = p_fiTicketId) THEN
    SELECT 404 AS fiCodigo, 'El ticket no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('ticket', p_fiTicketId) AS fjData;

  SELECT t.fiId, t.fcNumero, t.fdFechaIngreso, t.fcDescripcion, t.fcSolicitanteNombre,
         s.fcNombre AS fcSucursalNombre, p.fcNombre AS fcPrioridadNombre, e.fcCodigo AS fcEstadoCodigo, e.fcNombre AS fcEstadoNombre,
         tm.fcNombre AS fcTipoNombre, IFNULL(tm.fbRequiereAprobacion, 1) AS fbRequiereAprobacion,
         c.fcNombre AS fcCategoriaNombre, me.fcNombre AS fcMotivoEsperaNombre,
         t.fcTipoResponsable,
         CASE WHEN t.fcTipoResponsable = 'PROVEEDOR' THEN pr.fcNombre ELSE tc.fcNombre END AS fcResponsableNombre,
         t.fdFechaProgramada, t.fdLimiteRespuesta, t.fdLimiteSolucion,
         (SELECT h.fcComentario FROM ticketestado h WHERE h.fiTicketId = t.fiId ORDER BY h.fiId DESC LIMIT 1) AS fcUltimoComentario
  FROM ticket t
  JOIN estado e ON e.fiId = t.fiEstadoId
  JOIN prioridad p ON p.fiId = t.fiPrioridadId
  LEFT JOIN sucursal s ON s.fiId = t.fiSucursalId
  LEFT JOIN tipomantenimiento tm ON tm.fiId = t.fiTipoMantenimientoId
  LEFT JOIN categoria c ON c.fiId = t.fiCategoriaId
  LEFT JOIN motivoespera me ON me.fiId = t.fiMotivoEsperaId
  LEFT JOIN tecnico tc ON tc.fiId = t.fiTecnicoId
  LEFT JOIN proveedor pr ON pr.fiId = t.fiProveedorId
  WHERE t.fiId = p_fiTicketId;

  SELECT 'SOLICITANTE' AS fcGrupo, COALESCE(NULLIF(TRIM(t.fcCorreo),''), u.fcCorreo) AS fcCorreo,
         COALESCE(NULLIF(t.fcSolicitanteNombre,''), u.fcNombre) AS fcNombre
    FROM ticket t LEFT JOIN usuario u ON u.fiId = t.fiSolicitanteId
   WHERE t.fiId = p_fiTicketId AND COALESCE(NULLIF(TRIM(t.fcCorreo),''), u.fcCorreo) IS NOT NULL
  UNION ALL
  SELECT 'RESPONSABLE', ut.fcCorreo, tc.fcNombre
    FROM ticket t JOIN tecnico tc ON tc.fiId = t.fiTecnicoId JOIN usuario ut ON ut.fiId = tc.fiUsuarioId AND ut.fbActivo = 1
   WHERE t.fiId = p_fiTicketId AND IFNULL(t.fcTipoResponsable,'INTERNO') <> 'PROVEEDOR' AND TRIM(IFNULL(ut.fcCorreo,'')) <> ''
  UNION ALL
  SELECT 'RESPONSABLE', pr.fcCorreo, pr.fcNombre
    FROM ticket t JOIN proveedor pr ON pr.fiId = t.fiProveedorId
   WHERE t.fiId = p_fiTicketId AND t.fcTipoResponsable = 'PROVEEDOR' AND TRIM(IFNULL(pr.fcCorreo,'')) <> ''
  UNION ALL
  SELECT 'JEFATURA', u.fcCorreo, u.fcNombre
    FROM usuario u JOIN rol r ON r.fiId = u.fiRolId AND r.fcCodigo = 'JEFATURA' AND r.fbActivo = 1
    JOIN ticket t ON t.fiId = p_fiTicketId
   WHERE u.fbActivo = 1 AND TRIM(IFNULL(u.fcCorreo,'')) <> ''
     AND (u.fiSucursalId IS NULL OR u.fiSucursalId = t.fiSucursalId)
  UNION ALL
  SELECT 'MANTENIMIENTO', u.fcCorreo, u.fcNombre
    FROM usuario u JOIN rol r ON r.fiId = u.fiRolId AND r.fcCodigo IN ('MANTENIMIENTO','ADMIN') AND r.fbActivo = 1
   WHERE u.fbActivo = 1 AND TRIM(IFNULL(u.fcCorreo,'')) <> '';
END$$

-- Alertas SLA de las últimas 24 h cuyo correo aún no se encoló.
CREATE PROCEDURE sp_correo_sla_alertas_pendientes(IN p_fiLimite INT)
BEGIN
  DECLARE v_lim INT;
  SET v_lim = IF(IFNULL(p_fiLimite,0) < 1, 50, LEAST(p_fiLimite, 500));
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;
  SELECT a.fiId, a.fiTicketId, a.fcTipo, a.fdFecha, a.fcDetalle
  FROM slaalerta a
  JOIN ticket t ON t.fiId = a.fiTicketId
  JOIN estado e ON e.fiId = t.fiEstadoId
  WHERE a.fbCorreoEncolado = 0
    AND a.fdFecha >= NOW() - INTERVAL 1 DAY
    AND IFNULL(e.fbFinal, 0) = 0
  ORDER BY a.fiId
  LIMIT v_lim;
END$$

CREATE PROCEDURE sp_correo_sla_alerta_marcar(IN p_fiId INT)
BEGIN
  UPDATE slaalerta SET fbCorreoEncolado = 1 WHERE fiId = p_fiId;
  SELECT 200 AS fiCodigo, 'Alerta marcada' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('slaalerta', p_fiId) AS fjData;
END$$

DELIMITER ;
