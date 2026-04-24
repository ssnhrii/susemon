import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/app_provider.dart';
import '../../../models/sensor_model.dart';

class NotifikasiPageNew extends StatelessWidget {
  const NotifikasiPageNew({super.key});

  @override
  Widget build(BuildContext context) {
    final notif = context.watch<NotificationProvider>();
    final fmt   = DateFormat('dd/MM HH:mm');

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(notif.unreadCount),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => notif.fetch(),
                color: AppColors.primary,
                backgroundColor: AppColors.bgCard,
                child: notif.notifications.isEmpty
                    ? const _EmptyNotif()
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: notif.notifications.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _NotifCard(
                          notif: notif.notifications[i],
                          fmt: fmt,
                          onTap: () => notif.markRead(notif.notifications[i].id),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int unread) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    color: AppColors.bgCard,
    child: Row(
      children: [
        const Icon(Icons.notifications_rounded, color: AppColors.primary, size: 22),
        const SizedBox(width: 10),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Notifikasi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
          Text('Peringatan & Alert Sistem', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ]),
        const Spacer(),
        if (unread > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.danger.withOpacity(0.3)),
            ),
            child: Text('$unread Belum Dibaca',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.danger)),
          ),
      ],
    ),
  );
}

class _NotifCard extends StatelessWidget {
  final AppNotification notif;
  final DateFormat fmt;
  final VoidCallback onTap;
  const _NotifCard({required this.notif, required this.fmt, required this.onTap});

  Color get _color => switch (notif.type) {
    'critical' => AppColors.danger,
    'warning'  => AppColors.warning,
    'success'  => AppColors.success,
    _          => AppColors.primary,
  };

  IconData get _icon => switch (notif.type) {
    'critical' => Icons.thermostat,
    'warning'  => Icons.show_chart,
    'success'  => Icons.check_circle,
    _          => Icons.info_outline,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notif.isRead ? AppColors.bgCard : AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: notif.isRead ? AppColors.cardBorder : _color.withOpacity(0.4),
            width: notif.isRead ? 1 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: _color.withOpacity(notif.isRead ? 0.08 : 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon, color: _color.withOpacity(notif.isRead ? 0.5 : 1), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.access_time, size: 11, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(fmt.format(notif.createdAt),
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  if (notif.nodeId != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _color.withOpacity(0.15), borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(notif.nodeId!,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _color)),
                    ),
                  ],
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNotif extends StatelessWidget {
  const _EmptyNotif();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.notifications_none, size: 56, color: AppColors.textSecondary),
        SizedBox(height: 12),
        Text('Tidak ada notifikasi', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ],
    ),
  );
}
