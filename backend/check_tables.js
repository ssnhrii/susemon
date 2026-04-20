const mysql = require('mysql2/promise');
require('dotenv').config();

async function checkTables() {
  let connection;
  
  try {
    connection = await mysql.createConnection({
      host: process.env.DB_HOST || 'localhost',
      user: process.env.DB_USER || 'root',
      password: process.env.DB_PASSWORD || '',
      database: process.env.DB_NAME || 'susemon_db',
      port: process.env.DB_PORT || 3306
    });

    console.log('✅ Connected to database: susemon_db\n');

    // Show tables
    const [tables] = await connection.query('SHOW TABLES');
    console.log('📊 Tables in database:');
    console.log('========================');
    tables.forEach((table, index) => {
      const tableName = Object.values(table)[0];
      console.log(`${index + 1}. ${tableName}`);
    });
    console.log('========================\n');

    // Count records in each table
    console.log('📈 Record counts:');
    console.log('========================');
    for (const table of tables) {
      const tableName = Object.values(table)[0];
      const [count] = await connection.query(`SELECT COUNT(*) as count FROM ${tableName}`);
      console.log(`${tableName}: ${count[0].count} records`);
    }
    console.log('========================\n');

    // Show sensor nodes
    console.log('🔌 Sensor Nodes:');
    console.log('========================');
    const [nodes] = await connection.query('SELECT * FROM sensor_nodes');
    nodes.forEach(node => {
      console.log(`${node.node_id} - ${node.node_name} (${node.location})`);
    });
    console.log('========================\n');

    // Show latest sensor data
    console.log('🌡️  Latest Sensor Data:');
    console.log('========================');
    const [latestData] = await connection.query(`
      SELECT sd.*, sn.node_name 
      FROM sensor_data sd
      INNER JOIN sensor_nodes sn ON sd.node_id = sn.node_id
      WHERE sd.timestamp = (
        SELECT MAX(timestamp) FROM sensor_data WHERE node_id = sd.node_id
      )
      ORDER BY sd.node_id
    `);
    latestData.forEach(data => {
      console.log(`${data.node_id} (${data.node_name}): ${data.temperature}°C, ${data.humidity}% - ${data.status}`);
    });
    console.log('========================\n');

    // Show users
    console.log('👤 Users:');
    console.log('========================');
    const [users] = await connection.query('SELECT ip_address, name FROM users');
    users.forEach(user => {
      console.log(`${user.ip_address} - ${user.name}`);
    });
    console.log('========================');

  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    if (connection) {
      await connection.end();
    }
  }
}

checkTables();
