import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

class NotifikasiPage extends StatefulWidget {
  const NotifikasiPage({super.key});

  @override
  State<NotifikasiPage> createState() => _NotifikasiPageState();
}

class _NotifikasiPageState extends State<NotifikasiPage> {
  String currentTime = '';
  Timer? _timer;

  final List<Map<String, dynamic>> notifications = [
    {
      'message': 'Suhu NODE-004 mencapai 41.2°C - Tidak aman!',
      'time': '02:00:35',
      'node': 'NODE-004',
      'type': 'critical',
      'icon': Icons.thermostat,
    },
    {
      'message': 'Pola anomali suhu terdeteksi pada NODE-002',
      'time': '02:00:30',
      'node': 'NODE-002',
      'type': 'warning',
      'icon': Icons.show_chart,
    },
    {
      'message': 'Analisis AI: Prediksi overheating dalam 30 menit',
      'time': '02:00:25',
      'node': 'NODE-004',
      'type': 'warning',
      'icon': Icons.psychology,
    },
    {
      'message': 'Sistem koneksi dengan LoRa Gateway berhasil',
      'time': '02:00:20',
      'node': 'SYSTEM',
      'type': 'success',
      'icon': Icons.satellite_alt,
    },
  ];

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} WIB';
    });
  }

  Color _getIconBgColor(String type) {
    switch (type) {
      case 'critical':
        return const Color(0xFFFEE9E6);
      case 'warning':
        return const Color(0xFFFFF0E0);
      case 'success':
        return const Color(0xFFE3F7EC);
      default:
        return const Color(0xFFFEF3E8);
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'critical':
        return const Color(0xFFE53E3E);
      case 'warning':
        return const Color(0xFFE67E22);
      case 'success':
        return const Color(0xFF2B7E3A);
      default:
        return const Color(0xFFE67E22);
    }
  }

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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.notifications, color: const Color(0xFF1F6E8A), size: 32),
                          const SizedBox(width: 12),
                          Text(
                            'Susemon',
                            style: GoogleFonts.inter(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1F6E8A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '?? Pusat notifikasi & peringatan sistem',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF4F6F8F),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(60),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber, color: Color(0xFFE67E22), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '4 Node · 2 Peringatan',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Main Notifications Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 35,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFD),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(36),
                          topRight: Radius.circular(36),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications, color: Color(0xFFE67E22), size: 24),
                          const SizedBox(width: 10),
                          Text(
                            'Semua Notifikasi',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1F3E4C),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(40),
                            ),
                            child: Text(
                              '${notifications.length}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1F6E8A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Notifications List
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final notif = notifications[index];
                        return InkWell(
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: const Color(0xFFF0F2F8),
                                  width: index == notifications.length - 1 ? 0 : 1,
                                ),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: _getIconBgColor(notif['type']),
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  child: Icon(
                                    notif['icon'],
                                    color: _getIconColor(notif['type']),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              notif['message'],
                                              style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                                color: const Color(0xFF1E2F3E),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF4F7FC),
                                              borderRadius: BorderRadius.circular(30),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.access_time, size: 10, color: Color(0xFF7C9AC0)),
                                                const SizedBox(width: 6),
                                                Text(
                                                  notif['time'],
                                                  style: GoogleFonts.robotoMono(
                                                    fontSize: 11,
                                                    color: const Color(0xFF8BA0BC),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEEF2FF),
                                              borderRadius: BorderRadius.circular(30),
                                            ),
                                            child: Text(
                                              notif['node'],
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF1F6E8A),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Summary Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildSummaryItem(Icons.memory, 'Sensor:', '4 Aktif', 'Normal:2 | Peringatan:2'),
                    const SizedBox(height: 8),
                    _buildSummaryItem(Icons.show_chart, 'Analisis:', 'AI Prediktif', 'Overheating risk'),
                    const SizedBox(height: 8),
                    _buildSummaryItem(Icons.notifications, 'Notifikasi:', '${notifications.length}', 'Terbaru 2 menit'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Footer Note
              Center(
                child: Text(
                  '?? Notifikasi real-time · $currentTime',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF7F9CBB),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String label, String value, String badge) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFCFE),
        borderRadius: BorderRadius.circular(60),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1F6E8A), size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF5F7E9E),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2C5A74),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              badge,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F6E8A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

