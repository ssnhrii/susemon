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
    _tabControllers = List.generate(
      5,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
      ),
    );
    _tabControllers[0].forward();
  }

  @override
  void dispose() {
    for (final c in _tabControllers) {
      c.dispose();
    }
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
      backgroundColor: const Color(0xFFF0F7FF),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: IndexedStack(key: ValueKey(_idx), index: _idx, children: _pages),
      ),
      bottomNavigationBar: _BottomNav(
        current: _idx,
        unread: unread,
        onTap: _onTabTap,
        controllers: _tabControllers,
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int current;
  final int unread;
  final Function(int) onTap;
  final List<AnimationController> controllers;

  const _BottomNav({
    required this.current,
    required this.unread,
    required this.onTap,
    required this.controllers,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                index: 0,
                current: current,
                icon: Icons.dashboard_rounded,
                label: 'Dashboard',
                onTap: onTap,
                ctrl: controllers[0],
              ),
              _NavItem(
                index: 1,
                current: current,
                icon: Icons.psychology_rounded,
                label: 'AI',
                onTap: onTap,
                ctrl: controllers[1],
              ),
              _NavItemBadge(
                index: 2,
                current: current,
                icon: Icons.notifications_rounded,
                label: 'Notifikasi',
                badge: unread,
                onTap: onTap,
                ctrl: controllers[2],
              ),
              _NavItem(
                index: 3,
                current: current,
                icon: Icons.bar_chart_rounded,
                label: 'Laporan',
                onTap: onTap,
                ctrl: controllers[3],
              ),
              _NavItem(
                index: 4,
                current: current,
                icon: Icons.settings_rounded,
                label: 'Pengaturan',
                onTap: onTap,
                ctrl: controllers[4],
              ),
            ],
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
    required this.index,
    required this.current,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    final selected = index == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.85, end: 1.0).animate(
                  CurvedAnimation(parent: ctrl, curve: Curves.easeOutBack),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: selected ? AppColors.primary : AppColors.textDim,
                ),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.textDim,
                letterSpacing: 0.3,
              ),
              child: Text(label),
            ),
          ],
        ),
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
    required this.index,
    required this.current,
    required this.icon,
    required this.label,
    required this.badge,
    required this.onTap,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    final selected = index == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.85, end: 1.0).animate(
                      CurvedAnimation(parent: ctrl, curve: Curves.easeOutBack),
                    ),
                    child: Icon(
                      icon,
                      size: 22,
                      color: selected ? AppColors.primary : AppColors.textDim,
                    ),
                  ),
                ),
                if (badge > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: AnimatedScale(
                      scale: badge > 0 ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutBack,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            badge > 9 ? '9+' : '$badge',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.textDim,
                letterSpacing: 0.3,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
