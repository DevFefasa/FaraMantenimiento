-- 20_ticket_secuencia.sql
SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS ticketsecuencia (
  fiAnio INT NOT NULL,
  fiUltimo INT NOT NULL DEFAULT 0,
  PRIMARY KEY (fiAnio)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
