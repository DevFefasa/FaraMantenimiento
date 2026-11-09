-- 01_seguridad_tablas.sql
-- Tablas de seguridad (sin FK a sucursal: solo índice; migraciones 10-19 en paralelo)
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS rol (
  fiId INT NOT NULL AUTO_INCREMENT,
  fcCodigo VARCHAR(30) NOT NULL,
  fcNombre VARCHAR(100) NOT NULL,
  fcDescripcion VARCHAR(250) NULL,
  fdCreado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fiCreadoPor INT NULL,
  fdModificado DATETIME NULL,
  fiModificadoPor INT NULL,
  fbActivo TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (fiId),
  UNIQUE KEY uk_rol_codigo (fcCodigo),
  KEY ix_rol_activo (fbActivo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS pantalla (
  fiId INT NOT NULL AUTO_INCREMENT,
  fcCodigo VARCHAR(50) NOT NULL,
  fcNombre VARCHAR(100) NOT NULL,
  fcDescripcion VARCHAR(250) NULL,
  fiOrden INT NOT NULL DEFAULT 0,
  fdCreado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fiCreadoPor INT NULL,
  fdModificado DATETIME NULL,
  fiModificadoPor INT NULL,
  fbActivo TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (fiId),
  UNIQUE KEY uk_pantalla_codigo (fcCodigo),
  KEY ix_pantalla_orden (fiOrden),
  KEY ix_pantalla_activo (fbActivo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS usuario (
  fiId INT NOT NULL AUTO_INCREMENT,
  fcUsuario VARCHAR(100) NOT NULL,
  fcNombre VARCHAR(150) NOT NULL,
  fcCargo VARCHAR(100) NULL,
  fcCorreo VARCHAR(150) NULL,
  fcTelefono VARCHAR(40) NULL,
  fiRolId INT NOT NULL,
  fiSucursalId INT NULL COMMENT 'Sin FK a sucursal (orden 01 vs 10); solo índice',
  fbEsLocal TINYINT(1) NOT NULL DEFAULT 0,
  fcClaveHash VARCHAR(128) NULL,
  fbActivo TINYINT(1) NOT NULL DEFAULT 1,
  fdUltimoAcceso DATETIME NULL,
  fdCreado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fiCreadoPor INT NULL,
  fdModificado DATETIME NULL,
  fiModificadoPor INT NULL,
  PRIMARY KEY (fiId),
  UNIQUE KEY uk_usuario_usuario (fcUsuario),
  KEY ix_usuario_rol (fiRolId),
  KEY ix_usuario_sucursal (fiSucursalId),
  KEY ix_usuario_activo (fbActivo),
  KEY ix_usuario_creadopor (fiCreadoPor),
  CONSTRAINT fk_usuario_rol FOREIGN KEY (fiRolId) REFERENCES rol (fiId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS rolpermiso (
  fiId INT NOT NULL AUTO_INCREMENT,
  fiRolId INT NOT NULL,
  fiPantallaId INT NOT NULL,
  fdCreado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fiCreadoPor INT NULL,
  PRIMARY KEY (fiId),
  UNIQUE KEY uk_rolpermiso_rol_pantalla (fiRolId, fiPantallaId),
  KEY ix_rolpermiso_pantalla (fiPantallaId),
  CONSTRAINT fk_rolpermiso_rol FOREIGN KEY (fiRolId) REFERENCES rol (fiId),
  CONSTRAINT fk_rolpermiso_pantalla FOREIGN KEY (fiPantallaId) REFERENCES pantalla (fiId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS bitacoraacceso (
  fiId INT NOT NULL AUTO_INCREMENT,
  fiUsuarioId INT NULL,
  fcUsuario VARCHAR(100) NULL,
  fcAccion VARCHAR(50) NOT NULL COMMENT 'LOGIN_OK, LOGIN_FAIL, LOGOUT',
  fcIp VARCHAR(45) NULL,
  fcDetalle VARCHAR(500) NULL,
  fdFecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (fiId),
  KEY ix_bitacoraacceso_usuario (fiUsuarioId),
  KEY ix_bitacoraacceso_fecha (fdFecha),
  KEY ix_bitacoraacceso_accion (fcAccion)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
