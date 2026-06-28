// Script untuk tambah user baru ke database via API
var https = require('http');

var token = '';

function req(method, path, body, cb) {
  var data = body ? JSON.stringify(body) : null;
  var opts = {
    hostname: 'localhost',
    port: 3000,
    path: '/api' + path,
    method: method,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + token
    }
  };
  var r = https.request(opts, function(res) {
    var d = '';
    res.on('data', function(c) { d += c; });
    res.on('end', function() {
      try { cb(null, JSON.parse(d)); }
      catch(e) { cb(d); }
    });
  });
  r.on('error', cb);
  if (data) r.write(data);
  r.end();
}

// Step 1: Login
req('POST', '/auth/login', {ip_address: '127.0.0.1', access_code: 'ADMIN123'}, function(err, res) {
  if (err) { console.error('Login error:', err); return; }
  token = res.data.token;
  console.log('Login OK, token didapat');

  // Step 2: Tambah user untuk Android emulator (10.0.2.2)
  req('POST', '/users', {ip_address: '10.0.2.2', access_code: 'ADMIN123', name: 'Admin Emulator Android', role: 'admin'}, function(err2, res2) {
    console.log('User 10.0.2.2:', err2 ? 'error:'+JSON.stringify(err2) : res2.message || JSON.stringify(res2));
  });

  // Step 3: Tambah user untuk IP WiFi lokal (172.20.10.4)
  req('POST', '/users', {ip_address: '172.20.10.4', access_code: 'ADMIN123', name: 'Admin WiFi', role: 'admin'}, function(err3, res3) {
    console.log('User 172.20.10.4:', err3 ? 'error:'+JSON.stringify(err3) : res3.message || JSON.stringify(res3));
  });

  // Step 4: Tambah user untuk semua IP (wildcard untuk testing mudah)
  req('POST', '/users', {ip_address: '192.168.1.100', access_code: 'ADMIN123', name: 'Admin Testing', role: 'admin'}, function(err4, res4) {
    console.log('User 192.168.1.100:', err4 ? 'skip' : res4.message || JSON.stringify(res4));
  });

  // Cek users yang ada
  setTimeout(function() {
    req('GET', '/users', null, function(err5, res5) {
      if (err5) { console.log('Get users error'); return; }
      console.log('\n=== DAFTAR USER ===');
      var users = res5.data || [];
      users.forEach(function(u) {
        console.log(' - IP: ' + u.ip_address + ' | Role: ' + u.role + ' | Nama: ' + u.name);
      });
    });
  }, 500);
});
