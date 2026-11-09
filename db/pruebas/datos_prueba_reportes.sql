-- db/pruebas/datos_prueba_reportes.sql
-- Datos de prueba SOLO para reportes/dashboard. NO es migración.
-- Idempotente parcial: limpia tickets de prueba por prefijo TP- y recrea catálogos auxiliares si faltan.
-- Aplicar: docker exec -i MariaLocal sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" faramantenimiento' < db/pruebas/datos_prueba_reportes.sql

SET NAMES utf8mb4;

-- Sucursales de prueba
INSERT INTO sucursal (fcCodigo, fcNombre, fcTipo, fiRegionId, fbActivo)
SELECT 'SPS_PRUEBA', 'SPS Prueba', 'SUCURSAL', r.fiId, 1 FROM region r WHERE r.fcCodigo='NORTE'
  AND NOT EXISTS (SELECT 1 FROM sucursal WHERE fcCodigo='SPS_PRUEBA');
INSERT INTO sucursal (fcCodigo, fcNombre, fcTipo, fiRegionId, fbActivo)
SELECT 'TGU_PRUEBA', 'TGU Prueba', 'SUCURSAL', r.fiId, 1 FROM region r WHERE r.fcCodigo='CENTRO'
  AND NOT EXISTS (SELECT 1 FROM sucursal WHERE fcCodigo='TGU_PRUEBA');

-- Ubicaciones
INSERT INTO ubicacion (fcCodigo, fcNombre, fiSucursalId, fbActivo)
SELECT 'SPS_PISO1', 'Piso 1', s.fiId, 1 FROM sucursal s WHERE s.fcCodigo='SPS_PRUEBA'
  AND NOT EXISTS (SELECT 1 FROM ubicacion WHERE fcCodigo='SPS_PISO1');
INSERT INTO ubicacion (fcCodigo, fcNombre, fiSucursalId, fbActivo)
SELECT 'TGU_BODEGA', 'Bodega', s.fiId, 1 FROM sucursal s WHERE s.fcCodigo='TGU_PRUEBA'
  AND NOT EXISTS (SELECT 1 FROM ubicacion WHERE fcCodigo='TGU_BODEGA');

-- Activos
INSERT INTO activo (fcCodigo, fcNombre, fiSucursalId, fiUbicacionId, fiCategoriaId, fbActivo)
SELECT 'AC-AA-01', 'Aire acondicionado sala', s.fiId, u.fiId, c.fiId, 1
FROM sucursal s, ubicacion u, categoria c
WHERE s.fcCodigo='SPS_PRUEBA' AND u.fcCodigo='SPS_PISO1' AND c.fcCodigo='AIRE_ACONDICIONADO'
  AND NOT EXISTS (SELECT 1 FROM activo WHERE fcCodigo='AC-AA-01');
INSERT INTO activo (fcCodigo, fcNombre, fiSucursalId, fiUbicacionId, fiCategoriaId, fbActivo)
SELECT 'AC-EL-01', 'Tablero eléctrico principal', s.fiId, u.fiId, c.fiId, 1
FROM sucursal s, ubicacion u, categoria c
WHERE s.fcCodigo='TGU_PRUEBA' AND u.fcCodigo='TGU_BODEGA' AND c.fcCodigo='ELECTRICO'
  AND NOT EXISTS (SELECT 1 FROM activo WHERE fcCodigo='AC-EL-01');

-- Técnicos y proveedores
INSERT INTO tecnico (fcCodigo, fcNombre, fcTelefono, fiCategoriaId, fbActivo)
SELECT 'TEC-01', 'Juan Técnico', '9999-0001', c.fiId, 1 FROM categoria c WHERE c.fcCodigo='ELECTRICO'
  AND NOT EXISTS (SELECT 1 FROM tecnico WHERE fcCodigo='TEC-01');
INSERT INTO tecnico (fcCodigo, fcNombre, fcTelefono, fiCategoriaId, fbActivo)
SELECT 'TEC-02', 'María Técnica', '9999-0002', c.fiId, 1 FROM categoria c WHERE c.fcCodigo='AIRE_ACONDICIONADO'
  AND NOT EXISTS (SELECT 1 FROM tecnico WHERE fcCodigo='TEC-02');
INSERT INTO proveedor (fcCodigo, fcNombre, fcEspecialidad, fbActivo)
SELECT 'PROV-01', 'Servicios Frío SA', 'Aire acondicionado', 1
  FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM proveedor WHERE fcCodigo='PROV-01');

-- Limpiar tickets de prueba anteriores (y dependencias)
DELETE te FROM ticketencuesta te INNER JOIN ticket t ON t.fiId=te.fiTicketId WHERE t.fcNumero LIKE 'TP-%';
DELETE tm FROM ticketmaterial tm INNER JOIN ticket t ON t.fiId=tm.fiTicketId WHERE t.fcNumero LIKE 'TP-%';
DELETE th FROM ticketestado th INNER JOIN ticket t ON t.fiId=th.fiTicketId WHERE t.fcNumero LIKE 'TP-%';
DELETE FROM ticket WHERE fcNumero LIKE 'TP-%';

-- Variables de ids
SET @suc_sps = (SELECT fiId FROM sucursal WHERE fcCodigo='SPS_PRUEBA' LIMIT 1);
SET @suc_tgu = (SELECT fiId FROM sucursal WHERE fcCodigo='TGU_PRUEBA' LIMIT 1);
SET @ubi_sps = (SELECT fiId FROM ubicacion WHERE fcCodigo='SPS_PISO1' LIMIT 1);
SET @ubi_tgu = (SELECT fiId FROM ubicacion WHERE fcCodigo='TGU_BODEGA' LIMIT 1);
SET @act_aa = (SELECT fiId FROM activo WHERE fcCodigo='AC-AA-01' LIMIT 1);
SET @act_el = (SELECT fiId FROM activo WHERE fcCodigo='AC-EL-01' LIMIT 1);
SET @tipo_corr = (SELECT fiId FROM tipomantenimiento WHERE fcCodigo='CORRECTIVO' LIMIT 1);
SET @tipo_prev = (SELECT fiId FROM tipomantenimiento WHERE fcCodigo='PREVENTIVO' LIMIT 1);
SET @tipo_eme = (SELECT fiId FROM tipomantenimiento WHERE fcCodigo='EMERGENCIA' LIMIT 1);
SET @cat_aa = (SELECT fiId FROM categoria WHERE fcCodigo='AIRE_ACONDICIONADO' LIMIT 1);
SET @cat_el = (SELECT fiId FROM categoria WHERE fcCodigo='ELECTRICO' LIMIT 1);
SET @pri_cri = (SELECT fiId FROM prioridad WHERE fcCodigo='CRITICA' LIMIT 1);
SET @pri_alt = (SELECT fiId FROM prioridad WHERE fcCodigo='ALTA' LIMIT 1);
SET @pri_med = (SELECT fiId FROM prioridad WHERE fcCodigo='MEDIA' LIMIT 1);
SET @pri_baj = (SELECT fiId FROM prioridad WHERE fcCodigo='BAJA' LIMIT 1);
SET @est_rec = (SELECT fiId FROM estado WHERE fcCodigo='RECIBIDO' LIMIT 1);
SET @est_pro = (SELECT fiId FROM estado WHERE fcCodigo='EN_PROCESO' LIMIT 1);
SET @est_esp = (SELECT fiId FROM estado WHERE fcCodigo='EN_ESPERA' LIMIT 1);
SET @est_res = (SELECT fiId FROM estado WHERE fcCodigo='RESUELTO' LIMIT 1);
SET @est_cer = (SELECT fiId FROM estado WHERE fcCodigo='CERRADO' LIMIT 1);
SET @est_asi = (SELECT fiId FROM estado WHERE fcCodigo='ASIGNADO' LIMIT 1);
SET @tec1 = (SELECT fiId FROM tecnico WHERE fcCodigo='TEC-01' LIMIT 1);
SET @tec2 = (SELECT fiId FROM tecnico WHERE fcCodigo='TEC-02' LIMIT 1);
SET @prov1 = (SELECT fiId FROM proveedor WHERE fcCodigo='PROV-01' LIMIT 1);

-- Tickets variados (últimos 4 meses)
INSERT INTO ticket (
  fcNumero, fdFechaIngreso, fcSolicitanteNombre, fiSucursalId, fiUbicacionId, fiActivoId,
  fiTipoMantenimientoId, fiCategoriaId, fiPrioridadId, fcDescripcion, fiEstadoId,
  fcTipoResponsable, fiTecnicoId, fiProveedorId, fdPrimeraRespuesta, fdResuelto, fdCerrado,
  fiMinutosEnEspera, fbSlaRespuestaCumplido, fbSlaSolucionCumplido, fbReincidencia,
  fnHorasTrabajadas, fnCostoManoObra, fnCostoMateriales, fnCostoProveedor, fbActivo
) VALUES
('TP-2026-0001', DATE_SUB(NOW(), INTERVAL 90 DAY), 'Gerente SPS', @suc_sps, @ubi_sps, @act_aa,
 @tipo_corr, @cat_aa, @pri_alt, 'Fuga de gas en AA', @est_cer, 'INTERNO', @tec2, NULL,
 DATE_SUB(NOW(), INTERVAL 89 DAY), DATE_SUB(NOW(), INTERVAL 85 DAY), DATE_SUB(NOW(), INTERVAL 84 DAY),
 120, 1, 1, 0, 6.5, 1500.00, 800.00, 0, 1),
('TP-2026-0002', DATE_SUB(NOW(), INTERVAL 70 DAY), 'Gerente SPS', @suc_sps, @ubi_sps, @act_aa,
 @tipo_corr, @cat_aa, @pri_cri, 'AA no enfría (reincidencia)', @est_cer, 'PROVEEDOR', NULL, @prov1,
 DATE_SUB(NOW(), INTERVAL 70 DAY), DATE_SUB(NOW(), INTERVAL 68 DAY), DATE_SUB(NOW(), INTERVAL 67 DAY),
 0, 1, 0, 1, 8.0, 0, 500.00, 4500.00, 1),
('TP-2026-0003', DATE_SUB(NOW(), INTERVAL 55 DAY), 'Gerente TGU', @suc_tgu, @ubi_tgu, @act_el,
 @tipo_eme, @cat_el, @pri_cri, 'Corte eléctrico parcial', @est_cer, 'INTERNO', @tec1, NULL,
 DATE_SUB(NOW(), INTERVAL 55 DAY), DATE_SUB(NOW(), INTERVAL 54 DAY), DATE_SUB(NOW(), INTERVAL 53 DAY),
 0, 1, 1, 0, 4.0, 900.00, 1200.00, 0, 1),
('TP-2026-0004', DATE_SUB(NOW(), INTERVAL 40 DAY), 'Gerente TGU', @suc_tgu, @ubi_tgu, @act_el,
 @tipo_prev, @cat_el, @pri_med, 'Mantenimiento preventivo tablero', @est_cer, 'INTERNO', @tec1, NULL,
 DATE_SUB(NOW(), INTERVAL 39 DAY), DATE_SUB(NOW(), INTERVAL 38 DAY), DATE_SUB(NOW(), INTERVAL 37 DAY),
 0, 1, 1, 0, 3.0, 700.00, 200.00, 0, 1),
('TP-2026-0005', DATE_SUB(NOW(), INTERVAL 25 DAY), 'Gerente SPS', @suc_sps, @ubi_sps, @act_aa,
 @tipo_prev, @cat_aa, @pri_baj, 'Limpieza preventiva AA', @est_res, 'INTERNO', @tec2, NULL,
 DATE_SUB(NOW(), INTERVAL 24 DAY), DATE_SUB(NOW(), INTERVAL 22 DAY), NULL,
 60, 1, 1, 0, 2.5, 400.00, 150.00, 0, 1),
('TP-2026-0006', DATE_SUB(NOW(), INTERVAL 15 DAY), 'Gerente TGU', @suc_tgu, @ubi_tgu, @act_el,
 @tipo_corr, @cat_el, @pri_alt, 'Falla en breaker', @est_pro, 'INTERNO', @tec1, NULL,
 DATE_SUB(NOW(), INTERVAL 14 DAY), NULL, NULL,
 0, 1, NULL, 0, 1.5, 300.00, 0, 0, 1),
('TP-2026-0007', DATE_SUB(NOW(), INTERVAL 10 DAY), 'Gerente SPS', @suc_sps, @ubi_sps, @act_aa,
 @tipo_corr, @cat_aa, @pri_med, 'Ruido en condensadora', @est_esp, 'PROVEEDOR', NULL, @prov1,
 DATE_SUB(NOW(), INTERVAL 9 DAY), NULL, NULL,
 480, 1, NULL, 0, 0, 0, 0, 0, 1),
('TP-2026-0008', DATE_SUB(NOW(), INTERVAL 5 DAY), 'Gerente TGU', @suc_tgu, @ubi_tgu, NULL,
 @tipo_corr, @cat_el, @pri_baj, 'Cambio de luminaria', @est_asi, 'INTERNO', @tec1, NULL,
 NULL, NULL, NULL, 0, NULL, NULL, 0, 0, 0, 0, 0, 1),
('TP-2026-0009', DATE_SUB(NOW(), INTERVAL 2 DAY), 'Gerente SPS', @suc_sps, @ubi_sps, @act_aa,
 @tipo_corr, @cat_aa, @pri_alt, 'Fuga de agua en charola', @est_rec, NULL, NULL, NULL,
 NULL, NULL, NULL, 0, NULL, NULL, 1, 0, 0, 0, 0, 1),
('TP-2026-0010', DATE_SUB(NOW(), INTERVAL 1 DAY), 'Gerente TGU', @suc_tgu, @ubi_tgu, @act_el,
 @tipo_eme, @cat_el, @pri_cri, 'Olor a quemado en tablero', @est_pro, 'INTERNO', @tec1, NULL,
 DATE_SUB(NOW(), INTERVAL 1 DAY), NULL, NULL, 0, 1, NULL, 0, 2.0, 500.00, 0, 0, 1);

-- Encuestas en cerrados/resueltos
INSERT INTO ticketencuesta (fiTicketId, fiCalificacion, fbConforme, fcComentario, fdFecha)
SELECT t.fiId, 5, 1, 'Excelente', DATE_ADD(t.fdResuelto, INTERVAL 1 DAY) FROM ticket t WHERE t.fcNumero='TP-2026-0001';
INSERT INTO ticketencuesta (fiTicketId, fiCalificacion, fbConforme, fcComentario, fdFecha)
SELECT t.fiId, 3, 0, 'Tardó más de lo esperado', DATE_ADD(t.fdResuelto, INTERVAL 1 DAY) FROM ticket t WHERE t.fcNumero='TP-2026-0002';
INSERT INTO ticketencuesta (fiTicketId, fiCalificacion, fbConforme, fcComentario, fdFecha)
SELECT t.fiId, 4, 1, 'Bien', DATE_ADD(t.fdResuelto, INTERVAL 1 DAY) FROM ticket t WHERE t.fcNumero='TP-2026-0003';
INSERT INTO ticketencuesta (fiTicketId, fiCalificacion, fbConforme, fcComentario, fdFecha)
SELECT t.fiId, 5, 1, 'Preventivo a tiempo', DATE_ADD(t.fdResuelto, INTERVAL 1 DAY) FROM ticket t WHERE t.fcNumero='TP-2026-0004';
INSERT INTO ticketencuesta (fiTicketId, fiCalificacion, fbConforme, fcComentario, fdFecha)
SELECT t.fiId, 4, 1, 'OK', DATE_ADD(t.fdResuelto, INTERVAL 1 DAY) FROM ticket t WHERE t.fcNumero='TP-2026-0005';

SELECT 'Datos de prueba de reportes cargados' AS fcMensaje;
