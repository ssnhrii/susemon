import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/app_provider.dart';
import '../../../models/sensor_model.dart';
import '../../../shared/widgets/interactive.dart';

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

  static const _periods = {
    '1h': '1 Jam', '6h': '6 Jam', '24h': '24 Jam',
    '7d': '7 Hari', '30d': '30 Hari',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sensor = context.read<SensorProvider>();
      final ids = sensor.latest.map((r) => r.nodeId).toList();
      if (ids.isNotEmpty) {
        setState(() { _nodes = ids; _nodeId = ids.first; });
        _fetch();
      } else {
        sensor.refresh().then((_) {
          final freshIds = context.read<SensorProvider>().latest.map((r) => r.nodeId).toList();
          if (freshIds.isNotEmpty && mounted) {
            setState(() { _nodes = freshIds; _nodeId = freshIds.first; });
            _fetch();
          }
        });
      }
    });
  }

  Future<void> _fetch() async {
    if (_nodeId.isEmpty) return;
    setState(() => _loading = true);
    try {
      final data = await context.read<SensorProvider>()
          .getHistory(_nodeId, period: _period, limit: 200);
      if (mounted) setState(() => _history = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal memuat: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportCsv() async {
    if (_nodeId.isEmpty) return;
    final url = context.read<SensorProvider>().getExportUrl(_nodeId, period: _period);
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tidak bisa membuka URL export'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<SensorProvider>().stats;
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(children: [
                        _buildStatsRow(stats),
                        const SizedBox(height: 16),
                        if (_history.isNotEmpty) ...[
                          _buildChartCard(),
                          const SizedBox(height: 16),
                          _buildLogCard(),
                        ] else _buildEmpty(),
                        const SizedBox(height: 24),
                      ]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
    ),
    child: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.history_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Riwayat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
            Text('Data historis sensor', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ]),
          const Spacer(),
          if (_nodeId.isNotEmpty)
            TapScale(
              onTap: () {
                HapticFeedback.lightImpact();
                _exportCsv();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.download_rounded, size: 14, color: AppColors.success),
                  SizedBox(width: 5),
                  Text('CSV', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success)),
                ]),
              ),
            ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Row(children: [
          Expanded(child: _nodes.isEmpty
              ? _selectorPlaceholder()
              : _dropdown(
                  value: _nodeId,
                  items: {for (var n in _nodes) n: 'Node $n'},
                  onChanged: (v) { setState(() => _nodeId = v!); _fetch(); },
                )),
          const SizedBox(width: 10),
          Expanded(child: _dropdown(
            value: _period,
            items: _periods,
            onChanged: (v) { setState(() => _period = v!); _fetch(); },
          )),
        ]),
      ),
    ]),
  );

  Widget _selectorPlaceholder() => Container(
    height: 42,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: AppColors.bgCardAlt, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.cardBorder),
    ),
    alignment: Alignment.centerLeft,
    child: const Text('Memuat node...', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
  );

  Widget _dropdown({
    required String value,
    required Map<String, String> items,
    required Function(String?) onChanged,
  }) => Container(
    height: 42,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: AppColors.bgCardAlt, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.cardBorder),
    ),
    child: DropdownButton<String>(
      value: value, isExpanded: true,
      dropdownColor: AppColors.bgCard, underline: const SizedBox(),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 18),
      style: const TextStyle(color: Colors.white, fontSize: 12),
      items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
      onChanged: onChanged,
    ),
  );

  Widget _buildStatsRow(SensorStats stats) {
    final items = [
      ['${stats.avgTemp.toStringAsFixed(1)}°C', 'Rata-rata', AppColors.primary],
      ['${stats.maxTemp.toStringAsFixed(1)}°C', 'Tertinggi', AppColors.danger],
      ['${stats.minTemp.toStringAsFixed(1)}°C', 'Terendah', AppColors.success],
      ['${stats.dangerCount + stats.warningCount}', 'Alert', AppColors.warning],
    ];
    return Row(
      children: items.asMap().entries.map((e) {
        final item = e.value;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(left: e.key == 0 ? 0 : 8),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.bgCard, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(children: [
              Text(item[0] as String,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: item[2] as Color)),
              const SizedBox(height: 3),
              Text(item[1] as String,
                  style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChartCard() {
    if (_history.isEmpty) return const SizedBox.shrink();
    final temps = _history.map((r) => r.temperature).toList();
    final minT  = (temps.reduce((a, b) => a < b ? a : b) - 2).clamp(0.0, 100.0);
    final maxT  = (temps.reduce((a, b) => a > b ? a : b) + 2).clamp(0.0, 100.0);
    final tempSpots = _history.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.temperature)).toList();
    final humSpots  = _history.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(),
            e.value.humidity * (maxT - minT) / 100 + minT)).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Grafik Sensor',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
          const Spacer(),
          _legend(AppColors.primary, 'Suhu'),
          const SizedBox(width: 12),
          _legend(const Color(0xFF29B6F6), 'Kelembapan'),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: LineChart(LineChartData(
            minY: minT, maxY: maxT,
            clipData: const FlClipData.all(),
            gridData: FlGridData(
              show: true, drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(color: AppColors.cardBorder, strokeWidth: 0.8),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 32,
                getTitlesWidget: (v, _) => Text('${v.toInt()}°',
                    style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
              )),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            extraLinesData: ExtraLinesData(horizontalLines: [
              HorizontalLine(y: 35, color: AppColors.warning.withOpacity(0.4), strokeWidth: 1, dashArray: [5, 4]),
              HorizontalLine(y: 40, color: AppColors.danger.withOpacity(0.4), strokeWidth: 1, dashArray: [5, 4]),
            ]),
            lineBarsData: [
              LineChartBarData(
                spots: tempSpots, isCurved: true, color: AppColors.primary, barWidth: 2,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, _, __, ___) {
                    final idx = spot.x.toInt();
                    if (idx < 0 || idx >= _history.length) {
                      return FlDotCirclePainter(radius: 0, color: Colors.transparent, strokeWidth: 0);
                    }
                    final r = _history[idx];
                    if (r.status == 'AMAN') {
                      return FlDotCirclePainter(radius: 0, color: Colors.transparent, strokeWidth: 0);
                    }
                    return FlDotCirclePainter(radius: 4, color: AppColors.statusColor(r.status), strokeWidth: 0);
                  },
                ),
                belowBarData: BarAreaData(show: true, color: AppColors.primary.withOpacity(0.06)),
              ),
              LineChartBarData(
                spots: humSpots, isCurved: true,
                color: const Color(0xFF29B6F6).withOpacity(0.6), barWidth: 1.5,
                dotData: const FlDotData(show: false),
                dashArray: [4, 3],
                belowBarData: BarAreaData(show: false),
              ),
            ],
          )),
        ),
        const SizedBox(height: 8),
        Text(
          '${_history.length} data · ${_periods[_period]} · Node $_nodeId',
          style: const TextStyle(fontSize: 10, color: AppColors.textDim),
        ),
      ]),
    );
  }

  Widget _legend(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 12, height: 3,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 5),
    Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
  ]);

  Widget _buildLogCard() {
    final fmt    = DateFormat('dd/MM HH:mm');
    final recent = _history.reversed.take(20).toList();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(children: [
            const Text('Log Data',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            const Spacer(),
            Text('${recent.length} terbaru',
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ]),
        ),
        const SizedBox(height: 10),
        const Divider(color: AppColors.cardBorder, height: 1),
        ...recent.map((r) {
          final sc = AppColors.statusColor(r.status);
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                Container(width: 6, height: 6,
                    decoration: BoxDecoration(color: sc, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Text(fmt.format(r.timestamp.toLocal()),
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'monospace')),
                const SizedBox(width: 12),
                Text('${r.temperature.toStringAsFixed(1)}°C',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sc)),
                const SizedBox(width: 8),
                Text('${r.humidity.toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: sc.withOpacity(0.12), borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(r.status,
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: sc)),
                ),
              ]),
            ),
            if (r != recent.last) const Divider(color: AppColors.cardBorder, height: 1, indent: 32),
          ]);
        }),
        const SizedBox(height: 4),
      ]),
    );
  }

  Widget _buildEmpty() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: AppColors.bgCard, borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: const Icon(Icons.bar_chart_rounded, size: 28, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        const Text('Tidak ada data',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
        const SizedBox(height: 6),
        const Text('Coba pilih periode yang berbeda',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ]),
    ),
  );
}
