import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/app_provider.dart';
import '../../../models/sensor_model.dart';
import '../../../shared/widgets/interactive.dart';
import '../../../shared/widgets/mesh_background.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sensor = context.watch<SensorProvider>();
    final status = sensor.globalStatus;
    final sc = AppColors.statusColor(status);
    final isOffline = sensor.error != null;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: MeshBackground(
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(
                wsConnected: sensor.wsConnected,
                nodeCount: sensor.nodeCount,
              ),
              if (isOffline)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.15),
                    border: const Border(
                      bottom: BorderSide(color: AppColors.danger, width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off_rounded,
                          color: AppColors.danger, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Koneksi ke backend terputus. Menampilkan data terakhir.',
                          style: TextStyle(
                              color: AppColors.danger,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          sensor.refresh();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Coba Lagi',
                            style: TextStyle(
                                color: AppColors.danger,
                                fontSize: 10,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    HapticFeedback.mediumImpact();
                    await sensor.refresh();
                  },
                  color: AppColors.primary,
                  backgroundColor: Colors.white,
                  displacement: 40,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 0),
                              child: _StatusBanner(
                                status: status,
                                sc: sc,
                                problemCount: sensor.problemCount,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 80),
                              child: _StatsRow(stats: sensor.stats),
                            ),
                            const SizedBox(height: 20),
                            if (sensor.loading && sensor.latest.isEmpty) ...[
                              FadeSlideIn(
                                delay: const Duration(milliseconds: 120),
                                child: _SkeletonGrid(),
                              ),
                            ] else if (sensor.latest.isNotEmpty) ...[
                              FadeSlideIn(
                                delay: const Duration(milliseconds: 120),
                                child: _SectionHeader(
                                  title: 'Node Sensor',
                                  count: sensor.nodeCount,
                                ),
                              ),
                              const SizedBox(height: 12),
                              FadeSlideIn(
                                delay: const Duration(milliseconds: 160),
                                child: _NodeGrid(readings: sensor.latest),
                              ),
                            ] else if (!sensor.loading)
                              FadeSlideIn(
                                delay: const Duration(milliseconds: 120),
                                child: _EmptyState(error: sensor.error),
                              ),
                            const SizedBox(height: 24),
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

// ── Top Bar ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final bool wsConnected;
  final int nodeCount;
  const _TopBar({required this.wsConnected, required this.nodeCount});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.7),
      border: Border(
        bottom: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
      ),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: const Icon(
            Icons.sensors_rounded,
            size: 20,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SUSEMON',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
                letterSpacing: 2,
              ),
            ),
            Text(
              'Dashboard Utama',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const Spacer(),
        _LiveBadge(wsConnected: wsConnected, nodeCount: nodeCount),
      ],
    ),
  );
}

class _LiveBadge extends StatefulWidget {
  final bool wsConnected;
  final int nodeCount;
  const _LiveBadge({required this.wsConnected, required this.nodeCount});
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_pulse);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.wsConnected ? AppColors.success : AppColors.warning;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: color.withValues(alpha: _anim.value),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              widget.wsConnected
                  ? 'LIVE · ${widget.nodeCount} Node'
                  : 'POLLING',
              key: ValueKey(widget.wsConnected),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status Banner ─────────────────────────────────────────────────────────────

class _StatusBanner extends StatefulWidget {
  final String status;
  final Color sc;
  final int problemCount;
  const _StatusBanner({
    required this.status,
    required this.sc,
    required this.problemCount,
  });
  @override
  State<_StatusBanner> createState() => _StatusBannerState();
}

class _StatusBannerState extends State<_StatusBanner>
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
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    if (widget.status != 'AMAN') _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_StatusBanner old) {
    super.didUpdateWidget(old);
    if (widget.status != old.status) {
      if (widget.status != 'AMAN') {
        HapticFeedback.heavyImpact();
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

  IconData get _icon {
    switch (widget.status) {
      case 'BERBAHAYA':
        return Icons.local_fire_department_rounded;
      case 'WASPADA':
        return Icons.warning_amber_rounded;
      case 'MEMUAT':
        return Icons.hourglass_empty_rounded;
      default:
        return Icons.verified_rounded;
    }
  }

  String get _subtitle {
    switch (widget.status) {
      case 'BERBAHAYA':
        return '${widget.problemCount} sensor dalam kondisi kritis!';
      case 'WASPADA':
        return '${widget.problemCount} sensor perlu perhatian';
      case 'MEMUAT':
        return 'Mengambil data sensor...';
      default:
        return 'Semua sensor dalam kondisi normal';
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _pulse,
    builder: (_, __) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.sc.withValues(alpha: 0.3 * _pulse.value + 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: widget.sc.withValues(alpha: 0.06 * _pulse.value),
            blurRadius: 16,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: widget.sc.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_icon, color: widget.sc, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STATUS SISTEM',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: widget.sc.withValues(alpha: 0.6),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    widget.status,
                    key: ValueKey(widget.status),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: widget.sc,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.sc.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: widget.sc.withValues(alpha: _pulse.value),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final SensorStats stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _StatCard(
        label: 'Rata-rata',
        value: stats.avgTemp,
        suffix: '°',
        icon: Icons.thermostat_rounded,
        color: AppColors.primary,
      ),
      const SizedBox(width: 10),
      _StatCard(
        label: 'Tertinggi',
        value: stats.maxTemp,
        suffix: '°',
        icon: Icons.arrow_upward_rounded,
        color: AppColors.danger,
      ),
      const SizedBox(width: 10),
      _StatCard(
        label: 'Kelembapan',
        value: stats.avgHumidity,
        suffix: '%',
        icon: Icons.water_drop_rounded,
        color: const Color(0xFF0EA5E9),
        decimals: 0,
      ),
    ],
  );
}

class _StatCard extends StatelessWidget {
  final String label, suffix;
  final double value;
  final IconData icon;
  final Color color;
  final int decimals;
  const _StatCard({
    required this.label,
    required this.value,
    required this.suffix,
    required this.icon,
    required this.color,
    this.decimals = 1,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: TapScale(
      onTap: () => HapticFeedback.selectionClick(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: AppColors.glassCard(radius: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(height: 10),
            AnimatedCounter(
              value: value,
              suffix: suffix,
              decimals: decimals,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  const _SectionHeader({required this.title, this.count});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
        ),
      ),
      if (count != null) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    ],
  );
}

// ── Skeleton Grid ─────────────────────────────────────────────────────────────

class _SkeletonGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SkeletonBox(width: 100, height: 14, radius: 7),
      const SizedBox(height: 12),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.95,
        ),
        itemCount: 4,
        itemBuilder: (_, __) => const SkeletonNodeCard(),
      ),
    ],
  );
}

// ── Node Grid ─────────────────────────────────────────────────────────────────

class _NodeGrid extends StatelessWidget {
  final List<SensorReading> readings;
  const _NodeGrid({required this.readings});

  @override
  Widget build(BuildContext context) {
    final sorted = [...readings]
      ..sort((a, b) {
        const o = {'BERBAHAYA': 0, 'WASPADA': 1, 'AMAN': 2};
        return (o[a.status] ?? 3).compareTo(o[b.status] ?? 3);
      });
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemCount: sorted.length,
      itemBuilder: (_, i) => FadeSlideIn(
        delay: Duration(milliseconds: 40 * i),
        child: _NodeCard(reading: sorted[i]),
      ),
    );
  }
}

class _NodeCard extends StatelessWidget {
  final SensorReading reading;
  const _NodeCard({required this.reading});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.statusColor(reading.status);
    final timeStr = DateFormat('HH:mm').format(reading.timestamp.toLocal());

    return TapScale(
      onTap: () {
        HapticFeedback.selectionClick();
        _showNodeDetail(context, reading);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -10,
              right: -10,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.06),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          reading.nodeId,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    reading.nodeName ?? reading.nodeId,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  AnimatedCounter(
                    value: reading.temperature,
                    suffix: '°C',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: color,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.water_drop_rounded,
                        size: 11,
                        color: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${reading.humidity.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.onSurfaceVariant.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 9,
                          color: AppColors.textDim.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  StatusChipAnimated(status: reading.status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNodeDetail(BuildContext context, SensorReading r) {
    final color = AppColors.statusColor(r.status);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    r.nodeId,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  r.nodeName ?? r.nodeId,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                StatusChipAnimated(status: r.status),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _detailItem(
                  'Suhu',
                  '${r.temperature.toStringAsFixed(1)}°C',
                  color,
                ),
                const SizedBox(width: 12),
                _detailItem(
                  'Kelembapan',
                  '${r.humidity.toStringAsFixed(0)}%',
                  const Color(0xFF0EA5E9),
                ),
                if (r.rssi != null) ...[
                  const SizedBox(width: 12),
                  _detailItem('RSSI', '${r.rssi} dBm', AppColors.textDim),
                ],
              ],
            ),
            if (r.location != null) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 14,
                    color: AppColors.textDim,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    r.location!,
                    style: TextStyle(fontSize: 12, color: AppColors.textDim),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _detailItem(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: AppColors.textDim)),
        ],
      ),
    ),
  );
}

// ── Empty / Loading ───────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String? error;
  const _EmptyState({this.error});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(
      children: [
        TapScale(
          onTap: error != null
              ? () => context.read<SensorProvider>().refresh()
              : null,
          child: Container(
            width: 72,
            height: 72,
            decoration: AppColors.glassCard(radius: 20),
            child: Icon(
              error != null
                  ? Icons.wifi_off_rounded
                  : Icons.sensors_off_rounded,
              size: 32,
              color: AppColors.textDim,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          error != null ? 'Tidak dapat terhubung' : 'Menunggu data sensor',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          error ?? 'Pastikan sensor dan gateway aktif',
          style: TextStyle(fontSize: 12, color: AppColors.textDim),
          textAlign: TextAlign.center,
        ),
        if (error != null) ...[
          const SizedBox(height: 20),
          TapScale(
            onTap: () {
              HapticFeedback.lightImpact();
              context.read<SensorProvider>().refresh();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryContainer],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Coba Lagi',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
