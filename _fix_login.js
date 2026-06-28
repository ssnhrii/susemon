var fs = require('fs');
var p = 'mobile/lib/features/auth/login_screen.dart';
var c = fs.readFileSync(p, 'utf8');

// Tambah import dart:io dengan platform check
if (!c.includes("import 'package:flutter/foundation.dart'")) {
  c = c.replace(
    "import 'dart:io';",
    "import 'dart:io';\nimport 'package:flutter/foundation.dart' show kIsWeb;"
  );
}

// Ganti hint baris lokal dan jaringan — tambahkan hint web dan emulator
c = c.replace(
  "          _hintRow('Lokal', '127.0.0.1  ·  ADMIN123'),\n          _hintRow('Jaringan', _detectedIp.isNotEmpty\n              ? '$_detectedIp  ·  SUSEMON2026'\n              : '10.130.1.206  ·  SUSEMON2026'),",
  `          _hintRow('Lokal', '127.0.0.1  ·  ADMIN123'),
          _hintRow('Emulator', '10.0.2.2  ·  ADMIN123'),
          _hintRow('Jaringan', _detectedIp.isNotEmpty
              ? '\$_detectedIp  ·  SUSEMON2026'
              : '172.20.10.4  ·  ADMIN123'),`
);

// Auto-fill IP berdasarkan platform saat initState
c = c.replace(
  "  @override\n  void initState() {\n    super.initState();\n    _storage.read(key: 'server_ip').then((ip) {\n      if (ip != null && ip.isNotEmpty && mounted) _ipCtrl.text = ip;\n    });\n    _startUdpDiscovery();\n  }",
  `  @override
  void initState() {
    super.initState();
    _storage.read(key: 'server_ip').then((ip) {
      if (ip != null && ip.isNotEmpty && mounted) {
        _ipCtrl.text = ip;
      } else if (mounted) {
        // Auto-fill IP default berdasarkan platform
        if (kIsWeb) {
          _ipCtrl.text = '172.20.10.4'; // browser — pakai IP WiFi
        } else {
          try {
            if (Platform.isAndroid) {
              _ipCtrl.text = '10.0.2.2'; // Android emulator
            } else {
              _ipCtrl.text = '127.0.0.1'; // iOS simulator / desktop
            }
          } catch (_) {
            _ipCtrl.text = '127.0.0.1';
          }
        }
      }
    });
    _startUdpDiscovery();
  }`
);

fs.writeFileSync(p, c, 'utf8');
console.log('Login screen updated!');
