import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:math';

class WebDashboardPage extends StatefulWidget {
  const WebDashboardPage({super.key});

  @override
  State<WebDashboardPage> createState() => _WebDashboardPageState();
}

class _WebDashboardPageState extends State<WebDashboardPage> {
  Timer? _timer;
  DateTime _lastUpdate = DateTime.now();

  final List<Map<String, dynamic>> sensorNodes = [
    {
      'id': 'A1',
      'name': 'Node Sensor A1',
      'rack': 'Rack Server Utama',
      'suhu': 28.5,
      'status': 'Normal',
      'persentase': 92,
      'statusIcon': Icons.check_circle,
      'statusColor': const Color(0xFF2b7e3a),
    },
    {
      'id': 'B2',
      'name': 'Node Sensor B2',
      'rack': 'Rack Server Backup',
      'suhu': 32.1,
      'status': 'Waspada',
      'persentase': 78,
      'statusIcon': Icons.warning,
      'statusColor': const Color(0xFFe67e22),
    },
    {
      'id': 'C3',
      'name': 'Node Sensor C3',
      'rack': 'Rack Network',
      'suhu': 26.8,
      'status': 'Normal',
      'persentase': 85,
      'statusIcon': Icons.check_circle,
      'statusColor': const Color(0xFF2b7e3a),
    },
    {
      'id': 'D4',
      'name': 'Node Sensor D4',
      'rack': 'Rack Storage',
      'suhu': 41.2,
      'status': 'Berbahaya',
      'persentase': 65,
      'statusIcon': Icons.dangerous,
      'statusColor': const Color(0xFFe53e3e),
    },
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _lastUpdate = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  double get avgTemp {
    return sensorNodes.fold(0.0, (sum, node) => sum + node['suhu']) / sensorNodes.length;
  }

  int get warningCount {
    return sensorNodes.where((node) => node['status'] != 'Normal').length;
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
              _buildHeader(),
              const SizedBox(height: 32),
              _buildSensorGrid(),
              const SizedBox(height: 32),
              _buildFooterStats(),
              const SizedBox(height: 24),
              _buildAlertNote(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.memory, color: Color(0xFF1f6e8a), size: 32),
            const SizedBox(width: 12),
            Text(
              'SUSEMON',
              style: GoogleFonts.inter(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1f6e8a),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFeef2fa),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'PBL-TRPL412',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1f6e8a),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Suhu dan Kelembapan Server Monitoring | LoRa + AI Detection',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF4f6f8f),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.circle, color: Color(0xFF2b7e3a), size: 12),
              const SizedBox(width: 8),
              Text(
                'Monitoring aktif · ${sensorNodes.length} node terhubung',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1f5e7a),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSensorGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 1.1,
      ),
      itemCount: sensorNodes.length,
      itemBuilder: (context, index) {
        final node = sensorNodes[index];
        return _buildSensorCard(node);
      },
    );
  }

  Widget _buildSensorCard(Map<String, dynamic> node) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () {
            // Navigate to detail page
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sensors, color: Color(0xFF1f6e8a), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        node['name'],
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1f3e4c),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFecf3f9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    node['rack'],
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2c5a74),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFf8fafd),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${node['suhu']}',
                        style: GoogleFonts.inter(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: node['suhu'] >= 40
                              ? const Color(0xFFe67e22)
                              : const Color(0xFF172c3a),
                        ),
                      ),
                      Text(
                        '°C',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6f8eae),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFeef2f8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            node['statusIcon'],
                            color: node['statusColor'],
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            node['status'],
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: node['statusColor'],
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${node['persentase']}%',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF2c3e4e),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('${sensorNodes.length}', 'Node Aktif'),
          _buildStatItem('${avgTemp.toStringAsFixed(1)}°C', 'Suhu Rata-rata'),
          _buildStatItem('$warningCount', 'Status Warning'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1f6e8a),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF5f7f9a),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildAlertNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFfff6e8),
        borderRadius: BorderRadius.circular(20),
        border: const Border(
          left: BorderSide(color: Color(0xFFf5a623), width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info, color: Color(0xFFe67e22), size: 20),
              const SizedBox(width: 8),
              Text(
                'Informasi Sistem',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1a2634),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Node D4 dalam status "Berbahaya" — disarankan inspeksi pendinginan. Suhu mencapai 41.2°C.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF4a5568),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Data terbaru: ${_lastUpdate.day}/${_lastUpdate.month}/${_lastUpdate.year} - ${_lastUpdate.hour.toString().padLeft(2, '0')}:${_lastUpdate.minute.toString().padLeft(2, '0')}:${_lastUpdate.second.toString().padLeft(2, '0')}',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF64748b),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

