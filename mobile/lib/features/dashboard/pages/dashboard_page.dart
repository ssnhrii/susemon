import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/app_provider.dart';
import '../../../models/sensor_model.dart';
import '../../../shared/widgets/interactive.dart';
import '../../../shared/widgets/mesh_background.dart';
import 'sensor_detail_page.dart';
import 'settings_system_page.dart';
// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD PAGE — desain baru sesuai mockup
// ─────────────────────────────────────────────────────────────────────────────

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _formatTanggal(DateTime d) {
    const bulan = [
      '',
      'JANUARI',
      'FEBRUARI',
      'MARET',
      'APRIL',
      'MEI',
      'JUNI',
      'JULI',
      'AGUSTUS',
      'SEPTEMBER',
      'OKTOBER',
      'NOVEMBER',
      'DESEMBER',
    ];
    return '${d.day} ${bulan[d.month]} ${d.year}';
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final sensor = context.watch<SensorProvider>();
    final isOffline = sensor.error != null;
    final now = DateTime.now();
    final dateStr = _formatTanggal(now);
    final offlineCount = sensor.latest
        .where((r) => r.status == 'BERBAHAYA' || r.status == 'WASPADA')
        .length;
    final avgTemp = sensor.stats.avgTemp;
    final avgHum = sensor.stats.avgHumidity;
    final globalStatus = sensor.globalStatus;
    final statusColor = AppColors.statusColor(globalStatus);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FF),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          sensor.refresh();
        },
        backgroundColor: AppColors.primary,
        elevation: 4,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: MeshBackground(
        child: SafeArea(
          child: Column(
            children: [
              _AppBar(wsConnected: sensor.wsConnected),
              if (isOffline) _OfflineBanner(onRetry: sensor.refresh),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    HapticFeedback.mediumImpact();
                    await sensor.refresh();
                  },
                  color: AppColors.primary,
                  backgroundColor: Colors.white,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            // ── Header ──
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 0),
                              child: _DashHeader(
                                dateStr: dateStr,
                                exportUrl: sensor.latest.isNotEmpty
                                    ? sensor.getExportUrl(
                                        sensor.latest.first.nodeId,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 20),
                            // ── 4 Stat Cards ──
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 60),
                              child: _StatCardsGrid(
                                activeCount: sensor.latest.length,
                                offlineCount: offlineCount,
                                avgTemp: avgTemp,
                                avgHum: avgHum,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // ── Status Banner ──
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 120),
                              child: _StatusBannerNew(
                                status: globalStatus,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(height: 20),
                            // ── Tren Suhu ──
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 160),
                              child: _TrendCard(
                                title: 'Tren Suhu',
                                subtitle:
                                    'Riwayat tingkat suhu 24 jam terakhir',
                                readings: sensor.latest,
                                useTemp: true,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // ── Tren Kelembapan ──
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 200),
                              child: _TrendCard(
                                title: 'Tren Kelembapan',
                                subtitle:
                                    'Analisis tingkat kelembapan selama mingguan',
                                readings: sensor.latest,
                                useTemp: false,
                              ),
                            ),
                            const SizedBox(height: 20),
                            // ── Aktivitas Terbaru ──
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 240),
                              child: _AktivitasTerbaru(readings: sensor.latest),
                            ),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── AppBar ───────────────────────────────────────────────────────────────────
class _AppBar extends StatelessWidget {
  final bool wsConnected;
  const _AppBar({required this.wsConnected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.dashboard_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Text(
            'DASHBOARD',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          _PulseDot(connected: wsConnected),
          const SizedBox(width: 8),
          _iconBtn(Icons.notifications_outlined, () {}),
          const SizedBox(width: 4),
          _iconBtn(Icons.settings_outlined, () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsSystemPage()),
            );
          }),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    ),
  );
}

class _PulseDot extends StatefulWidget {
  final bool connected;
  const _PulseDot({required this.connected});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _a = Tween<double>(begin: 0.3, end: 1.0).animate(_c);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final col = widget.connected
        ? const Color(0xFF4ADE80)
        : const Color(0xFFFBBF24);
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: col.withValues(alpha: _a.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const _OfflineBanner({required this.onRetry});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: AppColors.danger.withValues(alpha: 0.12),
    child: Row(
      children: [
        const Icon(Icons.cloud_off_rounded, color: AppColors.danger, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Koneksi ke backend terputus.',
            style: TextStyle(
              color: AppColors.danger,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        GestureDetector(
          onTap: onRetry,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Coba Lagi',
              style: TextStyle(
                color: AppColors.danger,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// ── DashHeader ───────────────────────────────────────────────────────────────
class _DashHeader extends StatelessWidget {
  final String dateStr;
  final String? exportUrl;
  const _DashHeader({required this.dateStr, this.exportUrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dashboard Utama',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Tampilkan real-time infrastruktur sensor jaringan data.',
          style: TextStyle(fontSize: 12, color: AppColors.textDim),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 12,
                    color: AppColors.textDim,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dateStr,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            TapScale(
              onTap: () => HapticFeedback.lightImpact(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryContainer],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.upload_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'EKSPOR DATA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── StatCardsGrid ────────────────────────────────────────────────────────────
class _StatCardsGrid extends StatelessWidget {
  final int activeCount, offlineCount;
  final double avgTemp, avgHum;
  const _StatCardsGrid({
    required this.activeCount,
    required this.offlineCount,
    required this.avgTemp,
    required this.avgHum,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _StatCard(
              icon: Icons.sensors_rounded,
              iconColor: AppColors.primary,
              badge: '$activeCount AKTIF',
              badgeColor: AppColors.primary,
              label: 'SENSOR AKTIF',
              value: '$activeCount',
              valueColor: AppColors.textPrimary,
            ),
            const SizedBox(width: 12),
            _StatCard(
              icon: Icons.sensors_off_rounded,
              iconColor: AppColors.danger,
              badge: offlineCount > 0 ? '$offlineCount OFFLINE' : 'AMAN',
              badgeColor: offlineCount > 0
                  ? AppColors.danger
                  : AppColors.success,
              label: 'SENSOR OFFLINE',
              value: '$offlineCount',
              valueColor: offlineCount > 0
                  ? AppColors.danger
                  : AppColors.success,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _StatCard(
              icon: Icons.thermostat_rounded,
              iconColor: const Color(0xFF0EA5E9),
              badge: avgTemp > 0 ? '+${avgTemp.toStringAsFixed(1)}°C' : '--',
              badgeColor: const Color(0xFF0EA5E9),
              label: 'RATA-RATA SUHU',
              value: avgTemp > 0
                  ? '${avgTemp.toStringAsFixed(0)}\u00B0C'
                  : '--',
              valueColor: AppColors.textPrimary,
            ),
            const SizedBox(width: 12),
            _StatCard(
              icon: Icons.water_drop_rounded,
              iconColor: const Color(0xFF06B6D4),
              badge: '',
              badgeColor: Colors.transparent,
              label: 'KELEMBAPAN',
              value: avgHum > 0 ? '${avgHum.toStringAsFixed(0)}%' : '--',
              valueColor: AppColors.textPrimary,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor, badgeColor, valueColor;
  final String badge, label, value;
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.badge,
    required this.badgeColor,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
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
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const Spacer(),
              if (badge.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: badgeColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textDim,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: valueColor,
              height: 1.1,
            ),
          ),
        ],
      ),
    ),
  );
}

// ── StatusBannerNew ─────────────────────────────────────────────────────────
class _StatusBannerNew extends StatefulWidget {
  final String status;
  final Color color;
  const _StatusBannerNew({required this.status, required this.color});
  @override
  State<_StatusBannerNew> createState() => _StatusBannerNewState();
}

class _StatusBannerNewState extends State<_StatusBannerNew>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulse = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    if (widget.status != 'AMAN') {
      _ctrl.repeat(reverse: true);
    } else {
      _ctrl.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_StatusBannerNew old) {
    super.didUpdateWidget(old);
    if (widget.status != old.status) {
      if (widget.status != 'AMAN') {
        _ctrl.repeat(reverse: true);
      } else {
        _ctrl.stop();
        _ctrl.value = 1.0;
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _statusLabel {
    switch (widget.status) {
      case 'BERBAHAYA':
        return 'Kondisi Kritis!';
      case 'WASPADA':
        return 'Perlu Perhatian';
      case 'MEMUAT':
        return 'Memuat Data...';
      default:
        return 'Lancar \u0026 Aman';
    }
  }

  IconData get _icon {
    switch (widget.status) {
      case 'BERBAHAYA':
        return Icons.local_fire_department_rounded;
      case 'WASPADA':
        return Icons.warning_amber_rounded;
      case 'MEMUAT':
        return Icons.hourglass_empty_rounded;
      default:
        return Icons.verified_user_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGood = widget.status == 'AMAN';
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isGood
                ? [const Color(0xFF0058BE), const Color(0xFF2170E4)]
                : [widget.color.withValues(alpha: 0.9), widget.color],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (isGood ? AppColors.primary : widget.color).withValues(
                alpha: 0.3 * _pulse.value,
              ),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'STATUS SISTEM',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _statusLabel,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── TrendCard ────────────────────────────────────────────────────────────────
class _TrendCard extends StatelessWidget {
  final String title, subtitle;
  final List<SensorReading> readings;
  final bool useTemp;
  const _TrendCard({
    required this.title,
    required this.subtitle,
    required this.readings,
    required this.useTemp,
  });

  List<FlSpot> _buildSpots() {
    if (readings.isEmpty) {
      return List.generate(
        7,
        (i) => FlSpot(i.toDouble(), (20 + i * 2).toDouble()),
      );
    }
    final sorted = [...readings]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return sorted.asMap().entries.map((e) {
      final val = useTemp ? e.value.temperature : e.value.humidity;
      return FlSpot(e.key.toDouble(), val);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final spots = _buildSpots();
    final lineColor = useTemp ? AppColors.primary : const Color(0xFF0EA5E9);
    final fillColor = useTemp ? AppColors.primary : const Color(0xFF0EA5E9);
    final yVals = spots.map((s) => s.y).toList();
    final minY = yVals.isEmpty
        ? 0.0
        : (yVals.reduce((a, b) => a < b ? a : b) - 5).clamp(0.0, 100.0);
    final maxY = yVals.isEmpty
        ? 100.0
        : yVals.reduce((a, b) => a > b ? a : b) + 5;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
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
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textDim),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (val, meta) {
                        if (val.toInt() % 2 != 0)
                          return const SizedBox.shrink();
                        return Text(
                          '${val.toInt()}',
                          style: const TextStyle(
                            fontSize: 8,
                            color: AppColors.textDim,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: lineColor,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          fillColor.withValues(alpha: 0.25),
                          fillColor.withValues(alpha: 0.0),
                        ],
                      ),
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
}

// ── AktivitasTerbaru ─────────────────────────────────────────────────────────
class _AktivitasTerbaru extends StatelessWidget {
  final List<SensorReading> readings;
  const _AktivitasTerbaru({required this.readings});

  Color _statusColor(String s) {
    switch (s.toUpperCase()) {
      case 'BERBAHAYA':
        return AppColors.danger;
      case 'WASPADA':
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  String _statusLabel(String s) {
    switch (s.toUpperCase()) {
      case 'BERBAHAYA':
        return 'Offline';
      case 'WASPADA':
        return 'Offline';
      default:
        return 'Normal';
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = readings.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Aktivitas Terbaru',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => HapticFeedback.selectionClick(),
              child: const Text(
                'LIHAT SEMUA',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              // header row
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'SENSOR ID',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDim,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'STATUS',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDim,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'WAKTU',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDim,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        'AKSI',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDim,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Belum ada aktivitas',
                      style: TextStyle(fontSize: 12, color: AppColors.textDim),
                    ),
                  ),
                )
              else
                ...items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final r = entry.value;
                  final statusCol = _statusColor(r.status);
                  final statusLbl = _statusLabel(r.status);
                  final timeAgo = _timeAgo(r.timestamp);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: i.isEven
                          ? Colors.white.withValues(alpha: 0.0)
                          : AppColors.primary.withValues(alpha: 0.02),
                      border: Border(
                        top: BorderSide(
                          color: AppColors.outlineVariant.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.nodeId,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                r.nodeName ?? '',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: AppColors.textDim,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusCol.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '\u2022 $statusLbl',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: statusCol,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            timeAgo,
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textDim,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              final n = SensorNode(
                                id: 0,
                                nodeId: r.nodeId,
                                nodeName: r.nodeName ?? r.nodeId,
                                location: r.location ?? '',
                                isActive: true,
                                currentTemp: r.temperature,
                                currentHumidity: r.humidity,
                                currentStatus: r.status,
                                lastSeen: r.timestamp,
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SensorDetailPage(node: n),
                                ),
                              );
                            },
                            child: const Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  String _timeAgo(DateTime ts) {
    final diff = DateTime.now().difference(ts.toLocal());
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }
}
