import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:math';

class AnalisisAIPage extends StatefulWidget {
  const AnalisisAIPage({super.key});

  @override
  State<AnalisisAIPage> createState() => _AnalisisAIPageState();
}

class _AnalisisAIPageState extends State<AnalisisAIPage> {
  Timer? _timer;
  int _lastPing = 12;
  int _packetReceived = 17347;
  int _packetLost = 23;

  final List<Map<String, dynamic>> aiAnalysis = [
    {
      'title': 'Pola Overheating',
      'icon': Icons.local_fire_department,
      'badge': 'AI Powered',
      'confidence': '94%',
      'description': 'Sensor NODE-004 menunjukkan peningkatan suhu 2.3°C/jam dalam 3 jam terakhir.',
    },
    {
      'title': 'Anomali Pola Suhu',
      'icon': Icons.show_chart,
      'badge': 'Anomali',
      'confidence': '87%',
      'description': 'NODE-002 menunjukkan pola fluktuasi tidak normal.',
    },
    {
      'title': 'Tren Peningkatan',
      'icon': Icons.trending_up,
      'badge': 'Pola',
      'confidence': '91%',
      'description': 'Suhu rata-rata ruang server meningkat 1.5°C dalam setengah tahun.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      setState(() {
        _lastPing = Random().nextInt(20) + 5;
        _packetReceived++;
        if (Random().nextDouble() < 0.1) _packetLost++;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
              const SizedBox(height: 24),
              _buildAIGrid(),
              const SizedBox(height: 24),
              _buildGatewayCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Color(0xFF1f6e8a), size: 28),
                const SizedBox(width: 12),
                Text(
                  'Analisis AI',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1f6e8a),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Monitoring Prediktif berbasis AI',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF4f6f8f),
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.memory, color: Color(0xFFe67e22), size: 18),
              const SizedBox(width: 8),
              Text(
                '4 Node · Aktif',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAIGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: aiAnalysis.length,
      itemBuilder: (context, index) {
        final item = aiAnalysis[index];
        return _buildAICard(item);
      },
    );
  }

  Widget _buildAICard(Map<String, dynamic> item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(item['icon'], color: const Color(0xFF1f6e8a), size: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFeef2ff),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item['badge'],
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2563eb),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item['title'],
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  item['confidence'],
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1f6e8a),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item['description'],
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF4b6f8e),
                    height: 1.3,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGatewayCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.router, color: Color(0xFF1f8a4c), size: 28),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status LoRa Gateway',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFe3f7ec),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.circle, color: Color(0xFF1f7840), size: 8),
                        const SizedBox(width: 6),
                        Text(
                          'Terhubung',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1f7840),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildParamRow('Frekuensi', '923.5 MHz', Icons.cell_tower),
          _buildParamRow('Spreading Factor', 'SF7', Icons.expand),
          _buildParamRow('Bandwidth', '125 kHz', Icons.waves),
          _buildParamRow('Tx Power', '20 dBm', Icons.speed),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFf8fafc),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      _packetReceived.toString(),
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1f6e8a),
                      ),
                    ),
                    Text(
                      'Paket Diterima',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF5b7c9c),
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      _packetLost.toString(),
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1f6e8a),
                      ),
                    ),
                    Text(
                      'Paket Hilang',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF5b7c9c),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildParamRow('Last Ping', '$_lastPing s', Icons.access_time),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFf8fafc),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF2b7e3a), size: 16),
                const SizedBox(width: 8),
                Text(
                  'Link quality: Excellent (RSSI -52 dBm)',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParamRow(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFf0f2f8)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF5b7c9c)),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF5b7c9c),
                ),
              ),
            ],
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1f3e4c),
            ),
          ),
        ],
      ),
    );
  }
}

