import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/app_provider.dart';
import '../../auth/login_screen.dart';

class SettingsPageNew extends StatefulWidget {
  const SettingsPageNew({super.key});
  @override
  State<SettingsPageNew> createState() => _SettingsPageNewState();
}

class _SettingsPageNewState extends State<SettingsPageNew> {
  double _threshold = 40.0;
  bool _pushNotif = true;
  bool _soundAlert = false;
  String _interval = '30';

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar', style: TextStyle(color: Colors.white)),
        content: Text('Yakin ingin keluar dari sistem?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('Batal', style: TextStyle(color: AppColors.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Keluar', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      context.read<AuthProvider>().logout();
      context.read<SensorProvider>().stop();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth        = context.watch<AuthProvider>();
    final sensor      = context.watch<SensorProvider>();
    final wsConnected = sensor.wsConnected;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(auth),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Connection status
                    _buildConnectionCard(wsConnected),
                    const SizedBox(height: 14),
                    _buildSection('Threshold Suhu', Icons.thermostat, [_buildThreshold()]),
                    const SizedBox(height: 14),
                    _buildSection('Notifikasi', Icons.notifications_rounded, [
                      _buildSwitch('Notifikasi Push', 'Peringatan di perangkat', _pushNotif,
                          (v) => setState(() => _pushNotif = v)),
                      const SizedBox(height: 12),
                      _buildSwitch('Suara Peringatan', 'Bunyi saat kondisi kritis', _soundAlert,
                          (v) => setState(() => _soundAlert = v)),
                    ]),
                    const SizedBox(height: 14),
                    _buildSection('Sistem', Icons.tune, [_buildIntervalRow()]),
                    const SizedBox(height: 14),
                    _buildSection('Tentang', Icons.info_outline, [
                      _infoRow('Versi', '2.0.0'),
                      _infoRow('ID Proyek', 'PBL-TRPL412'),
                      _infoRow('Institusi', 'Politeknik Negeri Batam'),
                      _infoRow('Teknologi', 'Flutter + LoRa + AI'),
                      _infoRow('Backend', 'Python FastAPI + WebSocket'),
                    ]),
                    const SizedBox(height: 20),
                    // Logout button
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Keluar dari Sistem',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AuthProvider auth) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    color: AppColors.bgCard,
    child: Row(
      children: [
        const Icon(Icons.settings_rounded, color: AppColors.primary, size: 22),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Pengaturan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
          Text(auth.userName ?? 'Admin', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ]),
      ],
    ),
  );

  Widget _buildConnectionCard(bool wsConnected) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.bgCard, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: wsConnected ? AppColors.success.withOpacity(0.3) : AppColors.warning.withOpacity(0.3)),
    ),
    child: Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: (wsConnected ? AppColors.success : AppColors.warning).withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(wsConnected ? Icons.wifi : Icons.wifi_off,
            color: wsConnected ? AppColors.success : AppColors.warning, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(wsConnected ? 'WebSocket Terhubung' : 'HTTP Polling Aktif',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
        Text(wsConnected ? 'Real-time data streaming aktif' : 'Fallback polling setiap 5 detik',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ])),
      Container(
        width: 10, height: 10,
        decoration: BoxDecoration(
          color: wsConnected ? AppColors.success : AppColors.warning,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(
            color: wsConnected ? AppColors.success : AppColors.warning,
            blurRadius: 6, spreadRadius: 1,
          )],
        ),
      ),
    ]),
  );

  Widget _buildSection(String title, IconData icon, List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.bgCard, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
      ]),
      const SizedBox(height: 16),
      ...children,
    ]),
  );

  Widget _buildThreshold() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Batas Suhu Kritis', style: TextStyle(fontSize: 13, color: Colors.white)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: Text('${_threshold.toStringAsFixed(0)}°C',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.danger)),
        ),
      ]),
      SliderTheme(
        data: SliderThemeData(
          activeTrackColor: AppColors.primary,
          inactiveTrackColor: AppColors.bgCardAlt,
          thumbColor: AppColors.primary,
          overlayColor: AppColors.primary.withOpacity(0.2),
        ),
        child: Slider(value: _threshold, min: 30, max: 50, divisions: 20,
            onChanged: (v) => setState(() => _threshold = v)),
      ),
      Text('Peringatan dikirim jika suhu ≥ ${_threshold.toStringAsFixed(0)}°C',
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
    ],
  );

  Widget _buildSwitch(String title, String sub, bool val, Function(bool) onChange) => Row(
    children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 13, color: Colors.white)),
        Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ])),
      Switch(value: val, onChanged: onChange, activeColor: AppColors.primary),
    ],
  );

  Widget _buildIntervalRow() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Interval Refresh', style: TextStyle(fontSize: 13, color: Colors.white)),
        Text('Fallback polling interval', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ]),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.bgCardAlt, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: DropdownButton<String>(
          value: _interval,
          dropdownColor: AppColors.bgCard,
          underline: const SizedBox(),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          items: const [
            DropdownMenuItem(value: '5',  child: Text('5 detik')),
            DropdownMenuItem(value: '10', child: Text('10 detik')),
            DropdownMenuItem(value: '30', child: Text('30 detik')),
          ],
          onChanged: (v) => setState(() => _interval = v!),
        ),
      ),
    ],
  );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
    ]),
  );
}
