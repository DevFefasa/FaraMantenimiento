-- 10_catalogos_tablas.sql
-- Catálogos de Fara Mantenimiento (MariaDB 10.4, utf8mb4)
-- Idempotente: CREATE TABLE IF NOT EXISTS
-- Aplicar: docker exec -i MariaLocal sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" faramantenimiento' < db/migrations/10_catalogos_tablas.sql

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS region (
  fiId INT NOT NULL AUTO_INCREMENT,
  fcCodigo VARCHAR(30) NOT NULL,
  fcNombre VARCHAR(100) NOT NULL,
  fdCreado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fiCreadoPor INT NULL,
  fdModificado DATETIME NULL,
  fiModificadoPor INT NULL,
  fbActivo TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (fiId),
  UNIQUE KEY uk_region_codigo (fcCodigo),
  KEY ix_region_activo (fbActivo),
  KEY ix_region_creadopor (fiCreadoPor),
  KEY ix_region_modificadopor (fiModificadoPor)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS sucursal (
  fiId INT NOT NULL AUTO_INCREMENT,
  fcCodigo VARCHAR(30) NOT NULL,
  fcNombre VARCHAR(150) NOT NULL,
  fcTipo VARCHAR(20) NOT NULL COMMENT 'SUCURSAL, AREA, DEPARTAMENTO',
  fiRegionId INT NOT NULL,
  fcDireccion VARCHAR(250) NULL,
  fcTelefono VARCHAR(40) NULL,
  fdCreado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fiCreadoPor INT NULL,
  fdModificado DATETIME NULL,
  fiModificadoPor INT NULL,
  fbActivo TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (fiId),
  UNIQUE KEY uk_sucursal_codigo (fcCodigo),
  KEY ix_sucursal_region (fiRegionId),
  KEY ix_sucursal_tipo (fcTipo),
  KEY ix_sucursal_activo (fbActivo),
  KEY ix_sucursal_creadopor (fiCreadoPor),
  KEY ix_sucursal_modificadopor (fiModificadoPor),
  CONSTRAINT fk_sucursal_region FOREIGN KEY (fiRegionId) REFERENCES region (fiId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ubicacion (
  fiId INT NOT NULL AUTO_INCREMENT,
  fcCodigo VARCHAR(30) NOT NULL,
  fcNombre VARCHAR(150) NOT NULL,
  fiSucursalId INT NOT NULL,
  fdCreado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fiCreadoPor INT NULL,
  fdModificado DATETIME NULL,
  fiModificadoPor INT NULL,
  fbActivo TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (fiId),
  UNIQUE KEY uk_ubicacion_codigo (fcCodigo),
  KEY ix_ubicacion_sucursal (fiSucursalId),
  KEY ix_ubicacion_activo (fbActivo),
  KEY ix_ubicacion_creadopor (fiCreadoPor),
  KEY ix_ubicacion_modificadopor (fiModificadoPor),
  CONSTRAINT fk_ubicacion_sucursal FOREIGN KEY (fiSucursalId) REFERENCES sucursal (fiId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS tipomantenimiento (
  fiId INT NOT NULL AUTO_INCREMENT,
  fcCodigo VARCHAR(30) NOT NULL,
  fcNombre VARCHAR(100) NOT NULL,
  fbRequiereAprobacion TINYINT(1) NOT NULL DEFAULT 1,
  fbEsPreventivo TINYINT(1) NOT NULL DEFAULT 0,
  fbEsPostFalla TINYINT(1) NOT NULL DEFAULT 0,
  fbRequiereFechaSugerida TINYINT(1) NOT NULL DEFAULT 0,
  fiOrden INT NOT NULL DEFAULT 0,
  fdCreado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fiCreadoPor INT NULL,
  fdModificado DATETIME NULL,
  fiModificadoPor INT NULL,
  fbActivo TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (fiId),
  UNIQUE KEY uk_tipomantenimiento_codigo (fcCodigo),
  KEY ix_tipomantenimiento_orden (fiOrden),
  KEY ix_tipomantenimiento_activo (fbActivo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS categoria (
  fiId INT NOT NULL AUTO_INCREMENT,
  fcCodigo VARCHAR(30) NOT NULL,
  fcNombre VARCHAR(150) NOT NULL,
  fiOrden INT NOT NULL DEFAULT 0,
  fdCreado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fiCreadoPor INT NULL,
  fdModificado DATETIME NULL,
  fiModificadoPor INT NULL,
  fbActivo TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (fiId),
  UNIQUE KEY uk_categoria_codigo (fcCodigo),
  KEY ix_categoria_orden (fiOrden),
  KEY ix_categoria_activo (fbActivo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS prioridad (
  fiId INT NOT NULL AUTO_INCREMENT,
  fcCodigo VARCHAR(30) NOT NULL,
  fcNombre VARCHAR(50) NOT NULL,
  fiHorasRespuesta INT NOT NULL,
  fiHorasSolucion INT NOT NULL,
  fcColor VARCHAR(20) NOT NULL DEFAULT '#6c757d',
  fiOrden INT NOT NULL DEFAULT 0,
  fdCreado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fiCreadoPor INT NULL,
  fdModificado DATETIME NULL,
  fiModificadoPor INT NULL,
  fbActivo TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (fiId),
  UNIQUE KEY uk_prioridad_codigo (fcCodigo),
  KEY ix_prioridad_orden (fiOrden),
  KEY ix_prioridad_activo (fbActivo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS estado (
  fiId INT NOT NULL AUTO_INCREMENT,
  fcCodigo VARCHAR(30) NOT NULL,
  fcNombre VARCHAR(80) NOT NULL,
  fiOrden INT NOT NULL DEFAULT 0,
  fcColor VARCHAR(20) NOT NULL DEFAULT '#6c757d',
  fbFinal TINYINT(1) NOT NULL DEFAULT 0,
  fdCreado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fiCreadoPor INT NULL,
  fdModificado DATETIME NULL,
  fiModificadoPor INT NULL,
  fbActivo TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (fiId),
  UNIQUE KEY uk_estado_codigo (fcCodigo),
  KEY ix_estado_orden (fiOrden),
  KEY ix_estado_activo (fbActivo),
  KEY ix_estado_final (fbFinal)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS motivoespera (
  fiId INT NOT NULL AUTO_INCREMENT,
  fcCodigo VARCHAR(30) NOT NULL,
  fcNombre VARCHAR(100) NOT NULL,
  fiOrden INT NOT NULL DEFAULT 0,
  fdCreado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fiCreadoPor INT NULL,
  fdModificado DATETIME NULL,
  fiModificadoPor INT NULL,
  fbActivo TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (fiId),
  UNIQUE KEY uk_motivoespera_codigo (fcCodigo),
  KEY ix_motivoespera_orden (fiOrden),
  KEY ix_motivoespera_activo (fbActivo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS proveedor (
  fiId INT NOT NULL AUTO_INCREMENT,
  fcCodigo VARCHAR(30) NOT NULL,
  fcNombre VARCHAR(150) NOT NULL,
  fcRtn VARCHAR(30) NULL,
  fcContacto VARCHAR(150) NULL,
  fcTelefono VARCHAR(40) NULL,
  fcCorreo VARCHAR(150) NULL,
  fcEspecialidad VARCHAR(150) NULL,
  fdCreado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fiCreadoPor INT NULL,
  fdModificado DATETIME NULL,
  fiModificadoPor INT NULL,
  fbActivo TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (fiId),
  UNIQUE KEY uk_proveedor_codigo (fcCodigo),
  KEY ix_proveedor_activo (fbActivo),
  KEY ix_proveedor_nombre (fcNombre),
  KEY ix_proveedor_creadopor (fiCreadoPor),
  KEY ix_proveedor_modificadopor (fiModificadoPor)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS tecnico (
  fiId INT NOT NULL AUTO_INCREMENT,
  fcCodigo VARCHAR(30) NOT NULL,
  fcNombre VARCHAR(150) NOT NULL,
  fiUsuarioId INT NULL COMMENT 'Sin FK a usuario (migración 01-09 en paralelo); solo índice',
  fcTelefono VARCHAR(40) NULL,
  fiCategoriaId INT NULL,
  fdCreado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fiCreadoPor INT NULL,
  fdModificado DATETIME NULL,
  fiModificadoPor INT NULL,
  fbActivo TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (fiId),
  UNIQUE KEY uk_tecnico_codigo (fcCodigo),
  KEY ix_tecnico_usuario (fiUsuarioId),
  KEY ix_tecnico_categoria (fiCategoriaId),
  KEY ix_tecnico_activo (fbActivo),
  KEY ix_tecnico_creadopor (fiCreadoPor),
  KEY ix_tecnico_modificadopor (fiModificadoPor),
  CONSTRAINT fk_tecnico_categoria FOREIGN KEY (fiCategoriaId) REFERENCES categoria (fiId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS parametro (
  fiId INT NOT NULL AUTO_INCREMENT,
  fcClave VARCHAR(50) NOT NULL,
  fcValor VARCHAR(250) NOT NULL,
  fcDescripcion VARCHAR(250) NULL,
  fdCreado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fiCreadoPor INT NULL,
  fdModificado DATETIME NULL,
  fiModificadoPor INT NULL,
  fbActivo TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (fiId),
  UNIQUE KEY uk_parametro_clave (fcClave),
  KEY ix_parametro_activo (fbActivo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS activo (
  fiId INT NOT NULL AUTO_INCREMENT,
  fcCodigo VARCHAR(30) NOT NULL,
  fcNombre VARCHAR(150) NOT NULL,
  fcMarca VARCHAR(80) NULL,
  fcModelo VARCHAR(80) NULL,
  fcSerie VARCHAR(80) NULL,
  fiSucursalId INT NOT NULL,
  fiUbicacionId INT NULL,
  fiCategoriaId INT NULL,
  fdFechaInstalacion DATE NULL,
  fdCreado DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  fiCreadoPor INT NULL,
  fdModificado DATETIME NULL,
  fiModificadoPor INT NULL,
  fbActivo TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (fiId),
  UNIQUE KEY uk_activo_codigo (fcCodigo),
  KEY ix_activo_sucursal (fiSucursalId),
  KEY ix_activo_ubicacion (fiUbicacionId),
  KEY ix_activo_categoria (fiCategoriaId),
  KEY ix_activo_sucursal_categoria (fiSucursalId, fiCategoriaId),
  KEY ix_activo_activo (fbActivo),
  KEY ix_activo_creadopor (fiCreadoPor),
  KEY ix_activo_modificadopor (fiModificadoPor),
  CONSTRAINT fk_activo_sucursal FOREIGN KEY (fiSucursalId) REFERENCES sucursal (fiId),
  CONSTRAINT fk_activo_ubicacion FOREIGN KEY (fiUbicacionId) REFERENCES ubicacion (fiId),
  CONSTRAINT fk_activo_categoria FOREIGN KEY (fiCategoriaId) REFERENCES categoria (fiId)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
