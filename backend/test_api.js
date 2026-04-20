const axios = require('axios');

const BASE_URL = 'http://localhost:3000/api';

async function testAPI() {
  console.log('🧪 Testing SUSEMON Backend API\n');
  console.log('='.repeat(60));

  try {
    // 1. Health Check
    console.log('\n1️⃣  Testing Health Check...');
    const health = await axios.get(`${BASE_URL}/health`);
    console.log('✅ Health:', health.data.message);

    // 2. Login
    console.log('\n2️⃣  Testing Login...');
    const login = await axios.post(`${BASE_URL}/auth/login`, {
      ip_address: '127.0.0.1',
      access_code: 'ADMIN123'
    });
    console.log('✅ Login Success!');
    console.log('   User:', login.data.data.user.name);
    console.log('   Token:', login.data.data.token.substring(0, 30) + '...');
    
    const token = login.data.data.token;

    // 3. Get Sensor Nodes
    console.log('\n3️⃣  Testing Get Sensor Nodes...');
    const nodes = await axios.get(`${BASE_URL}/sensors/nodes`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    console.log('✅ Found', nodes.data.data.length, 'sensor nodes:');
    nodes.data.data.forEach(node => {
      const statusIcon = node.current_status === 'AMAN' ? '✅' : 
                        node.current_status === 'WASPADA' ? '⚠️' : '🔴';
      console.log(`   ${statusIcon} ${node.node_id} - ${node.node_name}`);
      console.log(`      📍 ${node.location}`);
      console.log(`      🌡️  ${node.current_temp}°C | 💧 ${node.current_humidity}% | ${node.current_status}`);
    });

    // 4. Get Latest Data
    console.log('\n4️⃣  Testing Get Latest Data...');
    const latest = await axios.get(`${BASE_URL}/sensors/latest`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    console.log('✅ Latest data retrieved:', latest.data.data.length, 'records');

    // 5. Get Statistics
    console.log('\n5️⃣  Testing Get Statistics...');
    const stats = await axios.get(`${BASE_URL}/sensors/statistics?period=24h`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    console.log('✅ Statistics (24h):');
    console.log('   Average Temp:', stats.data.data.avg_temperature, '°C');
    console.log('   Max Temp:', stats.data.data.max_temperature, '°C');
    console.log('   Min Temp:', stats.data.data.min_temperature, '°C');
    console.log('   Status: Aman:', stats.data.data.status_aman, 
                '| Waspada:', stats.data.data.status_waspada,
                '| Berbahaya:', stats.data.data.status_berbahaya);

    // 6. Get AI Prediction
    console.log('\n6️⃣  Testing AI Prediction...');
    const prediction = await axios.get(`${BASE_URL}/ai/prediction/D4`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    console.log('✅ AI Prediction for Node D4:');
    console.log('   Current Temp:', prediction.data.data.current_temp, '°C');
    console.log('   Predicted Temp:', prediction.data.data.predicted_temp, '°C');
    console.log('   Risk Level:', prediction.data.data.risk_level);
    console.log('   Confidence:', prediction.data.data.confidence, '%');
    console.log('   Trend:', prediction.data.data.trend);

    // 7. Get AI Analysis
    console.log('\n7️⃣  Testing AI Analysis...');
    const analysis = await axios.get(`${BASE_URL}/ai/analysis`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    console.log('✅ AI Analysis Summary:');
    console.log('   Total Nodes:', analysis.data.data.summary.total_nodes);
    console.log('   High Risk:', analysis.data.data.summary.high_risk_nodes);
    console.log('   Medium Risk:', analysis.data.data.summary.medium_risk_nodes);
    console.log('   Low Risk:', analysis.data.data.summary.low_risk_nodes);
    console.log('   Avg Confidence:', analysis.data.data.summary.avg_confidence, '%');

    // 8. Get Notifications
    console.log('\n8️⃣  Testing Get Notifications...');
    const notifications = await axios.get(`${BASE_URL}/notifications?limit=5`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    console.log('✅ Found', notifications.data.data.length, 'notifications:');
    notifications.data.data.forEach((notif, index) => {
      const typeIcon = notif.type === 'critical' ? '🔴' :
                      notif.type === 'warning' ? '⚠️' :
                      notif.type === 'success' ? '✅' : 'ℹ️';
      console.log(`   ${typeIcon} ${notif.title}`);
    });

    // 9. Get Sensor Data History
    console.log('\n9️⃣  Testing Get Sensor Data History...');
    const history = await axios.get(`${BASE_URL}/sensors/data/A1?period=24h&limit=5`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    console.log('✅ History for Node A1 (last 5 records):');
    history.data.data.forEach((record, index) => {
      console.log(`   ${index + 1}. ${record.temperature}°C | ${record.humidity}% | ${record.status}`);
    });

    console.log('\n' + '='.repeat(60));
    console.log('✅ ALL TESTS PASSED! Database is working perfectly!');
    console.log('='.repeat(60) + '\n');

  } catch (error) {
    console.error('\n❌ Error:', error.response?.data || error.message);
  }
}

testAPI();
