import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/app_navbar.dart';
import 'pages/dashboard_page.dart';
import 'pages/analisis_page.dart';
import 'pages/history_page_new.dart';
import 'pages/notifikasi_page_new.dart';
import 'pages/settings_page_new.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const DashboardPage(),
    const AnalisPage(),
    const HistoryPageNew(),
  ];

  final List<String> _titles = [
    'Real-time Monitoring',
    'AI Analysis & Prediction',
    'Data History & Trends',
  ];

  void _onNavItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onNotificationTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotifikasiPageNew()),
    );
  }

  void _onSettingsTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPageNew()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: Column(
          children: [
            // Header
            AppHeader(
              title: _titles[_selectedIndex],
              onNotificationTap: _onNotificationTap,
              onSettingsTap: _onSettingsTap,
              notificationCount: 3,
            ),
            
            // Navbar
            AppNavbar(
              selectedIndex: _selectedIndex,
              onItemSelected: _onNavItemSelected,
            ),
            
            // Main Content
            Expanded(
              child: _pages[_selectedIndex],
            ),
          ],
        ),
      ),
    );
  }
}
