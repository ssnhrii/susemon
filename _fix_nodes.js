var fs = require('fs');

// ── 1. Tambah navigasi ke SensorDetailPage dari nodes_page ──
var np = 'mobile/lib/features/dashboard/pages/nodes_page.dart';
var nc = fs.readFileSync(np, 'utf8');

// Tambah import sensor_detail_page
if (!nc.includes("import 'sensor_detail_page.dart'")) {
  nc = nc.replace(
    "import '../../../services/api_service.dart';",
    "import '../../../services/api_service.dart';\nimport '../../../providers/app_provider.dart';\nimport 'sensor_detail_page.dart';"
  );
}

// Bungkus _NodeCard dengan GestureDetector yang navigasi ke SensorDetailPage
nc = nc.replace(
  "itemBuilder: (_, i) => _NodeCard(\n              node: _nodes[i],\n              onDelete: () => _deleteNode(_nodes[i]),\n            ),",
  "itemBuilder: (_, i) => GestureDetector(\n              onTap: () {\n                Navigator.push(context, MaterialPageRoute(\n                  builder: (_) => SensorDetailPage(node: _nodes[i])));\n              },\n              child: _NodeCard(\n                node: _nodes[i],\n                onDelete: () => _deleteNode(_nodes[i]),\n              ),\n            ),"
);

fs.writeFileSync(np, nc, 'utf8');
console.log('nodes_page.dart updated');

// ── 2. Ganti tab index 3 di main_layout dari Laporan ke Sensors ──
var mp = 'mobile/lib/features/dashboard/main_layout.dart';
var mc = fs.readFileSync(mp, 'utf8');

// Tambah import nodes_page
if (!mc.includes("import 'pages/nodes_page.dart'")) {
  mc = mc.replace(
    "import 'pages/settings_page_new.dart';",
    "import 'pages/settings_page_new.dart';\nimport 'pages/nodes_page.dart';"
  );
}

// Ganti HistoryPageNew dengan NodesPage di index 3
mc = mc.replace(
  "    DashboardPage(),\n    AnalisisPage(),\n    NotifikasiPageNew(),\n    HistoryPageNew(),\n    SettingsPageNew(),",
  "    DashboardPage(),\n    AnalisisPage(),\n    NotifikasiPageNew(),\n    NodesPage(),\n    SettingsPageNew(),"
);

// Ganti label dan ikon tab Laporan (index 3) menjadi Sensors
mc = mc.replace(
  "              _NavItem(\n                index: 3,\n                current: current,\n                icon: Icons.bar_chart_rounded,\n                label: 'Laporan',\n                onTap: onTap,\n                ctrl: controllers[3],\n              ),",
  "              _NavItem(\n                index: 3,\n                current: current,\n                icon: Icons.sensors_rounded,\n                label: 'Sensors',\n                onTap: onTap,\n                ctrl: controllers[3],\n              ),"
);

fs.writeFileSync(mp, mc, 'utf8');
console.log('main_layout.dart updated');
console.log('Done!');
