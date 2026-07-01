import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/app_provider.dart';
import '../../../shared/widgets/interactive.dart';
import '../../../shared/widgets/mesh_background.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _threshold = context.read<SensorProvider>().tempThreshold;
        });
      }
    });
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Keluar',
          style: TextStyle(
            color: AppColors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Yakin ingin keluar dari sistem?',
          style: TextStyle(color: AppColors.textDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: TextStyle(color: AppColors.textDim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Keluar',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
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
    final auth = context.watch<AuthProvider>();
    final sensor = context.watch<SensorProvider>();
    final wsConnected = sensor.wsConnected;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: MeshBackground(
        child: SafeArea(
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
                      _buildSection(
                        'Threshold Suhu',
                        Icons.thermostat_rounded,
                        [_buildThreshold()],
                      ),
                      const SizedBox(height: 14),
                      _buildSection('Notifikasi', Icons.notifications_rounded, [
                        _buildSwitch(
                          'Notifikasi Push',
                          'Peringatan di perangkat',
                          _pushNotif,
                          (v) => setState(() => _pushNotif = v),
                        ),
                        Divider(
                          color: AppColors.outlineVariant.withValues(
                            alpha: 0.4,
                          ),
                          height: 24,
                        ),
                        _buildSwitch(
                          'Suara Peringatan',
                          'Bunyi saat kondisi kritis',
                          _soundAlert,
                          (v) => setState(() => _soundAlert = v),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      _buildSection('Sistem', Icons.tune_rounded, [
                        _buildIntervalRow(),
                      ]),
                      const SizedBox(height: 14),
                      if (auth.isStaff) ...[
                        _buildSection(
                          'Administrasi',
                          Icons.manage_accounts_rounded,
                          [
                            _buildNavRow(
                              icon: Icons.sensors_rounded,
                              title: 'Manajemen Perangkat',
                              subtitle: 'Kelola node sensor IoT',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const NodesPage(),
                                ),
                              ),
                            ),
                            if (auth.isAdmin) ...[
                              Divider(
                                color: AppColors.outlineVariant.withValues(
                                  alpha: 0.4,
                                ),
                                height: 24,
                              ),
                              _buildNavRow(
                                icon: Icons.people_rounded,
                                title: 'Manajemen User',
                                subtitle: 'Kelola akses pengguna sistem',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const UsersPage(),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                      _buildSection(
                        'Tentang Aplikasi',
                        Icons.info_outline_rounded,
                        [
                          _infoRow('Versi', '2.2.0'),
                          _infoRow('ID Proyek', 'PBL-TRPL412'),
                          _infoRow('Institusi', 'Politeknik Negeri Batam'),
                          _infoRow('Teknologi', 'Flutter + LoRa + AI'),
                          _infoRow('Backend', 'Python FastAPI + WebSocket'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Logout button
                      TapScale(
                        scale: 0.97,
                        onTap: _logout,
                        child: Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.logout_rounded,
                                size: 18,
                                color: AppColors.error,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Keluar dari Sistem',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
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
      ),
    );
  }

  Widget _buildHeader(AuthProvider auth) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.7),
      border: Border(
        bottom: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.settings_rounded,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pengaturan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            Row(
              children: [
                Text(
                  auth.userName ?? 'Admin',
                  style: TextStyle(fontSize: 11, color: AppColors.textDim),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: auth.isAdmin
                        ? AppColors.warning.withValues(alpha: 0.12)
                        : AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    auth.role.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: auth.isAdmin
                          ? AppColors.warning
                          : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildConnectionCard(bool wsConnected, int nodeCount) {
    final color = wsConnected ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppColors.glassCard(
        radius: 14,
        borderColor: color.withValues(alpha: 0.2),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              wsConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wsConnected ? 'WebSocket Terhubung' : 'HTTP Polling Aktif',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  wsConnected
                      ? '$nodeCount node terpantau real-time'
                      : 'Fallback polling setiap 5 detik',
                  style: TextStyle(fontSize: 11, color: AppColors.textDim),
                ),
              ],
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: AppColors.glassCard(radius: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 14, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
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
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: AppColors.textDim),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: AppColors.textDim, size: 20),
      ],
    ),
  );

  Widget _buildThreshold() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Batas Suhu Kritis',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
            ),
            child: Text(
              '${_threshold.toStringAsFixed(0)}°C',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      SliderTheme(
        data: SliderThemeData(
          activeTrackColor: AppColors.primary,
          inactiveTrackColor: AppColors.surfaceContainerHigh,
          thumbColor: AppColors.primary,
          overlayColor: AppColors.primary.withValues(alpha: 0.1),
          trackHeight: 3,
        ),
        child: Slider(
          value: _threshold,
          min: 30,
          max: 50,
          divisions: 20,
          onChanged: (v) => setState(() => _threshold = v),
          onChangeEnd: (v) {
            context.read<SensorProvider>().updateTempThreshold(v);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Batas suhu kritis diperbarui ke ${v.toStringAsFixed(0)}°C'),
                backgroundColor: AppColors.success,
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
      Text(
        'Waspada ≥ 30°C  ·  Berbahaya ≥ ${_threshold.toStringAsFixed(0)}°C',
        style: TextStyle(fontSize: 11, color: AppColors.textDim),
      ),
    ],
  );

  Widget _buildSwitch(
    String title,
    String sub,
    bool val,
    Function(bool) onChange,
  ) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(fontSize: 11, color: AppColors.textDim)),
          ],
        ),
      ),
      Switch(
        value: val,
        onChanged: onChange,
        activeThumbColor: AppColors.primary,
        activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
      ),
    ],
  );

  Widget _buildIntervalRow() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Interval Refresh',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Fallback polling (saat WS offline)',
              style: TextStyle(fontSize: 11, color: AppColors.textDim),
            ),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: DropdownButton<String>(
          value: _interval,
          dropdownColor: Colors.white,
          underline: const SizedBox(),
          style: const TextStyle(
            color: AppColors.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          items: const [
            DropdownMenuItem(value: '5', child: Text('5 detik')),
            DropdownMenuItem(value: '10', child: Text('10 detik')),
            DropdownMenuItem(value: '30', child: Text('30 detik')),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() => _interval = v);
            context.read<SensorProvider>().setPollInterval(int.parse(v));
          },
        ),
      ),
    ],
  );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.textDim)),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
        ),
      ],
    ),
  );
}
