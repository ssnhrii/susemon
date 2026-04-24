import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/app_provider.dart';
import '../../../models/sensor_model.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sensor      = context.watch<SensorProvider>();
    final notifUnread = context.watch<NotificationProvider>().unreadCount;
    final status      = sensor.globalStatus;
    final sc          = AppColors.statusColor(status);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(status: status, sc: sc, unread: notifUnread,
                wsConnected: sensor.wsConnected, nodeCount: sensor.latest.length),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => sensor.refresh(),
                color: AppColors.primary,
                backgroundColor: AppColors.bgCard,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _StatusBanner(status: status, sc: sc, problemCount: sensor.problemCount),
                      const SizedBox(height: 14),
                      _StatsRow(stats: sensor.stats, latest: sensor.latest),
                      const SizedBox(height: 14),
                      if (sensor.latest.isNotEmpty) _NodeGrid(readings: sensor.latest),
                      if (sensor.latest.isEmpty && !sensor.loading) _EmptyState(error: sensor.error),
                      if (sensor.loading && sensor.latest.isEmpty) const _LoadingState(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String status; final Color sc; final int unread; final bool wsConnected; final int nodeCount;
  const _TopBar({required this.status, required this.sc, required this.unread, required this.wsConnected, required this.nodeCount});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    color: AppColors.bgCard,
    child: Row(children: [
      Container(width: 36, height: 36,
          decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.bgCardAlt,
              border: Border.all(color: AppColors.primary.withOpacity(0.4))),
          child: const Icon(Icons.sensors, size: 18, color: AppColors.primary)),
      const SizedBox(width: 10),
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SUSEMON', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 2)),
        Text('Server Room Monitor', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ]),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: (wsConnected ? AppColors.success : AppColors.warning).withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: (wsConnected ? AppColors.success : AppColors.warning).withOpacity(0.3)),
        ),
        child: Row(children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(
              color: wsConnected ? AppColors.success : AppColors.warning, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(wsConnected ? 'LIVE · $nodeCount Node' : 'POLLING',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: wsConnected ? AppColors.success : AppColors.warning)),
        ]),
      ),
    ]),
  );
}

class _StatusBanner extends StatelessWidget {
  final String status; final Color sc; final int problemCount;
  const _StatusBanner({required this.status, required this.sc, required this.problemCount});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(14),
        border: Border.all(color: sc.withOpacity(0.4))),
    child: Row(children: [
      Icon(status == 'AMAN' ? Icons.check_circle : Icons.warning_rounded, color: sc, size: 22),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('STATUS: $status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: sc)),
        Text(problemCount > 0 ? '$problemCount sensor bermasalah' : 'Semua sensor normal',
            style: TextStyle(fontSize: 11, color: sc.withOpacity(0.8))),
      ]),
      const Spacer(),
      Container(width: 10, height: 10, decoration: BoxDecoration(
          color: sc, shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: sc, blurRadius: 8, spreadRadius: 2)])),
    ]),
  );
}

class _StatsRow extends StatelessWidget {
  final SensorStats stats; final List<SensorReading> latest;
  const _StatsRow({required this.stats, required this.latest});

  @override
  Widget build(BuildContext context) {
    final prob = latest.where((r) => r.status != 'AMAN').length;
    return Row(children: [
      _Tile('Rata-rata', '${stats.avgTemp.toStringAsFixed(1)}°C', Icons.thermostat, AppColors.primary),
      const SizedBox(width: 10),
      _Tile('Tertinggi', '${stats.maxTemp.toStringAsFixed(1)}°C', Icons.arrow_upward, AppColors.danger),
      const SizedBox(width: 10),
      _Tile('Masalah', '$prob Node', Icons.warning_rounded, AppColors.warning),
    ]);
  }
}

class _Tile extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  const _Tile(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ]),
    ),
  );
}

class _NodeGrid extends StatelessWidget {
  final List<SensorReading> readings;
  const _NodeGrid({required this.readings});

  @override
  Widget build(BuildContext context) {
    final sorted = [...readings]..sort((a, b) {
        const o = {'BERBAHAYA': 0, 'WASPADA': 1, 'AMAN': 2};
        return (o[a.status] ?? 3).compareTo(o[b.status] ?? 3);
      });
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.only(bottom: 12),
          child: Text('Node Sensor', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
      GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.05),
        itemCount: sorted.length,
        itemBuilder: (_, i) => _NodeCard(reading: sorted[i]),
      ),
    ]);
  }
}

class _NodeCard extends StatelessWidget {
  final SensorReading reading;
  const _NodeCard({required this.reading});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.statusColor(reading.status);
    return Container(
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5)),
      child: Stack(children: [
        Positioned(top: 0, left: 0, child: Container(width: 60, height: 60,
            decoration: BoxDecoration(gradient: RadialGradient(
                colors: [color.withOpacity(0.12), Colors.transparent])))),
        Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(reading.nodeId, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color))),
            const Spacer(),
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: color, blurRadius: 6, spreadRadius: 1)])),
          ]),
          const SizedBox(height: 6),
          Text(reading.nodeName ?? reading.nodeId,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
          const Spacer(),
          Text('${reading.temperature.toStringAsFixed(1)}°C',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.water_drop, size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text('${reading.humidity.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(reading.status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color))),
          ]),
        ])),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String? error;
  const _EmptyState({this.error});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(children: [
      Icon(error != null ? Icons.wifi_off : Icons.sensors_off, size: 48, color: AppColors.textSecondary),
      const SizedBox(height: 12),
      Text(error ?? 'Menunggu data dari sensor...', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
      if (error != null) ...[
        const SizedBox(height: 16),
        TextButton(onPressed: () => context.read<SensorProvider>().refresh(),
            child: const Text('Coba Lagi', style: TextStyle(color: AppColors.primary))),
      ],
    ]),
  );
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(32),
    child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
  );
}
