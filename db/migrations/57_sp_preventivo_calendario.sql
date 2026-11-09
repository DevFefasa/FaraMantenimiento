-- 57_sp_preventivo_calendario.sql
-- Callers: PreventivoRepositorio.CalendarioAsync; PreventivosController.Calendario
-- API: sp_preventivo_calendario(p_fdDesde, p_fdHasta)
-- Schema: fila estándar + eventos (ejecutados + proyectados) por plan activo
-- User instruction: "sp_preventivo_calendario(desde,hasta) con fechas programadas proyectadas por plan"
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_preventivo_calendario;

DELIMITER $$

CREATE PROCEDURE sp_preventivo_calendario(
  IN p_fdDesde DATE,
  IN p_fdHasta DATE
)
proc: BEGIN
  DECLARE v_desde DATE;
  DECLARE v_hasta DATE;
  DECLARE done INT DEFAULT 0;
  DECLARE v_planId INT; DECLARE v_nombre VARCHAR(150); DECLARE v_sucId INT; DECLARE v_sucNom VARCHAR(150);
  DECLARE v_actId INT; DECLARE v_actNom VARCHAR(150); DECLARE v_prox DATE; DECLARE v_freq INT;
  DECLARE v_d DATE;

  DECLARE cur CURSOR FOR
    SELECT p.fiId, p.fcNombre, p.fiSucursalId, s.fcNombre, p.fiActivoId, a.fcNombre, p.fdProximaFecha, p.fiFrecuenciaDias
    FROM planpreventivo p
    JOIN sucursal s ON s.fiId = p.fiSucursalId
    LEFT JOIN activo a ON a.fiId = p.fiActivoId
    WHERE p.fbActivo = 1 AND p.fiFrecuenciaDias > 0;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

  IF p_fdDesde IS NULL OR p_fdHasta IS NULL OR p_fdHasta < p_fdDesde THEN
    SELECT 400 AS fiCodigo, 'El rango de fechas no es válido' AS fcMensaje, 0 AS fbSucces, NULL AS fjData;
    LEAVE proc;
  END IF;

  SET v_desde = p_fdDesde;
  SET v_hasta = p_fdHasta;

  DROP TEMPORARY TABLE IF EXISTS tmp_prev_cal;
  CREATE TEMPORARY TABLE tmp_prev_cal (
    fiPlanId INT NOT NULL,
    fcNombre VARCHAR(150) NOT NULL,
    fiSucursalId INT NOT NULL,
    fcSucursalNombre VARCHAR(150) NULL,
    fiActivoId INT NULL,
    fcActivoNombre VARCHAR(150) NULL,
    fdFecha DATE NOT NULL,
    fiTicketId INT NULL,
    fcTicketNumero VARCHAR(30) NULL,
    fcEstadoCodigo VARCHAR(30) NULL,
    fcEstadoNombre VARCHAR(100) NULL,
    fbProyectado TINYINT(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (fiPlanId, fdFecha)
  ) ENGINE=MEMORY;

  INSERT IGNORE INTO tmp_prev_cal (
    fiPlanId, fcNombre, fiSucursalId, fcSucursalNombre, fiActivoId, fcActivoNombre,
    fdFecha, fiTicketId, fcTicketNumero, fcEstadoCodigo, fcEstadoNombre, fbProyectado
  )
  SELECT
    p.fiId, p.fcNombre, p.fiSucursalId, s.fcNombre, p.fiActivoId, a.fcNombre,
    e.fdFechaProgramada, e.fiTicketId, tk.fcNumero, est.fcCodigo, est.fcNombre, 0
  FROM planpreventivoejecucion e
  JOIN planpreventivo p ON p.fiId = e.fiPlanId
  JOIN sucursal s ON s.fiId = p.fiSucursalId
  LEFT JOIN activo a ON a.fiId = p.fiActivoId
  LEFT JOIN ticket tk ON tk.fiId = e.fiTicketId
  LEFT JOIN estado est ON est.fiId = tk.fiEstadoId
  WHERE p.fbActivo = 1
    AND e.fdFechaProgramada BETWEEN v_desde AND v_hasta;

  OPEN cur;
  read_loop: LOOP
    FETCH cur INTO v_planId, v_nombre, v_sucId, v_sucNom, v_actId, v_actNom, v_prox, v_freq;
    IF done = 1 THEN LEAVE read_loop; END IF;

    SET v_d = v_prox;
    WHILE v_d > v_hasta DO
      SET v_d = DATE_SUB(v_d, INTERVAL v_freq DAY);
    END WHILE;
    WHILE v_d >= v_desde DO
      INSERT IGNORE INTO tmp_prev_cal (
        fiPlanId, fcNombre, fiSucursalId, fcSucursalNombre, fiActivoId, fcActivoNombre,
        fdFecha, fiTicketId, fcTicketNumero, fcEstadoCodigo, fcEstadoNombre, fbProyectado
      ) VALUES (v_planId, v_nombre, v_sucId, v_sucNom, v_actId, v_actNom, v_d, NULL, NULL, NULL, NULL, 1);
      SET v_d = DATE_SUB(v_d, INTERVAL v_freq DAY);
    END WHILE;

    SET v_d = v_prox;
    WHILE v_d < v_desde DO
      SET v_d = DATE_ADD(v_d, INTERVAL v_freq DAY);
    END WHILE;
    WHILE v_d <= v_hasta DO
      INSERT IGNORE INTO tmp_prev_cal (
        fiPlanId, fcNombre, fiSucursalId, fcSucursalNombre, fiActivoId, fcActivoNombre,
        fdFecha, fiTicketId, fcTicketNumero, fcEstadoCodigo, fcEstadoNombre, fbProyectado
      ) VALUES (v_planId, v_nombre, v_sucId, v_sucNom, v_actId, v_actNom, v_d, NULL, NULL, NULL, NULL, 1);
      SET v_d = DATE_ADD(v_d, INTERVAL v_freq DAY);
    END WHILE;
  END LOOP;
  CLOSE cur;

  UPDATE tmp_prev_cal c
  JOIN planpreventivoejecucion e ON e.fiPlanId = c.fiPlanId AND e.fdFechaProgramada = c.fdFecha
  LEFT JOIN ticket tk ON tk.fiId = e.fiTicketId
  LEFT JOIN estado est ON est.fiId = tk.fiEstadoId
  SET c.fiTicketId = e.fiTicketId,
      c.fcTicketNumero = tk.fcNumero,
      c.fcEstadoCodigo = est.fcCodigo,
      c.fcEstadoNombre = est.fcNombre,
      c.fbProyectado = 0;

  SELECT 200 AS fiCodigo, 'OK' AS fcMensaje, 1 AS fbSucces,
         JSON_OBJECT('desde', v_desde, 'hasta', v_hasta) AS fjData;

  SELECT fiPlanId, fcNombre, fiSucursalId, fcSucursalNombre, fiActivoId, fcActivoNombre,
         fdFecha, fiTicketId, fcTicketNumero, fcEstadoCodigo, fcEstadoNombre, fbProyectado
  FROM tmp_prev_cal
  ORDER BY fdFecha, fcNombre;

  DROP TEMPORARY TABLE IF EXISTS tmp_prev_cal;
END$$

DELIMITER ;
