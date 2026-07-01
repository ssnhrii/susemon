import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/sensor_model.dart';
import '../../../providers/app_provider.dart';
import '../../../shared/widgets/interactive.dart';
import 'sensor_detail_page.dart';
import 'nodes_page.dart';

class SensorsListPage extends StatefulWidget {
  const SensorsListPage({super.key});
  @override
  State<SensorsListPage> createState() => _SensorsListPageState();
}

class _SensorsListPageState extends State<SensorsListPage> {
  final _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sensor = context.watch<SensorProvider>();
    final readings = sensor.latest;
    final total = readings.length;
    final aktif = readings.where((r) => r.status == 'AMAN').length;
    final maint = readings.where((r) => r.status == 'BERBAHAYA').length;
    final filtered = _query.isEmpty
        ? readings
        : readings
              .where(
                (r) =>
                    r.nodeId.toLowerCase().contains(_query.toLowerCase()) ||
                    (r.nodeName ?? '').toLowerCase().contains(
                      _query.toLowerCase(),
                    ) ||
                    (r.location ?? '').toLowerCase().contains(
                      _query.toLowerCase(),
                    ),
              )
              .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FA),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NodesPage()),
          );
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          _AppBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                HapticFeedback.mediumImpact();
                await sensor.refresh();
              },
              color: AppColors.primary,
              backgroundColor: Colors.white,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                children: [
                  const SizedBox(height: 14),
                  // Breadcrumb
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.maybePop(context);
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.arrow_back_ios_rounded,
                          size: 11,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'DASHBOARD',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Title + buttons row
                  const Text(
                    'Sensor Registry',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _OutlineBtn(
                        icon: Icons.tune_rounded,
                        label: 'Filter',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _searchFocus.requestFocus();
                        },
                      ),
                      const SizedBox(width: 10),
                      _FilledBtn(
                        icon: Icons.add_rounded,
                        label: 'Add Sensor',
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const NodesPage()),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ── 4 stat boxes 2×2 ──
                  Row(
                    children: [
                      _StatBox(
                        badge: total > 0
                            ? '+${(total * 0.1).ceil()} New'
                            : '0 New',
                        badgeColor: AppColors.primary,
                        icon: Icons.sensors_rounded,
                        iconColor: AppColors.primary,
                        value: '$total',
                        label: 'TOTAL REGISTRY',
                        valueColor: AppColors.textPrimary,
                      ),
                      const SizedBox(width: 12),
                      _StatBox(
                        badge: 'Online',
                        badgeColor: AppColors.success,
                        icon: Icons.bolt_rounded,
                        iconColor: AppColors.success,
                        value: '$aktif',
                        label: 'ACTIVE NODES',
                        valueColor: AppColors.textPrimary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatBox(
                        badge: maint > 0 ? 'Urgent' : 'OK',
                        badgeColor: maint > 0
                            ? AppColors.danger
                            : AppColors.success,
                        icon: Icons.error_outline_rounded,
                        iconColor: maint > 0
                            ? AppColors.danger
                            : AppColors.success,
                        value: maint.toString().padLeft(2, '0'),
                        label: 'MAINTENANCE',
                        valueColor: maint > 0
                            ? AppColors.danger
                            : AppColors.textPrimary,
                      ),
                      const SizedBox(width: 12),
                      _StatBox(
                        badge: '',
                        badgeColor: Colors.transparent,
                        icon: Icons.signal_cellular_alt_rounded,
                        iconColor: const Color(0xFF6366F1),
                        value: readings.isEmpty
                            ? '--'
                            : '${(aktif / (total == 0 ? 1 : total) * 100).toStringAsFixed(0)}%',
                        label: 'AVG. SIGNAL',
                        valueColor: AppColors.textPrimary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // ── Node Inventory card ──
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
                        // Header Node Inventory + LIVE badge
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                          child: Row(
                            children: [
                              const Text(
                                'Node Inventory',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: AppColors.success,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'LIVE',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Search box
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F6FA),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFE8EAF0),
                              ),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 10),
                                Icon(
                                  Icons.search_rounded,
                                  size: 16,
                                  color: AppColors.textDim.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _searchCtrl,
                                    focusNode: _searchFocus,
                                    onChanged: (v) =>
                                        setState(() => _query = v),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textPrimary,
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'Search Node ID or Site...',
                                      hintStyle: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textDim,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
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
                                  'NODE\nIDENTIFICATION',
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
                                  'DESCRIPTION',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textDim,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'SITE\nLOCATION',
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
                        const Divider(height: 1, color: Color(0xFFEEF0F8)),
                        // Rows
                        if (filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                sensor.loading
                                    ? 'Memuat...'
                                    : 'Tidak ada sensor ditemukan',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textDim,
                                ),
                              ),
                            ),
                          )
                        else
                          ...filtered.asMap().entries.map((entry) {
                            final i = entry.key;
                            final r = entry.value;
                            final node = SensorNode(
                              id: 0,
                              nodeId: r.nodeId,
                              nodeName: r.nodeName ?? r.nodeId,
                              location: r.location ?? '',
                              isActive: r.status == 'AMAN',
                              currentTemp: r.temperature,
                              currentHumidity: r.humidity,
                              currentStatus: r.status,
                              lastSeen: r.timestamp,
                            );
                            return FadeSlideIn(
                              delay: Duration(milliseconds: 30 * i),
                              child: _NodeRow(
                                reading: r,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          SensorDetailPage(node: node),
                                    ),
                                  );
                                },
                              ),
                            );
                          }),
                        // Pagination footer
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Color(0xFFEEF0F8)),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Monitoring ${filtered.length} of $total active nodes',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textDim,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.chevron_left_rounded,
                                    size: 18,
                                    color: AppColors.textDim,
                                  ),
                                  _PageBtn(label: '1', active: true),
                                  _PageBtn(label: '2', active: false),
                                  _PageBtn(label: '3', active: false),
                                  const Text(
                                    '...',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textDim,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: AppColors.textDim,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Footer
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'SERVERLY INTELLIGENCE • SECURE NODE',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.textDim.withValues(alpha: 0.6),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'SYSTEM ACTIVE',
                              style: TextStyle(
                                fontSize: 9,
                                color: AppColors.textDim.withValues(alpha: 0.7),
                                letterSpacing: 0.8,
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
    );
  }
}

// ── _AppBar ───────────────────────────────────────────────────────────────────
class _AppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            const Icon(Icons.sensors_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            const Text(
              'Sensor Inventory',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFF1D4ED8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── _StatBox ──────────────────────────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  final String badge, value, label;
  final Color badgeColor, iconColor, valueColor;
  final IconData icon;
  const _StatBox({
    required this.badge,
    required this.badgeColor,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.valueColor,
  });
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
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
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: valueColor,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.textDim,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    ),
  );
}

// ── _NodeRow ──────────────────────────────────────────────────────────────────
class _NodeRow extends StatelessWidget {
  final SensorReading reading;
  final VoidCallback onTap;
  const _NodeRow({required this.reading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isCrit = reading.status == 'BERBAHAYA';
    final isWarn = reading.status == 'WASPADA';
    final idColor = isCrit
        ? AppColors.danger
        : isWarn
        ? AppColors.warning
        : AppColors.primary;
    final subLabel = isCrit
        ? 'LEGACY DEVICE'
        : isWarn
        ? 'HARDWARE REV 1.9'
        : 'HARDWARE REV 2.1';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFEEF0F8))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Node ID
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
                      color: idColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subLabel,
                    style: TextStyle(
                      fontSize: 9,
                      color: AppColors.textDim.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            // Description
            Expanded(
              flex: 3,
              child: Text(
                reading.nodeName ?? reading.nodeId,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Location
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reading.location?.isNotEmpty == true
                        ? reading.location!
                        : 'Server Room',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'RACK 1 • ZONE B',
                    style: TextStyle(
                      fontSize: 8,
                      color: AppColors.textDim.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────
class _OutlineBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _OutlineBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}

class _FilledBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _FilledBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    ),
  );
}

class _PageBtn extends StatelessWidget {
  final String label;
  final bool active;
  const _PageBtn({required this.label, required this.active});
  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    margin: const EdgeInsets.symmetric(horizontal: 3),
    decoration: BoxDecoration(
      color: active ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Center(
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: active ? Colors.white : AppColors.textDim,
        ),
      ),
    ),
  );
}
