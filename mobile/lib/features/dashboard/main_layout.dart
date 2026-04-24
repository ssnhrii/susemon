import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/app_provider.dart';
import 'pages/dashboard_page.dart';
import 'pages/analisis_page.dart';
import 'pages/notifikasi_page_new.dart';
import 'pages/history_page_new.dart';
import 'pages/settings_page_new.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});
  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _idx = 0;

  final _pages = const [
    DashboardPage(),
    AnalisisPage(),
    NotifikasiPageNew(),
    HistoryPageNew(),
    SettingsPageNew(),
  ];

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<NotificationProvider>().unreadCount;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: IndexedStack(index: _idx, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          border: Border(top: BorderSide(color: AppColors.cardBorder)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _navItem(0, Icons.dashboard_rounded, 'Dashboard'),
                _navItem(1, Icons.psychology_rounded, 'AI'),
                _navItemBadge(2, Icons.notifications_rounded, 'Notifikasi', unread),
                _navItem(3, Icons.history_rounded, 'Riwayat'),
                _navItem(4, Icons.settings_rounded, 'Pengaturan'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int i, IconData icon, String label) {
    final selected = _idx == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _idx = i),
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: selected ? AppColors.primary : AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(
            fontSize: 10,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          )),
        ]),
      ),
    );
  }

  Widget _navItemBadge(int i, IconData icon, String label, int badge) {
    final selected = _idx == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _idx = i),
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: selected ? AppColors.primary : AppColors.textSecondary),
              ),
              if (badge > 0)
                Positioned(
                  top: -2, right: -2,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                    child: Center(
                      child: Text('$badge', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(
            fontSize: 10,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          )),
        ]),
      ),
    );
  }
}
