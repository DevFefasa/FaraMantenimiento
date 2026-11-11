-- 99_ticket_vistas.sql
-- Sección única "Tickets" con pestañas (vistas): creados, asignados, equipo, aprobar, atender, todos.
--  - usuario.fiJefeId (jerarquía; FK e índice los crea cursor2 en 98).
--  - fn_usuario_tiene_permiso, fn_usuario_es_subordinado, fn_ticket_puede_ver.
--  - sp_ticket_listar_vista: filtrado por vista y permiso en el SP (sp_ticket_listar queda como estaba).
--  - sp_ticket_vistas_resumen: pestañas disponibles y abiertos por pestaña.
--  - sp_ticket_puede_ver: regla de visibilidad para el detalle.
--  - "Todos" solo para ADMIN y GERENCIA: se quita TICKET_TODOS de JEFATURA y MANTENIMIENTO.
SET NAMES utf8mb4;

ALTER TABLE usuario ADD COLUMN IF NOT EXISTS fiJefeId INT NULL COMMENT 'Jefe directo (usuario.fiId)';

DELETE rp FROM rolpermiso rp
JOIN rol r ON r.fiId = rp.fiRolId
JOIN pantalla p ON p.fiId = rp.fiPantallaId
WHERE r.fcCodigo IN ('JEFATURA', 'MANTENIMIENTO') AND p.fcCodigo = 'TICKET_TODOS';

DROP FUNCTION IF EXISTS fn_usuario_tiene_permiso;
DROP FUNCTION IF EXISTS fn_usuario_es_subordinado;
DROP FUNCTION IF EXISTS fn_ticket_puede_ver;
DROP PROCEDURE IF EXISTS sp_ticket_listar_vista;
DROP PROCEDURE IF EXISTS sp_ticket_vistas_resumen;
DROP PROCEDURE IF EXISTS sp_ticket_puede_ver;

DELIMITER $$

-- 1 si el usuario (activo, con rol activo) tiene la pantalla/permiso indicado. ADMIN tiene todo.
CREATE FUNCTION fn_usuario_tiene_permiso(p_fiUsuarioId INT, p_fcPantalla VARCHAR(50))
RETURNS TINYINT
READS SQL DATA
BEGIN
  DECLARE v_rol VARCHAR(30) DEFAULT NULL;
  DECLARE v_rolId INT DEFAULT NULL;
  SELECT r.fcCodigo, r.fiId INTO v_rol, v_rolId
  FROM usuario u JOIN rol r ON r.fiId = u.fiRolId AND r.fbActivo = 1
  WHERE u.fiId = p_fiUsuarioId AND u.fbActivo = 1
  LIMIT 1;
  IF v_rol IS NULL THEN RETURN 0; END IF;
  IF v_rol = 'ADMIN' THEN RETURN 1; END IF;
  RETURN IF(EXISTS (
    SELECT 1 FROM rolpermiso rp JOIN pantalla p ON p.fiId = rp.fiPantallaId AND p.fbActivo = 1
    WHERE rp.fiRolId = v_rolId AND p.fcCodigo = p_fcPantalla), 1, 0);
END$$

-- 1 si p_fiSubordinadoId depende (directa o indirectamente, vía usuario.fiJefeId) de p_fiJefeId.
-- Recorre la cadena hacia arriba con tope de 20 niveles (evita ciclos).
CREATE FUNCTION fn_usuario_es_subordinado(p_fiSubordinadoId INT, p_fiJefeId INT)
RETURNS TINYINT
READS SQL DATA
BEGIN
  DECLARE v_actual INT;
  DECLARE v_nivel INT DEFAULT 0;
  IF p_fiSubordinadoId IS NULL OR p_fiJefeId IS NULL OR p_fiSubordinadoId = p_fiJefeId THEN RETURN 0; END IF;
  SELECT fiJefeId INTO v_actual FROM usuario WHERE fiId = p_fiSubordinadoId;
  WHILE v_actual IS NOT NULL AND v_nivel < 20 DO
    IF v_actual = p_fiJefeId THEN RETURN 1; END IF;
    SET v_nivel = v_nivel + 1;
    SET v_actual = (SELECT fiJefeId FROM usuario WHERE fiId = v_actual);
  END WHILE;
  RETURN 0;
END$$

-- Regla de visibilidad de un ticket: TICKET_TODOS/BANDEJA/APROBACION vigentes (o ADMIN), solicitante,
-- técnico asignado ligado al usuario, o solicitante subordinado (directo o indirecto).
CREATE FUNCTION fn_ticket_puede_ver(p_fiUsuarioId INT, p_fiTicketId INT)
RETURNS TINYINT
READS SQL DATA
BEGIN
  DECLARE v_sol INT DEFAULT NULL;
  DECLARE v_tec INT DEFAULT NULL;
  IF p_fiUsuarioId IS NULL OR p_fiUsuarioId <= 0 THEN RETURN 0; END IF;
  IF NOT EXISTS (SELECT 1 FROM usuario WHERE fiId = p_fiUsuarioId AND fbActivo = 1) THEN RETURN 0; END IF;
  SELECT fiSolicitanteId, fiTecnicoId INTO v_sol, v_tec FROM ticket WHERE fiId = p_fiTicketId AND fbActivo = 1;
  IF fn_usuario_tiene_permiso(p_fiUsuarioId, 'TICKET_TODOS') = 1
     OR fn_usuario_tiene_permiso(p_fiUsuarioId, 'TICKET_BANDEJA') = 1
     OR fn_usuario_tiene_permiso(p_fiUsuarioId, 'TICKET_APROBACION') = 1 THEN RETURN 1; END IF;
  IF v_sol = p_fiUsuarioId THEN RETURN 1; END IF;
  IF v_tec IS NOT NULL AND EXISTS (SELECT 1 FROM tecnico WHERE fiId = v_tec AND fiUsuarioId = p_fiUsuarioId) THEN RETURN 1; END IF;
  RETURN fn_usuario_es_subordinado(v_sol, p_fiUsuarioId);
END$$

-- Para el detalle: 200 si puede ver, 403 si no, 404 si el ticket no existe.
CREATE PROCEDURE sp_ticket_puede_ver(IN p_fiTicketId INT, IN p_fiUsuarioId INT)
proc: BEGIN
  IF NOT EXISTS (SELECT 1 FROM ticket WHERE fiId = p_fiTicketId AND fbActivo = 1) THEN
    SELECT 404 AS fiCodigo, 'El ticket no existe' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF fn_ticket_puede_ver(p_fiUsuarioId, p_fiTicketId) = 0 THEN
    SELECT 403 AS fiCodigo, 'No tiene permiso para ver este ticket' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, JSON_OBJECT('ticket', p_fiTicketId) AS fjData;
END$$

-- Pestañas disponibles para el usuario y tickets abiertos en cada una (2.º result set: fcVista, fbDisponible, fiAbiertos).
CREATE PROCEDURE sp_ticket_vistas_resumen(IN p_fiUsuarioId INT)
BEGIN
  DECLARE v_aprobar TINYINT DEFAULT 0;
  DECLARE v_atender TINYINT DEFAULT 0;
  DECLARE v_todos TINYINT DEFAULT 0;
  DECLARE v_equipo TINYINT DEFAULT 0;

  SET v_aprobar = fn_usuario_tiene_permiso(p_fiUsuarioId, 'TICKET_APROBACION');
  SET v_atender = fn_usuario_tiene_permiso(p_fiUsuarioId, 'TICKET_BANDEJA');
  SET v_todos = fn_usuario_tiene_permiso(p_fiUsuarioId, 'TICKET_TODOS');
  SET v_equipo = IF(EXISTS (SELECT 1 FROM usuario WHERE fiJefeId = p_fiUsuarioId AND fiId <> p_fiUsuarioId), 1, 0);

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;

  SELECT 'creados' AS fcVista, 1 AS fbDisponible,
         (SELECT COUNT(*) FROM ticket t JOIN estado e ON e.fiId = t.fiEstadoId
           WHERE t.fbActivo = 1 AND e.fbFinal = 0 AND t.fiSolicitanteId = p_fiUsuarioId) AS fiAbiertos
  UNION ALL
  SELECT 'asignados', 1,
         (SELECT COUNT(*) FROM ticket t JOIN estado e ON e.fiId = t.fiEstadoId JOIN tecnico tc ON tc.fiId = t.fiTecnicoId
           WHERE t.fbActivo = 1 AND e.fbFinal = 0 AND tc.fiUsuarioId = p_fiUsuarioId)
  UNION ALL
  SELECT 'equipo', v_equipo,
         IF(v_equipo = 0, 0, (SELECT COUNT(*) FROM ticket t JOIN estado e ON e.fiId = t.fiEstadoId
           WHERE t.fbActivo = 1 AND e.fbFinal = 0 AND fn_usuario_es_subordinado(t.fiSolicitanteId, p_fiUsuarioId) = 1))
  UNION ALL
  SELECT 'aprobar', v_aprobar,
         IF(v_aprobar = 0, 0, (SELECT COUNT(*) FROM ticket t JOIN estado e ON e.fiId = t.fiEstadoId
           WHERE t.fbActivo = 1 AND e.fcCodigo = 'EN_EVALUACION'))
  UNION ALL
  SELECT 'atender', v_atender,
         IF(v_atender = 0, 0, (SELECT COUNT(*) FROM ticket t JOIN estado e ON e.fiId = t.fiEstadoId
           WHERE t.fbActivo = 1 AND e.fbFinal = 0))
  UNION ALL
  SELECT 'todos', v_todos,
         IF(v_todos = 0, 0, (SELECT COUNT(*) FROM ticket t JOIN estado e ON e.fiId = t.fiEstadoId
           WHERE t.fbActivo = 1 AND e.fbFinal = 0));
END$$

-- Listado por vista. Mismos filtros y columnas que sp_ticket_listar (69) + p_fcVista y p_fiUsuarioId.
-- 400 si la vista no existe; 403 si el usuario no tiene el permiso de la vista.
CREATE PROCEDURE sp_ticket_listar_vista(
  IN p_fcVista VARCHAR(20),
  IN p_fiUsuarioId INT,
  IN p_fiEstadoId INT,
  IN p_fcEstadoCodigo VARCHAR(30),
  IN p_fiSucursalId INT,
  IN p_fiPrioridadId INT,
  IN p_fiTipoMantenimientoId INT,
  IN p_fiCategoriaId INT,
  IN p_fcTipoResponsable VARCHAR(20),
  IN p_fiTecnicoId INT,
  IN p_fiProveedorId INT,
  IN p_fdDesde DATETIME,
  IN p_fdHasta DATETIME,
  IN p_fcTexto VARCHAR(200),
  IN p_fbSoloAbiertos TINYINT,
  IN p_fiPagina INT,
  IN p_fiTamano INT
)
proc: BEGIN
  DECLARE v_vista VARCHAR(20);
  DECLARE v_offset INT DEFAULT 0;
  DECLARE v_tam INT DEFAULT 20;
  DECLARE v_pag INT DEFAULT 1;
  DECLARE v_total INT DEFAULT 0;
  DECLARE v_ok TINYINT DEFAULT 0;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN SELECT 500 AS fiCodigo, 'Ocurrió un error al listar tickets' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; END;

  SET v_vista = LOWER(TRIM(IFNULL(p_fcVista, '')));
  IF v_vista NOT IN ('creados', 'asignados', 'equipo', 'aprobar', 'atender', 'todos') THEN
    SELECT 400 AS fiCodigo, 'Vista de tickets no válida' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  IF p_fiUsuarioId IS NULL OR NOT EXISTS (SELECT 1 FROM usuario WHERE fiId = p_fiUsuarioId AND fbActivo = 1) THEN
    SELECT 403 AS fiCodigo, 'Usuario no válido' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;
  SET v_ok = CASE v_vista
    WHEN 'aprobar' THEN fn_usuario_tiene_permiso(p_fiUsuarioId, 'TICKET_APROBACION')
    WHEN 'atender' THEN fn_usuario_tiene_permiso(p_fiUsuarioId, 'TICKET_BANDEJA')
    WHEN 'todos' THEN fn_usuario_tiene_permiso(p_fiUsuarioId, 'TICKET_TODOS')
    ELSE 1 END;
  IF v_ok = 0 THEN
    SELECT 403 AS fiCodigo, 'No tiene permiso para esta vista de tickets' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;

  SET v_pag = IF(p_fiPagina IS NULL OR p_fiPagina < 1, 1, IF(p_fiPagina > 100000, 100000, p_fiPagina));
  SET v_tam = IF(p_fiTamano IS NULL OR p_fiTamano < 1, 20, IF(p_fiTamano > 200, 200, p_fiTamano));
  SET v_offset = (v_pag - 1) * v_tam;

  SELECT COUNT(*) INTO v_total
  FROM ticket t
  INNER JOIN estado e ON e.fiId = t.fiEstadoId
  LEFT JOIN tecnico tv ON tv.fiId = t.fiTecnicoId
  WHERE t.fbActivo = 1
    AND (   (v_vista = 'creados'   AND t.fiSolicitanteId = p_fiUsuarioId)
         OR (v_vista = 'asignados' AND tv.fiUsuarioId = p_fiUsuarioId)
         OR (v_vista = 'equipo'    AND fn_usuario_es_subordinado(t.fiSolicitanteId, p_fiUsuarioId) = 1)
         OR (v_vista = 'aprobar'   AND e.fcCodigo = 'EN_EVALUACION')
         OR v_vista IN ('atender', 'todos'))
    AND (p_fiEstadoId IS NULL OR p_fiEstadoId <= 0 OR t.fiEstadoId = p_fiEstadoId)
    AND (p_fcEstadoCodigo IS NULL OR TRIM(p_fcEstadoCodigo) = '' OR e.fcCodigo = UPPER(TRIM(p_fcEstadoCodigo)))
    AND (p_fiSucursalId IS NULL OR p_fiSucursalId <= 0 OR t.fiSucursalId = p_fiSucursalId)
    AND (p_fiPrioridadId IS NULL OR p_fiPrioridadId <= 0 OR t.fiPrioridadId = p_fiPrioridadId)
    AND (p_fiTipoMantenimientoId IS NULL OR p_fiTipoMantenimientoId <= 0 OR t.fiTipoMantenimientoId = p_fiTipoMantenimientoId)
    AND (p_fiCategoriaId IS NULL OR p_fiCategoriaId <= 0 OR t.fiCategoriaId = p_fiCategoriaId)
    AND (p_fcTipoResponsable IS NULL OR TRIM(p_fcTipoResponsable) = '' OR t.fcTipoResponsable = UPPER(TRIM(p_fcTipoResponsable)))
    AND (p_fiTecnicoId IS NULL OR p_fiTecnicoId <= 0 OR t.fiTecnicoId = p_fiTecnicoId)
    AND (p_fiProveedorId IS NULL OR p_fiProveedorId <= 0 OR t.fiProveedorId = p_fiProveedorId)
    AND (p_fdDesde IS NULL OR t.fdFechaIngreso >= p_fdDesde)
    AND (p_fdHasta IS NULL OR t.fdFechaIngreso <= p_fdHasta)
    AND (IFNULL(p_fbSoloAbiertos,0) = 0 OR e.fbFinal = 0)
    AND (p_fcTexto IS NULL OR TRIM(p_fcTexto) = '' OR t.fcNumero LIKE CONCAT('%', TRIM(p_fcTexto), '%')
         OR t.fcDescripcion LIKE CONCAT('%', TRIM(p_fcTexto), '%')
         OR t.fcSolicitanteNombre LIKE CONCAT('%', TRIM(p_fcTexto), '%'));

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces,
         JSON_OBJECT('total', v_total, 'pagina', v_pag, 'tamano', v_tam, 'vista', v_vista) AS fjData;

  SELECT t.fiId, t.fcNumero, t.fdFechaIngreso, t.fiSolicitanteId, t.fcSolicitanteNombre,
         t.fiSucursalId, s.fcNombre AS fcSucursalNombre,
         t.fiTipoMantenimientoId, tm.fcNombre AS fcTipoNombre,
         t.fiCategoriaId, c.fcNombre AS fcCategoriaNombre,
         t.fiPrioridadId, p.fcNombre AS fcPrioridadNombre, p.fcCodigo AS fcPrioridadCodigo, p.fcColor AS fcPrioridadColor,
         t.fiEstadoId, e.fcCodigo AS fcEstadoCodigo, e.fcNombre AS fcEstadoNombre, e.fcColor AS fcEstadoColor, e.fbFinal,
         t.fcTipoResponsable, t.fiTecnicoId, tec.fcNombre AS fcTecnicoNombre,
         t.fiProveedorId, pr.fcNombre AS fcProveedorNombre,
         t.fbReincidencia, t.fdLimiteRespuesta, t.fdLimiteSolucion,
         t.fbSlaRespuestaCumplido, t.fbSlaSolucionCumplido,
         LEFT(t.fcDescripcion, 160) AS fcDescripcionCorta,
         CASE
           WHEN e.fbFinal = 1 OR e.fcCodigo IN ('CERRADO','RECHAZADO','VALIDADO') THEN 'GRIS'
           WHEN t.fdLimiteSolucion IS NOT NULL AND NOW() > t.fdLimiteSolucion THEN 'ROJO'
           WHEN t.fdLimiteSolucion IS NOT NULL AND TIMESTAMPDIFF(SECOND, t.fdFechaIngreso, NOW()) >=
                0.75 * TIMESTAMPDIFF(SECOND, t.fdFechaIngreso, t.fdLimiteSolucion) THEN 'AMARILLO'
           ELSE 'VERDE'
         END AS fcSemaforoSla
  FROM ticket t
  INNER JOIN sucursal s ON s.fiId = t.fiSucursalId
  INNER JOIN tipomantenimiento tm ON tm.fiId = t.fiTipoMantenimientoId
  INNER JOIN categoria c ON c.fiId = t.fiCategoriaId
  INNER JOIN prioridad p ON p.fiId = t.fiPrioridadId
  INNER JOIN estado e ON e.fiId = t.fiEstadoId
  LEFT JOIN tecnico tec ON tec.fiId = t.fiTecnicoId
  LEFT JOIN proveedor pr ON pr.fiId = t.fiProveedorId
  WHERE t.fbActivo = 1
    AND (   (v_vista = 'creados'   AND t.fiSolicitanteId = p_fiUsuarioId)
         OR (v_vista = 'asignados' AND tec.fiUsuarioId = p_fiUsuarioId)
         OR (v_vista = 'equipo'    AND fn_usuario_es_subordinado(t.fiSolicitanteId, p_fiUsuarioId) = 1)
         OR (v_vista = 'aprobar'   AND e.fcCodigo = 'EN_EVALUACION')
         OR v_vista IN ('atender', 'todos'))
    AND (p_fiEstadoId IS NULL OR p_fiEstadoId <= 0 OR t.fiEstadoId = p_fiEstadoId)
    AND (p_fcEstadoCodigo IS NULL OR TRIM(p_fcEstadoCodigo) = '' OR e.fcCodigo = UPPER(TRIM(p_fcEstadoCodigo)))
    AND (p_fiSucursalId IS NULL OR p_fiSucursalId <= 0 OR t.fiSucursalId = p_fiSucursalId)
    AND (p_fiPrioridadId IS NULL OR p_fiPrioridadId <= 0 OR t.fiPrioridadId = p_fiPrioridadId)
    AND (p_fiTipoMantenimientoId IS NULL OR p_fiTipoMantenimientoId <= 0 OR t.fiTipoMantenimientoId = p_fiTipoMantenimientoId)
    AND (p_fiCategoriaId IS NULL OR p_fiCategoriaId <= 0 OR t.fiCategoriaId = p_fiCategoriaId)
    AND (p_fcTipoResponsable IS NULL OR TRIM(p_fcTipoResponsable) = '' OR t.fcTipoResponsable = UPPER(TRIM(p_fcTipoResponsable)))
    AND (p_fiTecnicoId IS NULL OR p_fiTecnicoId <= 0 OR t.fiTecnicoId = p_fiTecnicoId)
    AND (p_fiProveedorId IS NULL OR p_fiProveedorId <= 0 OR t.fiProveedorId = p_fiProveedorId)
    AND (p_fdDesde IS NULL OR t.fdFechaIngreso >= p_fdDesde)
    AND (p_fdHasta IS NULL OR t.fdFechaIngreso <= p_fdHasta)
    AND (IFNULL(p_fbSoloAbiertos,0) = 0 OR e.fbFinal = 0)
    AND (p_fcTexto IS NULL OR TRIM(p_fcTexto) = '' OR t.fcNumero LIKE CONCAT('%', TRIM(p_fcTexto), '%')
         OR t.fcDescripcion LIKE CONCAT('%', TRIM(p_fcTexto), '%')
         OR t.fcSolicitanteNombre LIKE CONCAT('%', TRIM(p_fcTexto), '%'))
  ORDER BY t.fdFechaIngreso DESC, t.fiId DESC
  LIMIT v_tam OFFSET v_offset;
END$$

DELIMITER ;
