import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/app_provider.dart';
import '../../../shared/widgets/interactive.dart';
import '../../auth/login_screen.dart';
import 'users_page.dart';
import 'nodes_page.dart';

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
        title: const Text('Keluar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text('Yakin ingin keluar dari sistem?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      context.read<SensorProvider>().stop();
      context.read<NotificationProvider>().stop();
      context.read<AiProvider>().stop();
      context.read<AuthProvider>().logout();
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
                    _buildConnectionCard(wsConnected, sensor.nodeCount),
                    const SizedBox(height: 14),
                    _buildSection('Threshold Suhu', Icons.thermostat, [_buildThreshold()]),
                    const SizedBox(height: 14),
                    _buildSection('Notifikasi', Icons.notifications_rounded, [
                      _buildSwitch('Notifikasi Push', 'Peringatan di perangkat', _pushNotif,
                          (v) => setState(() => _pushNotif = v)),
                      const Divider(color: AppColors.cardBorder, height: 24),
                      _buildSwitch('Suara Peringatan', 'Bunyi saat kondisi kritis', _soundAlert,
                          (v) => setState(() => _soundAlert = v)),
                    ]),
                    const SizedBox(height: 14),
                    _buildSection('Sistem', Icons.tune, [_buildIntervalRow()]),
                    const SizedBox(height: 14),
                    if (auth.isStaff) ...[
                      _buildSection('Administrasi', Icons.manage_accounts, [
                        _buildNavRow(
                          icon: Icons.sensors_rounded,
                          title: 'Manajemen Perangkat',
                          subtitle: 'Kelola node sensor IoT',
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const NodesPage())),
                        ),
                        if (auth.isAdmin) ...[
                          const Divider(color: AppColors.cardBorder, height: 24),
                          _buildNavRow(
                            icon: Icons.people_rounded,
                            title: 'Manajemen User',
                            subtitle: 'Kelola akses pengguna sistem',
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const UsersPage())),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 14),
                    ],
                    _buildSection('Tentang', Icons.info_outline, [
                      _infoRow('Versi', '2.2.0'),
                      _infoRow('ID Proyek', 'PBL-TRPL412'),
                      _infoRow('Institusi', 'Politeknik Negeri Batam'),
                      _infoRow('Teknologi', 'Flutter + LoRa + AI'),
                      _infoRow('Backend', 'Python FastAPI + WebSocket'),
                    ]),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: TapScale(
                        scale: 0.97,
                        onTap: _logout,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.danger),
                          ),
                          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.logout, size: 18, color: AppColors.danger),
                            SizedBox(width: 8),
                            Text('Keluar dari Sistem',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.danger)),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
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
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
    ),
    child: Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.settings_rounded, color: AppColors.primary, size: 20),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Pengaturan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
        Row(children: [
          Text(auth.userName ?? 'Admin', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: auth.isAdmin ? AppColors.warning.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              auth.role.toUpperCase(),
              style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w700,
                color: auth.isAdmin ? AppColors.warning : AppColors.primary,
              ),
            ),
          ),
        ]),
      ]),
    ]),
  );

  Widget _buildConnectionCard(bool wsConnected, int nodeCount) {
    final color = wsConnected ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(wsConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            wsConnected ? 'WebSocket Terhubung' : 'HTTP Polling Aktif',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            wsConnected ? '$nodeCount node terpantau real-time' : 'Fallback polling setiap 5 detik',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ])),
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            color: color, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color, blurRadius: 8, spreadRadius: 2)],
          ),
        ),
      ]),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
      ]),
      const SizedBox(height: 16),
      ...children,
    ]),
  );

  Widget _buildNavRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) => TapScale(
    onTap: () {
      HapticFeedback.selectionClick();
      onTap();
    },
    child: Row(children: [
      Icon(icon, size: 18, color: AppColors.primary),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
        Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ])),
      const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
    ]),
  );

  Widget _buildThreshold() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Batas Suhu Kritis', style: TextStyle(fontSize: 13, color: Colors.white)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('${_threshold.toStringAsFixed(0)}°C',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.danger)),
        ),
      ]),
      const SizedBox(height: 8),
      SliderTheme(
        data: SliderThemeData(
          activeTrackColor: AppColors.primary,
          inactiveTrackColor: AppColors.bgCardAlt,
          thumbColor: AppColors.primary,
          overlayColor: AppColors.primary.withValues(alpha: 0.15),
          trackHeight: 3,
        ),
        child: Slider(
          value: _threshold, min: 30, max: 50, divisions: 20,
          onChanged: (v) => setState(() => _threshold = v),
        ),
      ),
      Text(
        'Threshold aktif dikonfigurasi di backend (.env)',
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
    ],
  );

  Widget _buildSwitch(String title, String sub, bool val, Function(bool) onChange) => Row(
    children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ])),
      Switch(value: val, onChanged: onChange, activeThumbColor: AppColors.primary),
    ],
  );

  Widget _buildIntervalRow() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Interval Refresh', style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500)),
        SizedBox(height: 2),
        Text('Fallback polling interval', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.bgCardAlt,
          borderRadius: BorderRadius.circular(10),
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
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
    ]),
  );
}
