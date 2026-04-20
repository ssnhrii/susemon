import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  double tempThreshold = 40.0;
  bool emailNotif = true;
  bool pushNotif = true;
  bool soundAlert = false;
  String refreshInterval = '30';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.settings, color: Color(0xFF1F6E8A), size: 32),
                  const SizedBox(width: 12),
                  Text(
                    'Pengaturan Sistem',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1F6E8A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Konfigurasi threshold, notifikasi, dan preferensi sistem',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF4F6F8F),
                ),
              ),
              const SizedBox(height: 32),

              // Threshold Settings
              _buildSettingCard(
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
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1F3E4C),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${tempThreshold.toStringAsFixed(1)}°C',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1F6E8A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Slider(
                        value: tempThreshold,
                        min: 30,
                        max: 50,
                        divisions: 20,
                        activeColor: const Color(0xFF1F6E8A),
                        label: '${tempThreshold.toStringAsFixed(1)}°C',
                        onChanged: (value) {
                          setState(() {
                            tempThreshold = value;
                          });
                        },
                      ),
                      Text(
                        'Sistem akan memberikan peringatan jika suhu melebihi batas ini',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF7F9CBB),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Notification Settings
              _buildSettingCard(
                'Pengaturan Notifikasi',
                Icons.notifications,
                [
                  _buildSwitchTile(
                    'Notifikasi Email',
                    'Kirim peringatan ke email saat ada anomali',
                    emailNotif,
                    (value) => setState(() => emailNotif = value),
                  ),
                  const Divider(height: 24),
                  _buildSwitchTile(
                    'Notifikasi Push',
                    'Tampilkan notifikasi push di perangkat',
                    pushNotif,
                    (value) => setState(() => pushNotif = value),
                  ),
                  const Divider(height: 24),
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
              _buildSettingCard(
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
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1F3E4C),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Frekuensi pembaruan data sensor',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF7F9CBB),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFEEF2FA), width: 2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: DropdownButton<String>(
                          value: refreshInterval,
                          underline: const SizedBox(),
                          items: [
                            DropdownMenuItem(value: '10', child: Text('10 detik', style: GoogleFonts.inter())),
                            DropdownMenuItem(value: '30', child: Text('30 detik', style: GoogleFonts.inter())),
                            DropdownMenuItem(value: '60', child: Text('1 menit', style: GoogleFonts.inter())),
                            DropdownMenuItem(value: '300', child: Text('5 menit', style: GoogleFonts.inter())),
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
              _buildSettingCard(
                'Manajemen Sensor Node',
                Icons.memory,
                [
                  _buildSensorNodeItem('Node Sensor A1', 'Rack Server Utama', true, const Color(0xFF27AE60)),
                  const Divider(height: 20),
                  _buildSensorNodeItem('Node Sensor B2', 'Rack Server Badung', true, const Color(0xFFE67E22)),
                  const Divider(height: 20),
                  _buildSensorNodeItem('Node Sensor C3', 'Rack Network', true, const Color(0xFF27AE60)),
                  const Divider(height: 20),
                  _buildSensorNodeItem('Node Sensor D4', 'Rack Storage', true, const Color(0xFFE74C3C)),
                ],
              ),
              const SizedBox(height: 20),

              // About Section
              _buildSettingCard(
                'Tentang Aplikasi',
                Icons.info_outline,
                [
                  _buildInfoRow('Versi Aplikasi', '1.0.0'),
                  const SizedBox(height: 12),
                  _buildInfoRow('ID Proyek', 'PBL-TRPL412'),
                  const SizedBox(height: 12),
                  _buildInfoRow('Institusi', 'Politeknik Negeri Bali'),
                  const SizedBox(height: 12),
                  _buildInfoRow('Durasi', '14 Minggu'),
                  const SizedBox(height: 12),
                  _buildInfoRow('Teknologi', 'Flutter + LoRa + AI'),
                ],
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '? Pengaturan berhasil disimpan!',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                        backgroundColor: const Color(0xFF27AE60),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F6E8A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Simpan Pengaturan',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingCard(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF1F6E8A), size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F3E4C),
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
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1F3E4C),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF7F9CBB),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF1F6E8A),
        ),
      ],
    );
  }

  Widget _buildSensorNodeItem(String name, String location, bool isActive, Color statusColor) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
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
                  color: const Color(0xFF1F3E4C),
                ),
              ),
              Text(
                location,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF7F9CBB),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFE3F7EC) : const Color(0xFFFEE9E6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isActive ? 'Aktif' : 'Nonaktif',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive ? const Color(0xFF1F7840) : const Color(0xFFE53E3E),
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
            fontSize: 14,
            color: const Color(0xFF5F7F9A),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1F3E4C),
          ),
        ),
      ],
    );
  }
}

