import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String selectedSensor = 'all';
  String selectedPeriod = '24h';

  final List<Map<String, dynamic>> sensors = [
    {'id': 'A1', 'name': 'Node Sensor A1', 'rack': 'Rack Server Utama', 'baseTemp': 28.5},
    {'id': 'B2', 'name': 'Node Sensor B2', 'rack': 'Rack Server Badung', 'baseTemp': 32.1},
    {'id': 'C3', 'name': 'Node Sensor C3', 'rack': 'Rack Network', 'baseTemp': 26.8},
    {'id': 'D4', 'name': 'Node Sensor D4', 'rack': 'Rack Storage', 'baseTemp': 41.2},
  ];

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
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
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
                        const Icon(Icons.history, color: Color(0xFF1F6E8A), size: 32),
                        const SizedBox(width: 12),
                        Text(
                          'Riwayat Data Sensor',
                          style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1F3E4C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Analisis historis dan tren suhu dari semua node sensor',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF5F7F9A),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Filters
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildFilterDropdown(
                          'Sensor Node',
                          selectedSensor,
                          [
                            {'value': 'all', 'label': 'Semua Sensor'},
                            {'value': 'A1', 'label': 'Node Sensor A1'},
                            {'value': 'B2', 'label': 'Node Sensor B2'},
                            {'value': 'C3', 'label': 'Node Sensor C3'},
                            {'value': 'D4', 'label': 'Node Sensor D4'},
                          ],
                          (value) => setState(() => selectedSensor = value!),
                        ),
                        _buildFilterDropdown(
                          'Periode',
                          selectedPeriod,
                          [
                            {'value': '24h', 'label': '24 Jam Terakhir'},
                            {'value': '7d', 'label': '7 Hari Terakhir'},
                            {'value': '30d', 'label': '30 Hari Terakhir'},
                          ],
                          (value) => setState(() => selectedPeriod = value!),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Stats Overview
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: [
                  _buildStatCard(Icons.thermostat, '32.15°C', 'Rata-rata Suhu', const Color(0xFF1F6E8A)),
                  _buildStatCard(Icons.arrow_upward, '41.2°C', 'Suhu Tertinggi', const Color(0xFFE67E22)),
                  _buildStatCard(Icons.arrow_downward, '26.8°C', 'Suhu Terendah', const Color(0xFF27AE60)),
                  _buildStatCard(Icons.warning_amber, '12', 'Total Peringatan', const Color(0xFFE74C3C)),
                ],
              ),
              const SizedBox(height: 24),

              // Trend Chart
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
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
                        const Icon(Icons.show_chart, color: Color(0xFF1F6E8A), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Tren Suhu 7 Hari Terakhir',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1F3E4C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 200,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(show: true, drawVerticalLine: false),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    '${value.toInt()}°C',
                                    style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF5F7F9A)),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final labels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
                                  if (value.toInt() >= 0 && value.toInt() < labels.length) {
                                    return Text(
                                      labels[value.toInt()],
                                      style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF5F7F9A)),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: _generateLineChartData(),
                          minY: 20,
                          maxY: 45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Data Table
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
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
                        const Icon(Icons.table_chart, color: Color(0xFF1F6E8A), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Log Data Lengkap',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1F3E4C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFD)),
                        columns: [
                          DataColumn(label: Text('Waktu', style: GoogleFonts.inter(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Node', style: GoogleFonts.inter(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Lokasi', style: GoogleFonts.inter(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Suhu', style: GoogleFonts.inter(fontWeight: FontWeight.w700))),
                          DataColumn(label: Text('Status', style: GoogleFonts.inter(fontWeight: FontWeight.w700))),
                        ],
                        rows: _generateDataRows(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<Map<String, String>> items,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF5F7F9A),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFEEF2FA), width: 2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: DropdownButton<String>(
            value: value,
            underline: const SizedBox(),
            items: items.map((item) {
              return DropdownMenuItem(
                value: item['value'],
                child: Text(
                  item['label']!,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1F3E4C),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF5F7F9A),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<LineChartBarData> _generateLineChartData() {
    final colors = [
      const Color(0xFF1F6E8A),
      const Color(0xFFE67E22),
      const Color(0xFF27AE60),
      const Color(0xFFE74C3C),
    ];

    return sensors.asMap().entries.map((entry) {
      final index = entry.key;
      final sensor = entry.value;
      final random = Random(index);

      return LineChartBarData(
        spots: List.generate(7, (i) {
          return FlSpot(
            i.toDouble(),
            sensor['baseTemp'] + (random.nextDouble() * 4 - 2),
          );
        }),
        isCurved: true,
        color: colors[index],
        barWidth: 2,
        dotData: const FlDotData(show: false),
      );
    }).toList();
  }

  List<DataRow> _generateDataRows() {
    final now = DateTime.now();
    final random = Random();

    return List.generate(10, (i) {
      final time = now.subtract(Duration(minutes: i * 30));
      final sensor = sensors[random.nextInt(sensors.length)];
      final temp = sensor['baseTemp'] + (random.nextDouble() * 4 - 2);
      final status = temp > 40 ? 'Waspada' : 'Aman';

      return DataRow(
        cells: [
          DataCell(Text(
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
            style: GoogleFonts.robotoMono(fontSize: 12),
          )),
          DataCell(Text(sensor['name'], style: GoogleFonts.inter(fontSize: 12))),
          DataCell(Text(sensor['rack'], style: GoogleFonts.inter(fontSize: 12))),
          DataCell(Text(
            '${temp.toStringAsFixed(1)}°C',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: temp > 40 ? const Color(0xFFE67E22) : const Color(0xFF4F6F8F),
            ),
          )),
          DataCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: status == 'Aman' ? const Color(0xFFE3F7EC) : const Color(0xFFFFF0E0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: status == 'Aman' ? const Color(0xFF1F7840) : const Color(0xFFC45D1A),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

