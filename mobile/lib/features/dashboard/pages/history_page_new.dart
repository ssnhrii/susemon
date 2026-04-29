import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/app_provider.dart';
import '../../../models/sensor_model.dart';

class HistoryPageNew extends StatefulWidget {
  const HistoryPageNew({super.key});
  @override
  State<HistoryPageNew> createState() => _HistoryPageNewState();
}

class _HistoryPageNewState extends State<HistoryPageNew> {
  String _nodeId = '';
  String _period = '24h';
  List<SensorReading> _history = [];
  bool _loading = false;
  List<String> _nodes = [];

  final _periods = {'24h': '24 Jam', '7d': '7 Hari', '30d': '30 Hari'};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ambil node IDs dari data sensor real (bukan hardcode)
      final sensor = context.read<SensorProvider>();
      final ids = sensor.latest.map((r) => r.nodeId).toList();
      if (ids.isNotEmpty) {
        setState(() {
          _nodes  = ids;
          _nodeId = ids.first;
        });
        _fetch();
      } else {
        // Fallback: fetch latest dulu, lalu ambil node IDs
        sensor.refresh().then((_) {
          final freshIds = context.read<SensorProvider>().latest.map((r) => r.nodeId).toList();
          if (freshIds.isNotEmpty && mounted) {
            setState(() {
              _nodes  = freshIds;
              _nodeId = freshIds.first;
            });
            _fetch();
          }
        });
      }
    });
  }

  Future<void> _fetch() async {
    if (_nodeId.isEmpty) return;
    setState(() { _loading = true; });
    try {
      final data = await context.read<SensorProvider>().getHistory(_nodeId, period: _period);
      if (mounted) setState(() => _history = data);
    } catch (e) {
      if (mounted) {
        setState(() => _history = []);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data: $e'),
              backgroundColor: AppColors.danger, duration: const Duration(seconds: 3)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sensor = context.watch<SensorProvider>().stats;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildStats(sensor),
                    const SizedBox(height: 14),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                      )
                    else if (_history.isNotEmpty) ...[
                      _buildChart(),
                      const SizedBox(height: 14),
                      _buildLog(),
                    ] else
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Tidak ada data untuk periode ini',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    color: AppColors.bgCard,
    child: Column(
      children: [
        Row(children: [
          const Icon(Icons.history_rounded, color: AppColors.primary, size: 22),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Riwayat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
            Text('Data historis sensor', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ]),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          // Node selector
          Expanded(child: _nodes.isEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(color: AppColors.bgCardAlt, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.cardBorder)),
                child: const Text('Memuat node...', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              )
            : _selector(
                value: _nodeId,
                items: {for (var n in _nodes) n: 'Node $n'},
                onChanged: (v) { setState(() => _nodeId = v!); _fetch(); },
              )),
          const SizedBox(width: 10),
          // Period selector
          Expanded(child: _selector(
            value: _period,
            items: _periods,
            onChanged: (v) { setState(() => _period = v!); _fetch(); },
          )),
        ]),
      ],
    ),
  );

  Widget _selector({required String value, required Map<String, String> items,
      required Function(String?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCardAlt, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        dropdownColor: AppColors.bgCard,
        underline: const SizedBox(),
        style: const TextStyle(color: Colors.white, fontSize: 12),
        items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildStats(SensorStats stats) {
    final data = [
      ['${stats.avgTemp.toStringAsFixed(1)}°C', 'Rata-rata', AppColors.primary],
      ['${stats.maxTemp.toStringAsFixed(1)}°C', 'Tertinggi', AppColors.danger],
      ['${stats.minTemp.toStringAsFixed(1)}°C', 'Terendah', AppColors.success],
      ['${stats.dangerCount + stats.warningCount}', 'Peringatan', AppColors.warning],
    ];
    return Row(
      children: data.asMap().entries.map((e) {
        final s = e.value;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(left: e.key == 0 ? 0 : 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgCard, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(children: [
              Text(s[0] as String, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: s[2] as Color)),
              const SizedBox(height: 2),
              Text(s[1] as String, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary), textAlign: TextAlign.center),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChart() {
    if (_history.isEmpty) return const SizedBox.shrink();

    final spots = _history.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.temperature))
        .toList();

    // Dynamic Y-axis berdasarkan data aktual
    final temps = _history.map((r) => r.temperature).toList();
    final minY  = (temps.reduce((a, b) => a < b ? a : b) - 3).clamp(0.0, 100.0);
    final maxY  = (temps.reduce((a, b) => a > b ? a : b) + 3).clamp(0.0, 100.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Tren Suhu Node $_nodeId · ${_periods[_period]}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 14),
        SizedBox(
          height: 160,
          child: LineChart(LineChartData(
            minY: minY, maxY: maxY,
            gridData: FlGridData(show: true, drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(color: AppColors.cardBorder, strokeWidth: 1)),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30,
                  getTitlesWidget: (v, _) => Text('${v.toInt()}°',
                      style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)))),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            extraLinesData: ExtraLinesData(horizontalLines: [
              HorizontalLine(y: 35, color: AppColors.warning.withOpacity(0.5), strokeWidth: 1, dashArray: [5, 4]),
              HorizontalLine(y: 40, color: AppColors.danger.withOpacity(0.5), strokeWidth: 1, dashArray: [5, 4]),
            ]),
            lineBarsData: [LineChartBarData(
              spots: spots, isCurved: true, color: AppColors.primary, barWidth: 2,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, __, ___) {
                  // Bounds check agar tidak crash
                  final idx = spot.x.toInt();
                  if (idx < 0 || idx >= _history.length) {
                    return FlDotCirclePainter(radius: 2, color: AppColors.primary, strokeWidth: 0);
                  }
                  final r = _history[idx];
                  final c = AppColors.statusColor(r.status);
                  return FlDotCirclePainter(radius: r.status != 'AMAN' ? 4 : 2, color: c, strokeWidth: 0);
                },
              ),
              belowBarData: BarAreaData(show: true, color: AppColors.primary.withOpacity(0.08)),
            )],
          )),
        ),
      ]),
    );
  }

  Widget _buildLog() {
    final fmt = DateFormat('dd/MM HH:mm');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Log Data', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 12),
        ..._history.reversed.take(15).map((r) {
          final sc = AppColors.statusColor(r.status);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: AppColors.bgCardAlt, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Text(fmt.format(r.timestamp),
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'monospace')),
              const SizedBox(width: 10),
              Expanded(child: Text('${r.temperature.toStringAsFixed(1)}°C  ·  ${r.humidity.toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sc))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: sc.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(r.status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: sc)),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}
