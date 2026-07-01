-- ============================================================
-- SUSEMON Database Init Script v2.1
-- PBL-TRPL412 | Politeknik Negeri Batam
-- ============================================================

CREATE DATABASE IF NOT EXISTS susemon_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE susemon_db;

-- ── Tabel users ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
    id          INT PRIMARY KEY AUTO_INCREMENT,
    ip_address  VARCHAR(50)  UNIQUE NOT NULL,
    access_code VARCHAR(255) NOT NULL,
    name        VARCHAR(100),
    role        ENUM('admin','pic') DEFAULT 'pic',
    is_active   BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login  TIMESTAMP NULL,
    last_ip     VARCHAR(50) NULL
);

-- ── Tabel sensor_nodes ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS sensor_nodes (
    id         INT PRIMARY KEY AUTO_INCREMENT,
    node_id    VARCHAR(20)  UNIQUE NOT NULL,
    node_name  VARCHAR(100) NOT NULL,
    location   VARCHAR(200) NOT NULL,
    is_active  BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- ── Tabel sensor_data ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sensor_data (
    id          INT PRIMARY KEY AUTO_INCREMENT,
    node_id     VARCHAR(20)  NOT NULL,
    temperature DECIMAL(5,2) NOT NULL,
    humidity    DECIMAL(5,2) NOT NULL,
    status      ENUM('AMAN','WASPADA','BERBAHAYA') NOT NULL,
    rssi        INT NULL,
    timestamp   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (node_id) REFERENCES sensor_nodes(node_id) ON DELETE CASCADE,
    INDEX idx_node_ts (node_id, timestamp),
    INDEX idx_ts      (timestamp)
);

-- ── Tabel notifications ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
    id         INT PRIMARY KEY AUTO_INCREMENT,
    node_id    VARCHAR(20),
    title      VARCHAR(200) NOT NULL,
    message    TEXT         NOT NULL,
    type       ENUM('critical','warning','success','info') NOT NULL,
    is_read    BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (node_id) REFERENCES sensor_nodes(node_id) ON DELETE SET NULL,
    INDEX idx_created (created_at)
);

-- ── Tabel ai_predictions ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS ai_predictions (
    id               INT PRIMARY KEY AUTO_INCREMENT,
    node_id          VARCHAR(20)  NOT NULL,
    prediction_type  VARCHAR(50)  NOT NULL,
    confidence       DECIMAL(5,2) NOT NULL,
    predicted_value  DECIMAL(5,2),
    prediction_time  TIMESTAMP    NOT NULL,
    created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (node_id) REFERENCES sensor_nodes(node_id) ON DELETE CASCADE,
    INDEX idx_node_time (node_id, prediction_time)
);

-- ── Seed: users ──────────────────────────────────────────────
INSERT IGNORE INTO users (ip_address, access_code, name, role) VALUES
('127.0.0.1',  'ADMIN123',    'Admin Lokal',    'admin'),
('0.0.0.0',    'SUSEMON2026', 'Admin Jaringan', 'admin'),
('10.0.2.2',   'ADMIN123',    'Admin Emulator', 'admin');

-- ── Seed: sensor nodes ───────────────────────────────────────
INSERT IGNORE INTO sensor_nodes (node_id, node_name, location) VALUES
('TA11', 'Node Sensor TA11', 'Rack Server Utama');

-- ── Verifikasi (diperbaiki) ─────────────────────────────────
SELECT '=== SUSEMON DB READY ===' AS info;
SHOW TABLES FROM susemon_db;