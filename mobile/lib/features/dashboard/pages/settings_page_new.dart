import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

class SettingsPageNew extends StatefulWidget {
  const SettingsPageNew({super.key});

  @override
  State<SettingsPageNew> createState() => _SettingsPageNewState();
}

class _SettingsPageNewState extends State<SettingsPageNew> {
  double tempThreshold = 40.0;
  bool emailNotif = true;
  bool pushNotif = true;
  bool soundAlert = false;
  String refreshInterval = '30';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(AppSizes.paddingL),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  border: Border(
                    bottom: BorderSide(color: AppColors.cardBorder),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pengaturan Sistem',
                          style: GoogleFonts.orbitron(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Konfigurasi & Preferensi',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSizes.paddingL),
                  child: Column(
                    children: [
                      // Threshold Settings
                      _buildSection(
                        'Pengaturan Threshold',
                        Icons.thermostat,
                        [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Batas Suhu Kritis',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.danger.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${tempThreshold.toStringAsFixed(1)}°C',
                                      style: GoogleFonts.orbitron(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.danger,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SliderTheme(
                                data: SliderThemeData(
                                  activeTrackColor: AppColors.danger,
                                  inactiveTrackColor: AppColors.danger.withOpacity(0.2),
                                  thumbColor: AppColors.danger,
                                  overlayColor: AppColors.danger.withOpacity(0.2),
                                ),
                                child: Slider(
                                  value: tempThreshold,
                                  min: 30,
                                  max: 50,
                                  divisions: 20,
                                  label: '${tempThreshold.toStringAsFixed(1)}°C',
                                  onChanged: (value) {
                                    setState(() {
                                      tempThreshold = value;
                                    });
                                  },
                                ),
                              ),
                              Text(
                                'Sistem akan memberikan peringatan jika suhu melebihi batas ini',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Notification Settings
                      _buildSection(
                        'Pengaturan Notifikasi',
                        Icons.notifications,
                        [
                          _buildSwitchTile(
                            'Notifikasi Email',
                            'Kirim peringatan ke email saat ada anomali',
                            emailNotif,
                            (value) => setState(() => emailNotif = value),
                          ),
                          const Divider(height: 24, color: AppColors.cardBorder),
                          _buildSwitchTile(
                            'Notifikasi Push',
                            'Tampilkan notifikasi push di perangkat',
                            pushNotif,
                            (value) => setState(() => pushNotif = value),
                          ),
                          const Divider(height: 24, color: AppColors.cardBorder),
                          _buildSwitchTile(
                            'Suara Peringatan',
                            'Mainkan suara saat ada peringatan kritis',
                            soundAlert,
                            (value) => setState(() => soundAlert = value),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // System Settings
                      _buildSection(
                        'Pengaturan Sistem',
                        Icons.tune,
                        [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Interval Refresh Data',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Frekuensi pembaruan data sensor',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.bgCard,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.cardBorder),
                                ),
                                child: DropdownButton<String>(
                                  value: refreshInterval,
                                  underline: const SizedBox(),
                                  dropdownColor: const Color(0xFF203A43),
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  items: [
                                    DropdownMenuItem(value: '10', child: Text('10 detik')),
                                    DropdownMenuItem(value: '30', child: Text('30 detik')),
                                    DropdownMenuItem(value: '60', child: Text('1 menit')),
                                    DropdownMenuItem(value: '300', child: Text('5 menit')),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      refreshInterval = value!;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Sensor Management
                      _buildSection(
                        'Manajemen Sensor Node',
                        Icons.memory,
                        [
                          _buildSensorNode('Node A1', 'Rack Server Utama', true, AppColors.success),
                          const SizedBox(height: 12),
                          _buildSensorNode('Node B2', 'Rack Server Backup', true, AppColors.warning),
                          const SizedBox(height: 12),
                          _buildSensorNode('Node C3', 'Rack Network', true, AppColors.success),
                          const SizedBox(height: 12),
                          _buildSensorNode('Node D4', 'Rack Storage', true, AppColors.danger),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // About
                      _buildSection(
                        'Tentang Aplikasi',
                        Icons.info_outline,
                        [
                          _buildInfoRow('Versi Aplikasi', '1.0.0'),
                          const SizedBox(height: 12),
                          _buildInfoRow('ID Proyek', 'PBL-TRPL412'),
                          const SizedBox(height: 12),
                          _buildInfoRow('Institusi', 'Politeknik Negeri Bali'),
                          const SizedBox(height: 12),
                          _buildInfoRow('Teknologi', 'Flutter + LoRa + AI'),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Save Button
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppSizes.radiusL),
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '✅ Pengaturan berhasil disimpan!',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                ),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSizes.radiusL),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.save, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'SIMPAN PENGATURAN',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingL),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildSensorNode(String name, String location, bool isActive, Color statusColor) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: statusColor,
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                location,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isActive ? 'Aktif' : 'Nonaktif',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
