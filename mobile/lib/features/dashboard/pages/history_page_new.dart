import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

class HistoryPageNew extends StatefulWidget {
  const HistoryPageNew({super.key});

  @override
  State<HistoryPageNew> createState() => _HistoryPageNewState();
}

class _HistoryPageNewState extends State<HistoryPageNew> {
  String selectedSensor = 'all';
  String selectedPeriod = '7d';
  String appliedSensor = 'all';
  String appliedPeriod = '7d';
  
  void _applyFilters() {
    setState(() {
      appliedSensor = selectedSensor;
      appliedPeriod = selectedPeriod;
    });
    
    // Show snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Filter diterapkan: ${_getSensorLabel(appliedSensor)} - ${_getPeriodLabel(appliedPeriod)}',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  String _getSensorLabel(String value) {
    switch (value) {
      case 'all': return 'Semua Sensor';
      case 'A1': return 'Node A1';
      case 'B2': return 'Node B2';
      case 'C3': return 'Node C3';
      case 'D4': return 'Node D4';
      default: return value;
    }
  }
  
  String _getPeriodLabel(String value) {
    switch (value) {
      case '24h': return '24 Jam';
      case '7d': return '7 Hari';
      case '30d': return '30 Hari';
      default: return value;
    }
  }
  
  Widget _buildStatsOverview() {
    // Calculate stats based on applied filters
    double avgTemp = 32.15;
    double maxTemp = 41.2;
    double minTemp = 26.8;
    int warnings = 12;
    
    if (appliedSensor == 'A1') {
      avgTemp = 28.5;
      maxTemp = 30.2;
      minTemp = 26.8;
      warnings = 2;
    } else if (appliedSensor == 'B2') {
      avgTemp = 32.8;
      maxTemp = 35.1;
      minTemp = 30.5;
      warnings = 5;
    } else if (appliedSensor == 'C3') {
      avgTemp = 27.2;
      maxTemp = 29.5;
      minTemp = 25.1;
      warnings = 1;
    } else if (appliedSensor == 'D4') {
      avgTemp = 41.5;
      maxTemp = 43.8;
      minTemp = 39.2;
      warnings = 18;
    }
    
    // Adjust based on period
    if (appliedPeriod == '24h') {
      warnings = (warnings * 0.5).round();
    } else if (appliedPeriod == '30d') {
      warnings = (warnings * 3).round();
    }
    
    return Row(
      children: [
        Expanded(child: _buildStatCard('Rata-rata', '${avgTemp.toStringAsFixed(1)}°C', Icons.thermostat, AppColors.primary)),
        const SizedBox(width: AppSizes.paddingM),
        Expanded(child: _buildStatCard('Tertinggi', '${maxTemp.toStringAsFixed(1)}°C', Icons.arrow_upward, AppColors.danger)),
        const SizedBox(width: AppSizes.paddingM),
        Expanded(child: _buildStatCard('Terendah', '${minTemp.toStringAsFixed(1)}°C', Icons.arrow_downward, AppColors.success)),
        const SizedBox(width: AppSizes.paddingM),
        Expanded(child: _buildStatCard('Peringatan', warnings.toString(), Icons.warning_amber, AppColors.warning)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.paddingL),
      child: Column(
        children: [
          // Filters
          Row(
            children: [
              Expanded(
                child: _buildFilter(
                  'Sensor Node',
                  selectedSensor,
                  [
                    {'value': 'all', 'label': 'Semua Sensor'},
                    {'value': 'A1', 'label': 'Node A1'},
                    {'value': 'B2', 'label': 'Node B2'},
                    {'value': 'C3', 'label': 'Node C3'},
                    {'value': 'D4', 'label': 'Node D4'},
                  ],
                  (value) => setState(() => selectedSensor = value!),
                ),
              ),
              const SizedBox(width: AppSizes.paddingM),
              Expanded(
                child: _buildFilter(
                  'Periode',
                  selectedPeriod,
                  [
                    {'value': '24h', 'label': '24 Jam'},
                    {'value': '7d', 'label': '7 Hari'},
                    {'value': '30d', 'label': '30 Hari'},
                  ],
                  (value) => setState(() => selectedPeriod = value!),
                ),
              ),
              const SizedBox(width: AppSizes.paddingM),
              InkWell(
                onTap: _applyFilters,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Terapkan',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingL),

          // Stats Overview
          _buildStatsOverview(),
          const SizedBox(height: AppSizes.paddingL),

          // Trend Chart
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildTrendChart(),
              ),
              const SizedBox(width: AppSizes.paddingM),
              Expanded(
                child: _buildStatusPieChart(),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingL),

          // Data Table
          _buildDataTable(),
        ],
      ),
    );
  }

  Widget _buildFilter(String label, String value, List<Map<String, String>> items, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: const Color(0xFF203A43),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            items: items.map((item) {
              return DropdownMenuItem(
                value: item['value'],
                child: Text(item['label']!),
              );
            }).toList(),
            onChanged: onChanged,
          ),
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
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.orbitron(
              fontSize: 24,
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

  Widget _buildTrendChart() {
    // Generate data based on applied period
    int dataPoints = appliedPeriod == '24h' ? 24 : appliedPeriod == '7d' ? 7 : 30;
    
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
              Text(
                'Tren Suhu ${_getPeriodLabel(appliedPeriod)}',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Text(
                  _getSensorLabel(appliedSensor),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
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
                      interval: appliedPeriod == '30d' ? 5 : 1,
                      getTitlesWidget: (value, meta) {
                        if (appliedPeriod == '24h') {
                          return Text(
                            '${value.toInt()}h',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          );
                        } else if (appliedPeriod == '7d') {
                          final days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
                          if (value.toInt() >= 0 && value.toInt() < days.length) {
                            return Text(
                              days[value.toInt()],
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            );
                          }
                        } else {
                          return Text(
                            'D${value.toInt() + 1}',
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
                  LineChartBarData(
                    spots: List.generate(dataPoints, (i) {
                      // Different base temp for different sensors
                      double baseTemp = 30;
                      if (appliedSensor == 'A1') baseTemp = 28;
                      if (appliedSensor == 'B2') baseTemp = 32;
                      if (appliedSensor == 'C3') baseTemp = 27;
                      if (appliedSensor == 'D4') baseTemp = 41;
                      
                      return FlSpot(i.toDouble(), baseTemp + Random().nextDouble() * 4);
                    }),
                    isCurved: true,
                    color: appliedSensor == 'D4' ? AppColors.danger : 
                           appliedSensor == 'B2' ? AppColors.warning : AppColors.primary,
                    barWidth: 3,
                    dotData: FlDotData(show: dataPoints <= 24),
                    belowBarData: BarAreaData(
                      show: true,
                      color: (appliedSensor == 'D4' ? AppColors.danger : 
                             appliedSensor == 'B2' ? AppColors.warning : AppColors.primary).withOpacity(0.2),
                    ),
                  ),
                ],
                minY: 20,
                maxY: 45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPieChart() {
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
            'Distribusi Status',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    value: 65,
                    title: '65%',
                    color: AppColors.success,
                    radius: 60,
                    titleStyle: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: 25,
                    title: '25%',
                    color: AppColors.warning,
                    radius: 60,
                    titleStyle: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: 10,
                    title: '10%',
                    color: AppColors.danger,
                    radius: 60,
                    titleStyle: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
                sectionsSpace: 2,
                centerSpaceRadius: 40,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildLegendItem('Aman', AppColors.success),
          const SizedBox(height: 8),
          _buildLegendItem('Waspada', AppColors.warning),
          const SizedBox(height: 8),
          _buildLegendItem('Berbahaya', AppColors.danger),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
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

  Widget _buildDataTable() {
    // Generate data based on applied filters
    int recordCount = appliedPeriod == '24h' ? 12 : appliedPeriod == '7d' ? 10 : 15;
    
    final data = List.generate(recordCount, (i) {
      final now = DateTime.now().subtract(Duration(hours: i * 2));
      
      // Filter by sensor
      String nodeId;
      if (appliedSensor == 'all') {
        nodeId = ['A1', 'B2', 'C3', 'D4'][Random().nextInt(4)];
      } else {
        nodeId = appliedSensor;
      }
      
      // Different temp ranges for different nodes
      double baseTemp = 30;
      if (nodeId == 'A1') baseTemp = 28;
      if (nodeId == 'B2') baseTemp = 32;
      if (nodeId == 'C3') baseTemp = 27;
      if (nodeId == 'D4') baseTemp = 41;
      
      final temp = baseTemp + Random().nextDouble() * 4;
      final humidity = 60 + Random().nextDouble() * 20;
      final status = temp > 40 ? 'Berbahaya' : temp > 35 ? 'Waspada' : 'Aman';
      final color = temp > 40 ? AppColors.danger : temp > 35 ? AppColors.warning : AppColors.success;
      
      return {
        'time': '${now.day}/${now.month} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        'node': 'Node $nodeId',
        'temp': temp.toStringAsFixed(1),
        'humidity': humidity.toStringAsFixed(1),
        'status': status,
        'color': color,
      };
    });

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
              Text(
                'Log Data Lengkap',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                '${data.length} records',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.2),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
              4: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                children: [
                  _buildTableHeader('Waktu'),
                  _buildTableHeader('Node'),
                  _buildTableHeader('Suhu'),
                  _buildTableHeader('Kelembapan'),
                  _buildTableHeader('Status'),
                ],
              ),
              ...data.map((row) {
                return TableRow(
                  children: [
                    _buildTableCell(row['time'] as String),
                    _buildTableCell(row['node'] as String),
                    _buildTableCell('${row['temp']}°C'),
                    _buildTableCell('${row['humidity']}%'),
                    _buildTableCellStatus(row['status'] as String, row['color'] as Color),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTableCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildTableCellStatus(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
