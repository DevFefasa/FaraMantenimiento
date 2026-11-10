-- 79_sp_seguridad_correo_pendiente.sql
-- Callers: CorreoPendienteRepositorio.GuardarAsync; CorreoPendienteServicio (bienvenida).
-- API: sp_seguridad_correo_pendiente_guardar(...).
-- Schema: correopendiente (75). Cuerpo cifrado en C#; sin prod data.
-- User instruction: "guarda ahi el correo de bienvenida con la clave CIFRADA" + "75-79".
SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_seguridad_correo_pendiente_guardar;

DELIMITER $$

CREATE PROCEDURE sp_seguridad_correo_pendiente_guardar(
  IN p_fcPara VARCHAR(150),
  IN p_fcAsunto VARCHAR(250),
  IN p_fcCuerpoCifrado TEXT,
  IN p_fcTipo VARCHAR(40),
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
  IF p_fcCuerpoCifrado IS NULL OR TRIM(p_fcCuerpoCifrado) = '' THEN
    SELECT 400 AS fiCodigo, 'El cuerpo del correo es obligatorio' AS fcMensaje, 0 AS fbSucces, NULL AS fjData; LEAVE proc;
  END IF;

  START TRANSACTION;
  INSERT INTO correopendiente (fcPara, fcAsunto, fcCuerpoCifrado, fcTipo, fbEnviado, fiIntentos, fiCreadoPor)
  VALUES (
    TRIM(p_fcPara),
    TRIM(p_fcAsunto),
    p_fcCuerpoCifrado,
    IFNULL(NULLIF(TRIM(p_fcTipo),''), 'BIENVENIDA'),
    0, 0,
    IF(p_fiUsuarioId IS NULL OR p_fiUsuarioId <= 0, NULL, p_fiUsuarioId)
  );
  SET v_id = LAST_INSERT_ID();
  COMMIT;
  SELECT 201 AS fiCodigo, 'Correo encolado correctamente' AS fcMensaje, 1 AS fbSucces,
         JSON_OBJECT('correopendiente', v_id) AS fjData;
END$$

DELIMITER ;
