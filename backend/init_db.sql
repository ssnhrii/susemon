-- ============================================================
-- SUSEMON Database Init Script
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
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login  TIMESTAMP NULL
);

-- ── Tabel sensor_nodes ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS sensor_nodes (
    id         INT PRIMARY KEY AUTO_INCREMENT,
    node_id    VARCHAR(10)  UNIQUE NOT NULL,
    node_name  VARCHAR(100) NOT NULL,
    location   VARCHAR(200) NOT NULL,
    is_active  BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- ── Tabel sensor_data ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sensor_data (
    id          INT PRIMARY KEY AUTO_INCREMENT,
    node_id     VARCHAR(10)  NOT NULL,
    temperature DECIMAL(5,2) NOT NULL,
    humidity    DECIMAL(5,2) NOT NULL,
    status      ENUM('AMAN','WASPADA','BERBAHAYA') NOT NULL,
    timestamp   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (node_id) REFERENCES sensor_nodes(node_id) ON DELETE CASCADE,
    INDEX idx_node_ts (node_id, timestamp),
    INDEX idx_ts      (timestamp)
);

-- ── Tabel notifications ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
    id         INT PRIMARY KEY AUTO_INCREMENT,
    node_id    VARCHAR(10),
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
    node_id          VARCHAR(10)  NOT NULL,
    prediction_type  VARCHAR(50)  NOT NULL,
    confidence       DECIMAL(5,2) NOT NULL,
    predicted_value  DECIMAL(5,2),
    prediction_time  TIMESTAMP    NOT NULL,
    created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (node_id) REFERENCES sensor_nodes(node_id) ON DELETE CASCADE,
    INDEX idx_node_time (node_id, prediction_time)
);

-- ── Seed: users ──────────────────────────────────────────────
INSERT IGNORE INTO users (ip_address, access_code, name) VALUES
('127.0.0.1',  'ADMIN123',    'Admin Local'),
('0.0.0.0',    'SUSEMON2026', 'Admin Network');

-- ── Seed: sensor nodes ───────────────────────────────────────
INSERT IGNORE INTO sensor_nodes (node_id, node_name, location) VALUES
('A1', 'Node Sensor A1', 'Rack Server Utama'),
('B2', 'Node Sensor B2', 'Rack Server Backup'),
('C3', 'Node Sensor C3', 'Rack Network'),
('D4', 'Node Sensor D4', 'Rack Storage');

-- ── Seed: sample sensor data (untuk testing AI) ──────────────
INSERT IGNORE INTO sensor_data (node_id, temperature, humidity, status) VALUES
('A1', 27.5, 61.0, 'AMAN'),('A1', 28.0, 62.0, 'AMAN'),('A1', 27.8, 60.5, 'AMAN'),
('A1', 28.3, 63.0, 'AMAN'),('A1', 28.1, 61.5, 'AMAN'),('A1', 27.9, 62.5, 'AMAN'),
('A1', 28.5, 63.5, 'AMAN'),('A1', 28.2, 62.0, 'AMAN'),('A1', 27.7, 61.0, 'AMAN'),
('A1', 28.4, 62.8, 'AMAN'),

('B2', 31.0, 66.0, 'WASPADA'),('B2', 31.5, 67.0, 'WASPADA'),('B2', 32.0, 67.5, 'WASPADA'),
('B2', 31.8, 66.5, 'WASPADA'),('B2', 32.1, 68.0, 'WASPADA'),('B2', 31.3, 65.5, 'WASPADA'),
('B2', 32.3, 67.0, 'WASPADA'),('B2', 31.9, 66.8, 'WASPADA'),('B2', 32.5, 68.5, 'WASPADA'),
('B2', 31.7, 66.2, 'WASPADA'),

('C3', 26.0, 57.0, 'AMAN'),('C3', 26.5, 58.0, 'AMAN'),('C3', 26.2, 57.5, 'AMAN'),
('C3', 26.8, 58.5, 'AMAN'),('C3', 26.3, 57.8, 'AMAN'),('C3', 26.7, 58.2, 'AMAN'),
('C3', 26.1, 57.3, 'AMAN'),('C3', 26.9, 58.8, 'AMAN'),('C3', 26.4, 57.6, 'AMAN'),
('C3', 26.6, 58.1, 'AMAN'),

('D4', 39.0, 72.0, 'WASPADA'),('D4', 39.5, 73.0, 'BERBAHAYA'),('D4', 40.0, 74.0, 'BERBAHAYA'),
('D4', 40.5, 74.5, 'BERBAHAYA'),('D4', 41.0, 75.0, 'BERBAHAYA'),('D4', 40.8, 74.8, 'BERBAHAYA'),
('D4', 41.2, 75.5, 'BERBAHAYA'),('D4', 40.3, 74.2, 'BERBAHAYA'),('D4', 41.5, 76.0, 'BERBAHAYA'),
('D4', 40.7, 74.6, 'BERBAHAYA');

-- ── Seed: sample notifications ───────────────────────────────
INSERT IGNORE INTO notifications (node_id, title, message, type) VALUES
('D4', 'Suhu Kritis - Node D4',
 'Suhu mencapai 41.2°C pada Rack Storage. Tindakan segera diperlukan!', 'critical'),
('B2', 'Anomali Terdeteksi - Node B2',
 'Pola anomali suhu tidak normal. AI confidence: 87%', 'warning'),
('D4', 'Prediksi Overheating',
 'AI memprediksi overheating dalam 30 menit pada Node D4', 'warning'),
(NULL, 'Sistem Aktif',
 'Semua node sensor terhubung. SUSEMON siap monitoring.', 'success');

-- ── Verifikasi ───────────────────────────────────────────────
SELECT '=== SUSEMON DB READY ===' AS info;
SELECT table_name, table_rows
FROM information_schema.tables
WHERE table_schema = 'susemon_db'
ORDER BY table_name;
