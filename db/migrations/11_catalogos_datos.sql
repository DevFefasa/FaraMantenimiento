-- 11_catalogos_datos.sql
-- Datos iniciales de catálogos (INSERT IGNORE por fcCodigo / fcClave)
-- Aplicar: docker exec -i MariaLocal sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" faramantenimiento' < db/migrations/11_catalogos_datos.sql

SET NAMES utf8mb4;

-- Regiones de Honduras
INSERT IGNORE INTO region (fcCodigo, fcNombre, fbActivo) VALUES
  ('CENTRO', 'Centro', 1),
  ('NORTE', 'Norte', 1),
  ('OCCIDENTE', 'Occidente', 1),
  ('ORIENTE', 'Oriente', 1),
  ('SUR', 'Sur', 1),
  ('ATLANTICO', 'Atlántico', 1);

-- Oficina Central (área) en región Centro
INSERT IGNORE INTO sucursal (fcCodigo, fcNombre, fcTipo, fiRegionId, fcDireccion, fcTelefono, fbActivo)
SELECT 'OFICINA_CENTRAL', 'Oficina Central', 'AREA', r.fiId, NULL, NULL, 1
FROM region r
WHERE r.fcCodigo = 'CENTRO'
  AND NOT EXISTS (SELECT 1 FROM sucursal s WHERE s.fcCodigo = 'OFICINA_CENTRAL');

-- Tipos de mantenimiento (7)
INSERT IGNORE INTO tipomantenimiento
  (fcCodigo, fcNombre, fbRequiereAprobacion, fbEsPreventivo, fbEsPostFalla, fbRequiereFechaSugerida, fiOrden, fbActivo)
VALUES
  ('CORRECTIVO', 'Correctivo', 1, 0, 0, 0, 1, 1),
  ('PREVENTIVO', 'Preventivo', 1, 1, 0, 0, 2, 1),
  ('PREDICTIVO', 'Predictivo', 1, 0, 0, 0, 3, 1),
  ('PROGRAMADO', 'Programado / planificado', 1, 0, 0, 1, 4, 1),
  ('EMERGENCIA', 'Emergencia', 0, 0, 0, 0, 5, 1),
  ('MEJORA', 'Mejora o adecuación', 1, 0, 0, 0, 6, 1),
  ('POST_FALLA', 'Análisis post-falla', 1, 0, 1, 0, 7, 1);

-- Categorías / especialidades (12)
INSERT IGNORE INTO categoria (fcCodigo, fcNombre, fiOrden, fbActivo) VALUES
  ('ELECTRICO', 'Eléctrico', 1, 1),
  ('PLOMERIA', 'Plomería e hidrosanitario', 2, 1),
  ('AIRE_ACONDICIONADO', 'Aire acondicionado y ventilación', 3, 1),
  ('OBRA_CIVIL', 'Obra civil e infraestructura', 4, 1),
  ('ESTRUCTURAS', 'Estructuras y estanterías', 5, 1),
  ('PUERTAS', 'Puertas, cortinas y portones', 6, 1),
  ('MONTACARGAS', 'Montacargas y equipo de carga', 7, 1),
  ('PLANTAS_ELECTRICAS', 'Plantas eléctricas', 8, 1),
  ('SEGURIDAD', 'Sistemas de seguridad', 9, 1),
  ('ILUMINACION', 'Iluminación', 10, 1),
  ('SENALIZACION', 'Señalización', 11, 1),
  ('OTROS', 'Otros', 12, 1);

-- Prioridades con SLA (horas corridas)
INSERT IGNORE INTO prioridad
  (fcCodigo, fcNombre, fiHorasRespuesta, fiHorasSolucion, fcColor, fiOrden, fbActivo)
VALUES
  ('CRITICA', 'Crítica', 2, 24, '#dc3545', 1, 1),
  ('ALTA', 'Alta', 8, 72, '#fd7e14', 2, 1),
  ('MEDIA', 'Media', 24, 168, '#ffc107', 3, 1),
  ('BAJA', 'Baja', 48, 336, '#28a745', 4, 1);

-- Estados del flujo
INSERT IGNORE INTO estado (fcCodigo, fcNombre, fiOrden, fcColor, fbFinal, fbActivo) VALUES
  ('RECIBIDO', 'Recibido', 1, '#6c757d', 0, 1),
  ('EN_EVALUACION', 'En evaluación', 2, '#17a2b8', 0, 1),
  ('APROBADO', 'Aprobado', 3, '#20c997', 0, 1),
  ('RECHAZADO', 'Rechazado', 4, '#dc3545', 1, 1),
  ('ASIGNADO', 'Asignado', 5, '#007bff', 0, 1),
  ('EN_PROCESO', 'En proceso', 6, '#6610f2', 0, 1),
  ('EN_ESPERA', 'En espera', 7, '#fd7e14', 0, 1),
  ('RESUELTO', 'Resuelto', 8, '#28a745', 0, 1),
  ('VALIDADO', 'Validado', 9, '#218838', 0, 1),
  ('CERRADO', 'Cerrado', 10, '#343a40', 1, 1);

-- Motivos de espera
INSERT IGNORE INTO motivoespera (fcCodigo, fcNombre, fiOrden, fbActivo) VALUES
  ('MATERIALES', 'Materiales', 1, 1),
  ('PROVEEDOR', 'Proveedor', 2, 1),
  ('PRESUPUESTO', 'Presupuesto', 3, 1),
  ('AUTORIZACION', 'Autorización', 4, 1);

-- Parámetros del sistema
INSERT IGNORE INTO parametro (fcClave, fcValor, fcDescripcion, fbActivo) VALUES
  ('DIAS_CIERRE_AUTOMATICO', '5', 'Días sin validar en RESUELTO antes de cierre automático', 1),
  ('DIAS_REINCIDENCIA', '90', 'Días hacia atrás para marcar reincidencia (mismo activo y categoría)', 1),
  ('MONEDA', 'LPS', 'Moneda de costos (Lempiras)', 1),
  ('PREFIJO_TICKET', 'TK', 'Prefijo del número de ticket (TK-AAAA-000001)', 1);
