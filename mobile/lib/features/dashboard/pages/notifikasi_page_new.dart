import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/app_provider.dart';
import '../../../models/sensor_model.dart';
import '../../../shared/widgets/interactive.dart';
import '../../../shared/widgets/mesh_background.dart';

class NotifikasiPageNew extends StatelessWidget {
  const NotifikasiPageNew({super.key});

  @override
  Widget build(BuildContext context) {
    final notif = context.watch<NotificationProvider>();
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: MeshBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                unread: notif.unreadCount,
                onMarkAll: () => notif.markAllRead(),
              ),
              // Filter bar
              _FilterBar(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => notif.fetch(),
                  color: AppColors.primary,
                  backgroundColor: Colors.white,
                  child: notif.notifications.isEmpty
                      ? const _EmptyNotif()
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: notif.notifications.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final n = notif.notifications[i];
                            return FadeSlideIn(
                              delay: Duration(milliseconds: 30 * i),
                              child: Dismissible(
                                key: Key('notif_${n.id}'),
                                direction: DismissDirection.endToStart,
                                onDismissed: (_) {
                                  HapticFeedback.mediumImpact();
                                  notif.markRead(n.id);
                                },
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.done_all_rounded,
                                    color: AppColors.success,
                                  ),
                                ),
                                child: _NotifCard(
                                  notif: n,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    notif.markRead(n.id);
                                  },
                                ),
                              ),
                            );
                          },
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

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int unread;
  final VoidCallback onMarkAll;
  const _Header({required this.unread, required this.onMarkAll});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.7),
      border: Border(
        bottom: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.notifications_rounded,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notifikasi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            Text(
              unread > 0 ? '$unread belum dibaca' : 'Semua sudah dibaca',
              style: TextStyle(
                fontSize: 11,
                color: unread > 0 ? AppColors.error : AppColors.textDim,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const Spacer(),
        if (unread > 0)
          TextButton(
            onPressed: onMarkAll,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Tandai semua',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    ),
  );
}

// ── Filter Bar ────────────────────────────────────────────────────────────────

class _FilterBar extends StatefulWidget {
  @override
  State<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<_FilterBar> {
  int _selected = 0;
  final _filters = ['Semua', 'Kritis', 'Peringatan'];
  final _colors = [AppColors.primary, AppColors.error, AppColors.warning];

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.5),
      border: Border(
        bottom: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
      ),
    ),
    child: Row(
      children: [
        Text(
          'Filter',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 12),
        ..._filters.asMap().entries.map((e) {
          final selected = e.key == _selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selected = e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? _colors[e.key]
                      : Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: selected
                        ? _colors[e.key]
                        : AppColors.outlineVariant.withValues(alpha: 0.5),
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: _colors[e.key].withValues(alpha: 0.2),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  e.value,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    ),
  );
}

// ── Notif Card ────────────────────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  final AppNotification notif;
  final VoidCallback onTap;
  const _NotifCard({required this.notif, required this.onTap});

  Color get _color => switch (notif.type) {
    'critical' => AppColors.error,
    'warning' => AppColors.warning,
    'success' => AppColors.success,
    _ => AppColors.primary,
  };

  IconData get _icon => switch (notif.type) {
    'critical' => Icons.error_rounded,
    'warning' => Icons.warning_amber_rounded,
    'success' => Icons.check_circle_rounded,
    _ => Icons.info_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM, HH:mm');
    return TapScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(color: _color, width: 4),
            top: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
            right: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: notif.isRead ? 0.06 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _icon,
                  color: _color.withValues(alpha: notif.isRead ? 0.5 : 1),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notif.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: notif.isRead
                                  ? AppColors.textDim
                                  : AppColors.onSurface,
                            ),
                          ),
                        ),
                        if (!notif.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif.message,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 11,
                          color: AppColors.textDim,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          fmt.format(notif.createdAt.toLocal()),
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textDim,
                          ),
                        ),
                        if (notif.nodeId != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              notif.nodeId!,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: _color,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        // Status label
                        Text(
                          notif.type == 'critical'
                              ? 'KRITIS'
                              : notif.type == 'warning'
                              ? 'PERINGATAN'
                              : 'INFO',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: _color,
                            letterSpacing: 0.5,
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
    );
  }
}

// ── Empty ─────────────────────────────────────────────────────────────────────

class _EmptyNotif extends StatelessWidget {
  const _EmptyNotif();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: AppColors.glassCard(radius: 20),
          child: const Icon(
            Icons.notifications_none_rounded,
            size: 32,
            color: AppColors.textDim,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Tidak ada notifikasi',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Sistem berjalan normal',
          style: TextStyle(fontSize: 12, color: AppColors.textDim),
        ),
      ],
    ),
  );
}
