import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _MainLayoutState extends State<MainLayout> with TickerProviderStateMixin {
  int _idx = 0;
  late List<AnimationController> _tabControllers;

  final _pages = const [
    DashboardPage(),
    AnalisisPage(),
    NotifikasiPageNew(),
    HistoryPageNew(),
    SettingsPageNew(),
  ];

  @override
  void initState() {
    super.initState();
    _tabControllers = List.generate(5, (i) => AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    ));
    _tabControllers[0].forward();
  }

  @override
  void dispose() {
    for (final c in _tabControllers) c.dispose();
    super.dispose();
  }

  void _onTabTap(int i) {
    if (i == _idx) return;
    HapticFeedback.selectionClick();
    _tabControllers[_idx].reverse();
    setState(() => _idx = i);
    _tabControllers[i].forward();
  }

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<NotificationProvider>().unreadCount;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: child,
        ),
        child: IndexedStack(
          key: ValueKey(_idx),
          index: _idx,
          children: _pages,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          border: Border(top: BorderSide(color: AppColors.cardBorder, width: 0.8)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _NavItem(index: 0, current: _idx, icon: Icons.dashboard_rounded, label: 'Dashboard', onTap: _onTabTap, ctrl: _tabControllers[0]),
                _NavItem(index: 1, current: _idx, icon: Icons.psychology_rounded, label: 'AI', onTap: _onTabTap, ctrl: _tabControllers[1]),
                _NavItemBadge(index: 2, current: _idx, icon: Icons.notifications_rounded, label: 'Notifikasi', badge: unread, onTap: _onTabTap, ctrl: _tabControllers[2]),
                _NavItem(index: 3, current: _idx, icon: Icons.history_rounded, label: 'Riwayat', onTap: _onTabTap, ctrl: _tabControllers[3]),
                _NavItem(index: 4, current: _idx, icon: Icons.settings_rounded, label: 'Pengaturan', onTap: _onTabTap, ctrl: _tabControllers[4]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index, current;
  final IconData icon;
  final String label;
  final Function(int) onTap;
  final AnimationController ctrl;

  const _NavItem({
    required this.index, required this.current, required this.icon,
    required this.label, required this.onTap, required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    final selected = index == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.85, end: 1.0).animate(
                CurvedAnimation(parent: ctrl, curve: Curves.easeOutBack),
              ),
              child: Icon(icon, size: 22, color: selected ? AppColors.primary : AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            child: Text(label),
          ),
        ]),
      ),
    );
  }
}

class _NavItemBadge extends StatelessWidget {
  final int index, current, badge;
  final IconData icon;
  final String label;
  final Function(int) onTap;
  final AnimationController ctrl;

  const _NavItemBadge({
    required this.index, required this.current, required this.icon,
    required this.label, required this.badge, required this.onTap, required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    final selected = index == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Stack(clipBehavior: Clip.none, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.85, end: 1.0).animate(
                  CurvedAnimation(parent: ctrl, curve: Curves.easeOutBack),
                ),
                child: Icon(icon, size: 22, color: selected ? AppColors.primary : AppColors.textSecondary),
              ),
            ),
            if (badge > 0)
              Positioned(
                top: -2, right: -2,
                child: AnimatedScale(
                  scale: badge > 0 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                    child: Center(
                      child: Text(
                        badge > 9 ? '9+' : '$badge',
                        style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            child: Text(label),
          ),
        ]),
      ),
    );
  }
}
