import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

class AnalisPage extends StatelessWidget {
  const AnalisPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Analysis Cards
          Row(
            children: [
              Expanded(
                child: _buildAICard(
                  'Overheating Detection',
                  '94%',
                  'Akurasi prediksi overheating dalam 30 menit',
                  Icons.local_fire_department,
                  AppColors.danger,
                  'HIGH RISK',
                ),
              ),
              const SizedBox(width: AppSizes.paddingM),
              Expanded(
                child: _buildAICard(
                  'Anomaly Detection',
                  '87%',
                  'Deteksi pola anomali suhu tidak normal',
                  Icons.warning_amber,
                  AppColors.warning,
                  'MEDIUM',
                ),
              ),
              const SizedBox(width: AppSizes.paddingM),
              Expanded(
                child: _buildAICard(
                  'Trend Analysis',
                  '91%',
                  'Analisis tren kenaikan suhu 7 hari',
                  Icons.trending_up,
                  AppColors.success,
                  'NORMAL',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingL),

          // Prediction Chart
          Container(
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
                    Icon(Icons.psychology, color: AppColors.primary, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'AI Prediction - Suhu 24 Jam Kedepan',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 250,
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
                                '${value.toInt()}°C',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() % 4 == 0) {
                                return Text(
                                  '${value.toInt()}h',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                  ),
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
                      lineBarsData: [
                        // Actual data
                        LineChartBarData(
                          spots: List.generate(12, (i) {
                            return FlSpot(i.toDouble(), 28 + Random().nextDouble() * 6);
                          }),
                          isCurved: true,
                          color: AppColors.primary,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.primary.withOpacity(0.2),
                          ),
                        ),
                        // Prediction data
                        LineChartBarData(
                          spots: List.generate(12, (i) {
                            return FlSpot((i + 12).toDouble(), 30 + Random().nextDouble() * 8);
                          }),
                          isCurved: true,
                          color: AppColors.warning,
                          barWidth: 3,
                          dashArray: [5, 5],
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.warning.withOpacity(0.1),
                          ),
                        ),
                      ],
                      minY: 20,
                      maxY: 45,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegend('Data Aktual', AppColors.primary),
                    const SizedBox(width: 24),
                    _buildLegend('Prediksi AI', AppColors.warning),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.paddingL),

          // AI Methods & LoRa Info
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  'Metode AI',
                  [
                    {'label': 'Moving Average', 'value': 'Window: 10 data'},
                    {'label': 'Z-Score Analysis', 'value': 'Threshold: 2.5σ'},
                    {'label': 'Model Accuracy', 'value': '94.2%'},
                  ],
                  Icons.analytics,
                ),
              ),
              const SizedBox(width: AppSizes.paddingM),
              Expanded(
                child: _buildInfoCard(
                  'LoRa Gateway',
                  [
                    {'label': 'Frequency', 'value': '923.5 MHz'},
                    {'label': 'Spreading Factor', 'value': 'SF7'},
                    {'label': 'Bandwidth', 'value': '125 kHz'},
                    {'label': 'TX Power', 'value': '20 dBm'},
                  ],
                  Icons.router,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingL),

          // Recommendations
          Container(
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
                    Icon(Icons.lightbulb, color: AppColors.warning, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Rekomendasi AI',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildRecommendation(
                  'HIGH PRIORITY',
                  'Node D4 menunjukkan tren overheating. Periksa sistem pendingin segera.',
                  AppColors.danger,
                ),
                const SizedBox(height: 12),
                _buildRecommendation(
                  'MEDIUM',
                  'Node B2 mengalami fluktuasi suhu. Monitor dalam 2 jam kedepan.',
                  AppColors.warning,
                ),
                const SizedBox(height: 12),
                _buildRecommendation(
                  'INFO',
                  'Sistem berjalan optimal. Maintenance rutin direkomendasikan minggu depan.',
                  AppColors.success,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAICard(String title, String percentage, String description, IconData icon, Color color, String status) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingL),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            percentage,
            style: GoogleFonts.orbitron(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, List<Map<String, String>> items, IconData icon) {
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
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
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
          const SizedBox(height: 16),
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item['label']!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    item['value']!,
                    style: GoogleFonts.robotoMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
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

  Widget _buildRecommendation(String priority, String message, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              priority,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
