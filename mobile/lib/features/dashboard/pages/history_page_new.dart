import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/app_provider.dart';
import '../../../models/sensor_model.dart';
import 'package:url_launcher/url_launcher.dart';

class HistoryPageNew extends StatefulWidget {
  const HistoryPageNew({super.key});
  @override
  State<HistoryPageNew> createState() => _HistoryPageNewState();
}

class _HistoryPageNewState extends State<HistoryPageNew>
    with SingleTickerProviderStateMixin {
  late TabController _chartTab;
  final String _period = '30d';
  List<SensorReading> _history = [];
  bool _loading = false;
  String _searchNode = '';

  @override
  void initState() {
    super.initState();
    _chartTab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetch());
  }

  @override
  void dispose() {
    _chartTab.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final sensor = context.read<SensorProvider>();
    final ids = sensor.latest.map((r) => r.nodeId).toList();
    if (ids.isEmpty) return;
    setState(() => _loading = true);
    try {
      final all = await Future.wait(
        ids.map((id) => sensor.getHistory(id, period: _period, limit: 50)),
      );
      if (mounted) {
        setState(
          () =>
              _history = all.expand((x) => x).toList()
                ..sort((a, b) => a.timestamp.compareTo(b.timestamp)),
        );
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _showExportBottomSheet(SensorProvider sensor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ekspor Data Laporan (CSV)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pilih node sensor untuk mengunduh laporan riwayat data.',
              style: TextStyle(fontSize: 12, color: AppColors.textDim),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: sensor.latest.length,
                itemBuilder: (context, i) {
                  final node = sensor.latest[i];
                  return ListTile(
                    leading: const Icon(Icons.table_chart_rounded, color: Color(0xFF16A34A)),
                    title: Text(node.nodeName ?? node.nodeId, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text('ID: ${node.nodeId} · ${node.location ?? ""}', style: const TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.download_rounded, color: AppColors.primary, size: 18),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final url = sensor.getExportUrl(node.nodeId, period: _period);
                      try {
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          throw 'Tidak dapat membuka download link';
                        }
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Gagal mengekspor data: $e'), backgroundColor: AppColors.danger),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const mon = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${mon[d.month]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final sensor = context.watch<SensorProvider>();
    final stats = sensor.stats;
    final latest = sensor.latest;
    final avgTemp = stats.avgTemp;
    final avgHum = stats.avgHumidity;
    final notifCount = sensor.problemCount;
    final uptime = latest.isEmpty
        ? 0.0
        : latest.where((r) => r.status == 'AMAN').length / latest.length * 100;
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));
    final dateRange = '${_formatDate(start)} - ${_formatDate(now)}';

    // Filtered for table
    final tableData = latest
        .where(
          (r) =>
              _searchNode.isEmpty ||
              r.nodeId.toLowerCase().contains(_searchNode.toLowerCase()) ||
              (r.location ?? '').toLowerCase().contains(
                _searchNode.toLowerCase(),
              ),
        )
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FA),
      body: Column(
        children: [
          // ── AppBar ──────────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0058BE),
              boxShadow: [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.menu_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Laporan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    // Kembali button
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.maybePop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_back_ios_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'Kembali',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1D4ED8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await _fetch();
                await sensor.refresh();
              },
              color: AppColors.primary,
              backgroundColor: Colors.white,
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      children: [
                        // ── Date range + export buttons ──────────────────────
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE8EAF0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 14,
                                color: AppColors.textDim,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  dateRange,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: AppColors.textDim,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            // Excel button
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  _showExportBottomSheet(sensor);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFD1D5DB),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.table_chart_rounded,
                                        size: 15,
                                        color: Color(0xFF16A34A),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Excel',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF16A34A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Cetak PDF button
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Ekspor PDF sedang dikembangkan. Silakan gunakan fitur ekspor Excel/CSV.'),
                                      backgroundColor: AppColors.warning,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.picture_as_pdf_rounded,
                                        size: 15,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Cetak PDF',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ── 4 Stat Cards ────────────────────────────────────
                        _StatCard(
                          label: 'RATA-RATA SUHU',
                          value: avgTemp > 0
                              ? '${avgTemp.toStringAsFixed(1)}\u00B0C'
                              : '--',
                          sub: avgTemp > 0
                              ? '\u25B2 1.2% dari target'
                              : 'Menunggu data',
                          subColor: AppColors.danger,
                          icon: Icons.thermostat_rounded,
                          iconColor: const Color(0xFF0EA5E9),
                        ),
                        const SizedBox(height: 10),
                        _StatCard(
                          label: 'RATA-RATA KELEMBAPAN',
                          value: avgHum > 0
                              ? '${avgHum.toStringAsFixed(1)}%'
                              : '--',
                          sub: avgHum > 0
                              ? '\u25BC 0.1% vs hari lalu'
                              : 'Menunggu data',
                          subColor: AppColors.success,
                          icon: Icons.water_drop_rounded,
                          iconColor: const Color(0xFF06B6D4),
                        ),
                        const SizedBox(height: 10),
                        _StatCard(
                          label: 'NOTIFIKASI SISTEM',
                          value: '$notifCount',
                          sub: notifCount == 0
                              ? '\u2713 Semua terselesaikan'
                              : '$notifCount notifikasi aktif',
                          subColor: notifCount == 0
                              ? AppColors.success
                              : AppColors.warning,
                          icon: Icons.notifications_rounded,
                          iconColor: AppColors.primary,
                        ),
                        const SizedBox(height: 10),
                        _StatCard(
                          label: 'UPTIME SENSOR',
                          value: '${uptime.toStringAsFixed(1)}%',
                          sub: uptime >= 99
                              ? '\u26A1 Kinerja Stabil'
                              : 'Periksa sensor offline',
                          subColor: uptime >= 99
                              ? AppColors.primary
                              : AppColors.warning,
                          icon: Icons.shield_outlined,
                          iconColor: AppColors.success,
                        ),
                        const SizedBox(height: 20),

                        // ── Visualisasi Tren Bulanan ─────────────────────────
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE8EAF0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Visualisasi Tren Bulanan',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Data tren sensor selama periode dipilih',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textDim,
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Tab Suhu / Kelembapan
                              TabBar(
                                controller: _chartTab,
                                isScrollable: false,
                                labelStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                                unselectedLabelStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                labelColor: AppColors.primary,
                                unselectedLabelColor: AppColors.textDim,
                                indicatorColor: AppColors.primary,
                                indicatorWeight: 2.5,
                                indicatorSize: TabBarIndicatorSize.tab,
                                tabs: const [
                                  Tab(text: 'Suhu'),
                                  Tab(text: 'Kelembapan'),
                                ],
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                height: 180,
                                child: TabBarView(
                                  controller: _chartTab,
                                  physics: const NeverScrollableScrollPhysics(),
                                  children: [
                                    _buildLineChart(useTemp: true),
                                    _buildLineChart(useTemp: false),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              // X-axis labels
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children:
                                    ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun']
                                        .map(
                                          (m) => Text(
                                            m,
                                            style: const TextStyle(
                                              fontSize: 8,
                                              color: AppColors.textDim,
                                            ),
                                          ),
                                        )
                                        .toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Analisis Cerdas AI ───────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE8EAF0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(
                                    Icons.psychology_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Analisis Cerdas AI',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Data analisis efisiensi sensor terkini.',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textDim,
                                ),
                              ),
                              const SizedBox(height: 14),
                              // AI insight text
                              RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    height: 1.5,
                                  ),
                                  children: [
                                    const TextSpan(
                                      text: 'Mendeteksi anomali pada ',
                                    ),
                                    TextSpan(
                                      text: 'Zone B (Rak 04)',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const TextSpan(
                                      text: '. Efisiensi pendinginan menurun ',
                                    ),
                                    TextSpan(
                                      text: '12%',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.danger,
                                      ),
                                    ),
                                    const TextSpan(text: '.'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              // Rekomendasi box
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F9FC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFE8EAF0),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'REKOMENDASI',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textDim,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.danger.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              5,
                                            ),
                                          ),
                                          child: const Text(
                                            'PRIORITAS',
                                            style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.danger,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Jadwalkan pembersihan filter AC unit-03 dalam 24 jam ke depan.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              // Lihat Laporan Lengkap button
                              GestureDetector(
                                onTap: () => HapticFeedback.lightImpact(),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Lihat Laporan Lengkap',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Detail Statistik Sensor ──────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE8EAF0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  16,
                                  10,
                                ),
                                child: const Text(
                                  'Detail Statistik Sensor',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              // Search
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  10,
                                ),
                                child: Container(
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF4F6FA),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFFE8EAF0),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const SizedBox(width: 10),
                                      Icon(
                                        Icons.search_rounded,
                                        size: 15,
                                        color: AppColors.textDim.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          onChanged: (v) =>
                                              setState(() => _searchNode = v),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textPrimary,
                                          ),
                                          decoration: const InputDecoration(
                                            hintText: 'Cari ID atau Lokasi...',
                                            hintStyle: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textDim,
                                            ),
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: Icon(
                                          Icons.tune_rounded,
                                          size: 15,
                                          color: AppColors.textDim.withValues(
                                            alpha: 0.7,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Table header
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                color: const Color(0xFFF8F9FC),
                                child: const Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        'SENSOR\nID',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textDim,
                                          letterSpacing: 0.4,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        'LOKASI\nPENEMPATAN',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textDim,
                                          letterSpacing: 0.4,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'AVG.\nTEMP',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textDim,
                                          letterSpacing: 0.4,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(
                                height: 1,
                                color: Color(0xFFEEF0F8),
                              ),
                              if (tableData.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Center(
                                    child: Text(
                                      'Tidak ada data',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textDim,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                ...tableData
                                    .take(8)
                                    .map((r) => _SensorTableRow(reading: r)),
                              // Footer
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Center(
                                  child: Text(
                                    'Menampilkan ${tableData.take(8).length} dari ${tableData.length} sensor aktif',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textDim,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart({required bool useTemp}) {
    if (_history.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada data',
          style: TextStyle(fontSize: 11, color: AppColors.textDim),
        ),
      );
    }
    final color = useTemp ? AppColors.primary : const Color(0xFF0EA5E9);
    final spots = _history.asMap().entries.map((e) {
      final val = useTemp ? e.value.temperature : e.value.humidity;
      return FlSpot(e.key.toDouble(), val);
    }).toList();
    final yVals = spots.map((s) => s.y).toList();
    final minY = (yVals.reduce((a, b) => a < b ? a : b) - 3).clamp(0.0, 100.0);
    final maxY = yVals.reduce((a, b) => a > b ? a : b) + 3;
    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 4,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: Color(0xFFF0F2FA), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, _) => Text(
                '${v.toInt()}',
                style: const TextStyle(fontSize: 8, color: AppColors.textDim),
              ),
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: color,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.25),
                  color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _StatCard ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value, sub;
  final Color subColor, iconColor;
  final IconData icon;
  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.subColor,
    required this.iconColor,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE8EAF0)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDim,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 10,
                  color: subColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
      ],
    ),
  );
}

// ── _SensorTableRow ───────────────────────────────────────────────────────────
class _SensorTableRow extends StatelessWidget {
  final SensorReading reading;
  const _SensorTableRow({required this.reading});
  @override
  Widget build(BuildContext context) {
    final sc = AppColors.statusColor(reading.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEEF0F8))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reading.nodeId,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: sc,
                  ),
                ),
                Text(
                  reading.status,
                  style: TextStyle(
                    fontSize: 9,
                    color: sc.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              reading.location?.isNotEmpty == true
                  ? reading.location!
                  : 'Data Center\nRak 01',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${reading.temperature.toStringAsFixed(1)}\u00B0C',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: sc,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
