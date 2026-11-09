-- 19_sp_catalogo_combos.sql
-- Callers: docker exec MariaLocal; CatalogoRepositorio / selects de formularios (futuro)
-- API: sp_catalogo_combos
-- Schema: result sets de catálogos activos (region, sucursal, ubicacion, activo, tipomantenimiento, categoria, prioridad, estado, motivoespera, proveedor, tecnico)
-- User instruction: "sp_catalogo_combos que devuelva tras la fila estandar un result set por catalogo activo ... para llenar selects"
-- Aplicar: docker exec -i MariaLocal sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" faramantenimiento' < db/migrations/19_sp_catalogo_combos.sql

SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_catalogo_combos;

DELIMITER $$

CREATE PROCEDURE sp_catalogo_combos()
BEGIN
  -- 1) Fila estándar
  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces, NULL AS fjData;

  -- 2) Regiones
  SELECT r.fiId, r.fcCodigo, r.fcNombre
  FROM region r
  WHERE r.fbActivo = 1
  ORDER BY r.fcNombre;

  -- 3) Sucursales
  SELECT s.fiId, s.fcCodigo, s.fcNombre, s.fcTipo, s.fiRegionId
  FROM sucursal s
  WHERE s.fbActivo = 1
  ORDER BY s.fcNombre;

  -- 4) Ubicaciones
  SELECT u.fiId, u.fcCodigo, u.fcNombre, u.fiSucursalId
  FROM ubicacion u
  WHERE u.fbActivo = 1
  ORDER BY u.fcNombre;

  -- 5) Activos
  SELECT a.fiId, a.fcCodigo, a.fcNombre, a.fiSucursalId, a.fiUbicacionId, a.fiCategoriaId
  FROM activo a
  WHERE a.fbActivo = 1
  ORDER BY a.fcNombre;

  -- 6) Tipos de mantenimiento
  SELECT t.fiId, t.fcCodigo, t.fcNombre, t.fbRequiereAprobacion, t.fbEsPreventivo,
         t.fbEsPostFalla, t.fbRequiereFechaSugerida, t.fiOrden
  FROM tipomantenimiento t
  WHERE t.fbActivo = 1
  ORDER BY t.fiOrden, t.fcNombre;

  -- 7) Categorías
  SELECT c.fiId, c.fcCodigo, c.fcNombre, c.fiOrden
  FROM categoria c
  WHERE c.fbActivo = 1
  ORDER BY c.fiOrden, c.fcNombre;

  -- 8) Prioridades
  SELECT p.fiId, p.fcCodigo, p.fcNombre, p.fiHorasRespuesta, p.fiHorasSolucion, p.fcColor, p.fiOrden
  FROM prioridad p
  WHERE p.fbActivo = 1
  ORDER BY p.fiOrden, p.fcNombre;

  -- 9) Estados
  SELECT e.fiId, e.fcCodigo, e.fcNombre, e.fiOrden, e.fcColor, e.fbFinal
  FROM estado e
  WHERE e.fbActivo = 1
  ORDER BY e.fiOrden, e.fcNombre;

  -- 10) Motivos de espera
  SELECT m.fiId, m.fcCodigo, m.fcNombre, m.fiOrden
  FROM motivoespera m
  WHERE m.fbActivo = 1
  ORDER BY m.fiOrden, m.fcNombre;

  -- 11) Proveedores
  SELECT pr.fiId, pr.fcCodigo, pr.fcNombre, pr.fcEspecialidad
  FROM proveedor pr
  WHERE pr.fbActivo = 1
  ORDER BY pr.fcNombre;

  -- 12) Técnicos
  SELECT te.fiId, te.fcCodigo, te.fcNombre, te.fiCategoriaId, te.fcTelefono
  FROM tecnico te
  WHERE te.fbActivo = 1
  ORDER BY te.fcNombre;
END$$

DELIMITER ;
