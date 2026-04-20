import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'dart:math';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Timer? _timer;
  final List<FlSpot> _suhuData = [];
  final List<FlSpot> _kelembapanData = [];
  double _currentSuhu = 28.5;
  double _currentKelembapan = 65.0;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _updateData();
    });
  }

  void _initializeData() {
    for (int i = 0; i < 10; i++) {
      _suhuData.add(FlSpot(i.toDouble(), 28 + Random().nextDouble() * 5));
      _kelembapanData.add(FlSpot(i.toDouble(), 60 + Random().nextDouble() * 15));
    }
  }

  void _updateData() {
    setState(() {
      _currentSuhu = 28 + Random().nextDouble() * 8;
      _currentKelembapan = 60 + Random().nextDouble() * 20;
      
      if (_suhuData.length >= 20) {
        _suhuData.removeAt(0);
        _kelembapanData.removeAt(0);
        for (int i = 0; i < _suhuData.length; i++) {
          _suhuData[i] = FlSpot(i.toDouble(), _suhuData[i].y);
          _kelembapanData[i] = FlSpot(i.toDouble(), _kelembapanData[i].y);
        }
      }
      
      _suhuData.add(FlSpot(_suhuData.length.toDouble(), _currentSuhu));
      _kelembapanData.add(FlSpot(_kelembapanData.length.toDouble(), _currentKelembapan));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.paddingL),
      child: Column(
        children: [
          // Stats Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Suhu Real-time',
                  '${_currentSuhu.toStringAsFixed(1)}°C',
                  Icons.thermostat,
                  _currentSuhu > 35 ? AppColors.danger : AppColors.success,
                ),
              ),
              const SizedBox(width: AppSizes.paddingM),
              Expanded(
                child: _buildStatCard(
                  'Kelembapan',
                  '${_currentKelembapan.toStringAsFixed(1)}%',
                  Icons.water_drop,
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSizes.paddingM),
              Expanded(
                child: _buildStatCard(
                  'Status',
                  _currentSuhu > 35 ? 'WASPADA' : 'AMAN',
                  Icons.check_circle,
                  _currentSuhu > 35 ? AppColors.warning : AppColors.success,
                ),
              ),
              const SizedBox(width: AppSizes.paddingM),
              Expanded(
                child: _buildStatCard(
                  'Node Aktif',
                  '4/4',
                  Icons.sensors,
                  AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingL),

          // Charts
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildChartCard(
                  'Grafik Suhu Real-time',
                  _suhuData,
                  AppColors.danger,
                  '°C',
                  20,
                  45,
                ),
              ),
              const SizedBox(width: AppSizes.paddingM),
              Expanded(
                flex: 2,
                child: _buildChartCard(
                  'Grafik Kelembapan Real-time',
                  _kelembapanData,
                  AppColors.primary,
                  '%',
                  40,
                  90,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingL),

          // Sensor Nodes
          _buildSensorNodes(),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color,
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.orbitron(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(String title, List<FlSpot> data, Color color, String unit, double minY, double maxY) {
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
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.white.withOpacity(0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}$unit',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: data,
                    isCurved: true,
                    color: color,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withOpacity(0.2),
                    ),
                  ),
                ],
                minY: minY,
                maxY: maxY,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorNodes() {
    final nodes = [
      {'id': 'A1', 'name': 'Rack Server Utama', 'suhu': 28.5, 'status': 'AMAN'},
      {'id': 'B2', 'name': 'Rack Server Backup', 'suhu': 32.1, 'status': 'WASPADA'},
      {'id': 'C3', 'name': 'Rack Network', 'suhu': 26.8, 'status': 'AMAN'},
      {'id': 'D4', 'name': 'Rack Storage', 'suhu': 41.2, 'status': 'BERBAHAYA'},
    ];

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
          Text(
            'Node Sensor Status',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          ...nodes.map((node) {
            final color = node['status'] == 'AMAN'
                ? AppColors.success
                : node['status'] == 'WASPADA'
                    ? AppColors.warning
                    : AppColors.danger;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        node['id'] as String,
                        style: GoogleFonts.orbitron(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          node['name'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${node['suhu']}°C',
                          style: GoogleFonts.robotoMono(
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
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      node['status'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
