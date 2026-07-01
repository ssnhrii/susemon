import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/app_provider.dart';
import '../../../models/sensor_model.dart';
import 'sensor_detail_page.dart';

// ══════════════════════════════════════════════════════════════════════════════
// NotifikasiPageNew — halaman Alerts sesuai desain mockup
// ══════════════════════════════════════════════════════════════════════════════

class NotifikasiPageNew extends StatefulWidget {
  const NotifikasiPageNew({super.key});
  @override
  State<NotifikasiPageNew> createState() => _NotifikasiPageNewState();
}

class _NotifikasiPageNewState extends State<NotifikasiPageNew> {
  // Filter: 'semua', 'critical', 'warning', 'info'
  String _filter = 'semua';
  final String _dateFilter = '';
  int _visibleCount = 10;

  List<AppNotification> _applyFilter(List<AppNotification> all) {
    var list = _filter == 'semua'
        ? all
        : all.where((n) => n.type == _filter).toList();
    return list.take(_visibleCount).toList();
  }

  String _timeStr(DateTime ts) {
    final t = ts.toLocal();
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Baru saja';
    if (d.inMinutes < 60) return '${d.inMinutes} mnt lalu';
    return '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')} WIB';
  }

  @override
  Widget build(BuildContext context) {
    final notifProv = context.watch<NotificationProvider>();
    final all = notifProv.notifications;
    final filtered = _applyFilter(all);
    final newCount = notifProv.unreadCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F5FA),
      body: Column(
        children: [
          // ── AppBar ─────────────────────────────────────────────────────
          Container(
            color: Colors.white,
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
                      color: AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Notifikasi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4FA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF0F4FA),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: AppColors.textSecondary,
                        size: 18,
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
                HapticFeedback.mediumImpact();
                await notifProv.fetch();
              },
              color: AppColors.primary,
              backgroundColor: Colors.white,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  // ── Filter card ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE8EAF0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: FILTER label + Semua + Kritis
                        Row(
                          children: [
                            const Text(
                              'FILTER',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDim,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(width: 12),
                            _FilterChip(
                              label: 'Semua',
                              active: _filter == 'semua',
                              color: AppColors.primary,
                              dot: false,
                              onTap: () => setState(() {
                                _filter = 'semua';
                                _visibleCount = 10;
                              }),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Kritis',
                              active: _filter == 'critical',
                              color: AppColors.danger,
                              dot: true,
                              onTap: () => setState(() {
                                _filter = 'critical';
                                _visibleCount = 10;
                              }),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Row 2: Peringatan
                        _FilterChip(
                          label: 'Peringatan',
                          active: _filter == 'warning',
                          color: AppColors.warning,
                          dot: true,
                          onTap: () => setState(() {
                            _filter = 'warning';
                            _visibleCount = 10;
                          }),
                        ),
                        const SizedBox(height: 8),
                        // Row 3: date + filter icon
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 38,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F9FC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFE8EAF0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 13,
                                      color: AppColors.textDim,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _dateFilter.isEmpty
                                          ? 'mm/dd/yyyy'
                                          : _dateFilter,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _dateFilter.isEmpty
                                            ? AppColors.textDim
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8F9FC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFE8EAF0),
                                ),
                              ),
                              child: const Icon(
                                Icons.filter_list_rounded,
                                size: 18,
                                color: AppColors.textDim,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Daftar Alerts card ─────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE8EAF0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                          child: Row(
                            children: [
                              const Text(
                                'Daftar Alerts',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              if (newCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '$newCount BARU',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFEEF0F8)),

                        // Empty state
                        if (filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.notifications_off_outlined,
                                    size: 40,
                                    color: AppColors.textDim.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Tidak ada notifikasi',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textDim,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...filtered.map(
                            (n) => _AlertItem(
                              notif: n,
                              timeStr: _timeStr(n.createdAt),
                              onMarkRead: () => notifProv.markRead(n.id),
                              onLihatSensor: n.nodeId == null
                                  ? null
                                  : () {
                                      HapticFeedback.selectionClick();
                                      final sp = context.read<SensorProvider>();
                                      final live = sp.latest.where((r) => r.nodeId == n.nodeId).firstOrNull;
                                      final node = SensorNode(
                                        id: 0,
                                        nodeId: n.nodeId!,
                                        nodeName: n.nodeName ?? live?.nodeName ?? n.nodeId!,
                                        location: n.location ?? live?.location ?? '',
                                        isActive: true,
                                        currentTemp: live?.temperature,
                                        currentHumidity: live?.humidity,
                                        currentStatus: live?.status,
                                      );
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => SensorDetailPage(node: node),
                                        ),
                                      );
                                    },
                            ),
                          ),

                        // Muat Lebih Banyak
                        if (all.length > _visibleCount)
                          GestureDetector(
                            onTap: () => setState(() => _visibleCount += 10),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Color(0xFFEEF0F8)),
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  'MUAT LEBIH BANYAK',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                    letterSpacing: 0.5,
                                  ),
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
}

// ── _FilterChip ───────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool active, dot;
  final Color color;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.active,
    required this.color,
    required this.dot,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.selectionClick();
      onTap();
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: active ? color : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? color : const Color(0xFFD1D5DB),
          width: active ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: active ? Colors.white : color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}

// ── _AlertItem ────────────────────────────────────────────────────────────────
class _AlertItem extends StatelessWidget {
  final AppNotification notif;
  final String timeStr;
  final VoidCallback onMarkRead;
  final VoidCallback? onLihatSensor;
  const _AlertItem({
    required this.notif,
    required this.timeStr,
    required this.onMarkRead,
    this.onLihatSensor,
  });

  Color get _iconBg {
    switch (notif.type) {
      case 'critical':
        return const Color(0xFFFFEBEB);
      case 'warning':
        return const Color(0xFFFFF8EB);
      default:
        return const Color(0xFFEBF0FF);
    }
  }

  Color get _iconColor {
    switch (notif.type) {
      case 'critical':
        return AppColors.danger;
      case 'warning':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  IconData get _icon {
    switch (notif.type) {
      case 'critical':
        return Icons.error_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color get _statusColor {
    switch (notif.type) {
      case 'critical':
        return AppColors.danger;
      case 'warning':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  String get _statusLabel {
    switch (notif.type) {
      case 'critical':
        return 'STATUS: KRITIS';
      case 'warning':
        return 'STATUS: PERINGATAN';
      default:
        return 'STATUS: INFO';
    }
  }

  bool get _isCritical => notif.type == 'critical';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onMarkRead,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: const Color(0xFFEEF0F8))),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left accent bar for critical
              if (_isCritical)
                Container(
                  width: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(4),
                      bottomLeft: Radius.circular(4),
                    ),
                  ),
                ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _iconBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_icon, color: _iconColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      // Body
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title + time
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    notif.title,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  timeStr,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textDim,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              notif.message,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            // Actions
                            Row(
                              children: [
                                // Lihat Sensor
                                if (notif.nodeId != null) ...[
                                  GestureDetector(
                                    onTap: onLihatSensor,
                                    behavior: HitTestBehavior.opaque,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.open_in_new_rounded,
                                          size: 12,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'LIHAT\nSENSOR',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primary,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: const BoxDecoration(
                                      color: AppColors.textDim,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                // Status badge
                                Text(
                                  _statusLabel,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: _statusColor,
                                  ),
                                ),
                              ],
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
        ),
      ),
    );
  }
}
