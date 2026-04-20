const mysql = require('mysql2/promise');
require('dotenv').config();

async function initDatabase() {
  let connection;
  
  try {
    // Connect without database
    connection = await mysql.createConnection({
      host: process.env.DB_HOST || 'localhost',
      user: process.env.DB_USER || 'root',
      password: process.env.DB_PASSWORD || '',
      port: process.env.DB_PORT || 3306
    });

    console.log('📦 Creating database...');
    
    // Create database
    await connection.query(`CREATE DATABASE IF NOT EXISTS ${process.env.DB_NAME || 'susemon_db'}`);
    await connection.query(`USE ${process.env.DB_NAME || 'susemon_db'}`);

    console.log('📋 Creating tables...');

    // Table: users
    await connection.query(`
      CREATE TABLE IF NOT EXISTS users (
        id INT PRIMARY KEY AUTO_INCREMENT,
        ip_address VARCHAR(50) UNIQUE NOT NULL,
        access_code VARCHAR(255) NOT NULL,
        name VARCHAR(100),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        last_login TIMESTAMP NULL
      )
    `);

    // Table: sensor_nodes
    await connection.query(`
      CREATE TABLE IF NOT EXISTS sensor_nodes (
        id INT PRIMARY KEY AUTO_INCREMENT,
        node_id VARCHAR(10) UNIQUE NOT NULL,
        node_name VARCHAR(100) NOT NULL,
        location VARCHAR(200) NOT NULL,
        is_active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      )
    `);

    // Table: sensor_data
    await connection.query(`
      CREATE TABLE IF NOT EXISTS sensor_data (
        id INT PRIMARY KEY AUTO_INCREMENT,
        node_id VARCHAR(10) NOT NULL,
        temperature DECIMAL(5,2) NOT NULL,
        humidity DECIMAL(5,2) NOT NULL,
        status ENUM('AMAN', 'WASPADA', 'BERBAHAYA') NOT NULL,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (node_id) REFERENCES sensor_nodes(node_id) ON DELETE CASCADE,
        INDEX idx_node_timestamp (node_id, timestamp),
        INDEX idx_timestamp (timestamp)
      )
    `);

    // Table: notifications
    await connection.query(`
      CREATE TABLE IF NOT EXISTS notifications (
        id INT PRIMARY KEY AUTO_INCREMENT,
        node_id VARCHAR(10),
        title VARCHAR(200) NOT NULL,
        message TEXT NOT NULL,
        type ENUM('critical', 'warning', 'success', 'info') NOT NULL,
        is_read BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (node_id) REFERENCES sensor_nodes(node_id) ON DELETE SET NULL,
        INDEX idx_created (created_at)
      )
    `);

    // Table: ai_predictions
    await connection.query(`
      CREATE TABLE IF NOT EXISTS ai_predictions (
        id INT PRIMARY KEY AUTO_INCREMENT,
        node_id VARCHAR(10) NOT NULL,
        prediction_type VARCHAR(50) NOT NULL,
        confidence DECIMAL(5,2) NOT NULL,
        predicted_value DECIMAL(5,2),
        prediction_time TIMESTAMP NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (node_id) REFERENCES sensor_nodes(node_id) ON DELETE CASCADE,
        INDEX idx_node_time (node_id, prediction_time)
      )
    `);

    // Table: system_logs
    await connection.query(`
      CREATE TABLE IF NOT EXISTS system_logs (
        id INT PRIMARY KEY AUTO_INCREMENT,
        log_type VARCHAR(50) NOT NULL,
        message TEXT NOT NULL,
        metadata JSON,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_type_created (log_type, created_at)
      )
    `);

    console.log('🌱 Seeding initial data...');

    // Insert default users
    await connection.query(`
      INSERT IGNORE INTO users (ip_address, access_code, name) VALUES
      ('127.0.0.1', 'ADMIN123', 'Admin Local'),
      ('192.168.1.100', 'SUSEMON2026', 'Admin Network')
    `);

    // Insert sensor nodes
    await connection.query(`
      INSERT IGNORE INTO sensor_nodes (node_id, node_name, location) VALUES
      ('A1', 'Node Sensor A1', 'Rack Server Utama'),
      ('B2', 'Node Sensor B2', 'Rack Server Backup'),
      ('C3', 'Node Sensor C3', 'Rack Network'),
      ('D4', 'Node Sensor D4', 'Rack Storage')
    `);

    // Insert sample sensor data
    const nodes = ['A1', 'B2', 'C3', 'D4'];
    const baseTemps = { A1: 28.5, B2: 32.1, C3: 26.8, D4: 41.2 };
    
    for (const node of nodes) {
      for (let i = 0; i < 20; i++) {
        const temp = baseTemps[node] + (Math.random() * 4 - 2);
        const humidity = 60 + Math.random() * 20;
        const status = temp > 40 ? 'BERBAHAYA' : temp > 35 ? 'WASPADA' : 'AMAN';
        const timestamp = new Date(Date.now() - i * 30 * 60 * 1000); // Every 30 minutes
        
        await connection.query(`
          INSERT INTO sensor_data (node_id, temperature, humidity, status, timestamp)
          VALUES (?, ?, ?, ?, ?)
        `, [node, temp.toFixed(2), humidity.toFixed(2), status, timestamp]);
      }
    }

    // Insert sample notifications
    await connection.query(`
      INSERT INTO notifications (node_id, title, message, type) VALUES
      ('D4', 'Suhu Kritis - Node D4', 'Suhu mencapai 41.2°C pada Rack Storage. Tindakan segera diperlukan!', 'critical'),
      ('B2', 'Anomali Terdeteksi', 'Pola anomali suhu tidak normal pada Node B2. AI confidence: 87%', 'warning'),
      ('D4', 'Prediksi Overheating', 'AI memprediksi overheating dalam 30 menit pada Node D4', 'warning'),
      (NULL, 'Koneksi LoRa Berhasil', 'Semua node sensor terhubung dengan gateway. Signal strength: Excellent', 'success')
    `);

    console.log('✅ Database initialized successfully!');
    console.log('📊 Tables created:');
    console.log('   - users');
    console.log('   - sensor_nodes');
    console.log('   - sensor_data');
    console.log('   - notifications');
    console.log('   - ai_predictions');
    console.log('   - system_logs');
    console.log('');
    console.log('👤 Default users:');
    console.log('   IP: 127.0.0.1 | Code: ADMIN123');
    console.log('   IP: 192.168.1.100 | Code: SUSEMON2026');

  } catch (error) {
    console.error('❌ Error initializing database:', error.message);
    throw error;
  } finally {
    if (connection) {
      await connection.end();
    }
  }
}

// Run if called directly
if (require.main === module) {
  initDatabase()
    .then(() => process.exit(0))
    .catch(() => process.exit(1));
}

module.exports = initDatabase;
