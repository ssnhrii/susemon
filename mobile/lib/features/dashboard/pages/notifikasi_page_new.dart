import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/app_provider.dart';
import '../../../models/sensor_model.dart';
import '../../../shared/widgets/interactive.dart';

class NotifikasiPageNew extends StatelessWidget {
  const NotifikasiPageNew({super.key});

  @override
  Widget build(BuildContext context) {
    final notif = context.watch<NotificationProvider>();
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _Header(unread: notif.unreadCount, onMarkAll: () => notif.markAllRead()),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => notif.fetch(),
                color: AppColors.primary,
                backgroundColor: AppColors.bgCard,
                child: notif.notifications.isEmpty
                    ? const _EmptyNotif()
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: notif.notifications.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                                  color: AppColors.success.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.done_all_rounded, color: AppColors.success),
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
    );
  }
}

class _Header extends StatelessWidget {
  final int unread;
  final VoidCallback onMarkAll;
  const _Header({required this.unread, required this.onMarkAll});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
    ),
    child: Row(children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.notifications_rounded, color: AppColors.primary, size: 20),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Notifikasi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
        Text(
          unread > 0 ? '$unread belum dibaca' : 'Semua sudah dibaca',
          style: TextStyle(fontSize: 11,
              color: unread > 0 ? AppColors.danger : AppColors.textSecondary),
        ),
      ]),
      const Spacer(),
      if (unread > 0)
        TextButton(
          onPressed: onMarkAll,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Tandai semua',
              style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
        ),
    ]),
  );
}

class _NotifCard extends StatelessWidget {
  final AppNotification notif;
  final VoidCallback onTap;
  const _NotifCard({required this.notif, required this.onTap});

  Color get _color => switch (notif.type) {
    'critical' => AppColors.danger,
    'warning'  => AppColors.warning,
    'success'  => AppColors.success,
    _          => AppColors.primary,
  };

  IconData get _icon => switch (notif.type) {
    'critical' => Icons.local_fire_department_rounded,
    'warning'  => Icons.warning_amber_rounded,
    'success'  => Icons.check_circle_rounded,
    _          => Icons.info_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM, HH:mm');
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: notif.isRead ? AppColors.cardBorder : _color.withValues(alpha: 0.4),
            width: notif.isRead ? 1 : 1.5,
          ),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: notif.isRead ? 0.07 : 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon, color: _color.withValues(alpha: notif.isRead ? 0.5 : 1), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(notif.title,
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: notif.isRead ? AppColors.textSecondary : Colors.white,
                    )),
              ),
              if (!notif.isRead)
                Container(width: 8, height: 8,
                    decoration: BoxDecoration(color: _color, shape: BoxShape.circle)),
            ]),
            const SizedBox(height: 4),
            Text(notif.message,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.5),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.access_time_rounded, size: 11, color: AppColors.textDim),
              const SizedBox(width: 4),
              Text(fmt.format(notif.createdAt.toLocal()),
                  style: const TextStyle(fontSize: 10, color: AppColors.textDim)),
              if (notif.nodeId != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(notif.nodeId!,
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _color)),
                ),
              ],
            ]),
          ])),
        ]),
      ),
    );
  }
}

class _EmptyNotif extends StatelessWidget {
  const _EmptyNotif();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: AppColors.bgCard, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: const Icon(Icons.notifications_none_rounded, size: 32, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 16),
      const Text('Tidak ada notifikasi',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
      const SizedBox(height: 6),
      const Text('Sistem berjalan normal',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    ]),
  );
}
