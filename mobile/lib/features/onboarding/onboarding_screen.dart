import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  final _pages = const [
    _OnboardPage(
      icon: Icons.sensors,
      title: 'Monitoring Real-time',
      desc: 'Pantau suhu & kelembapan ruang server secara real-time melalui node sensor LoRa.',
    ),
    _OnboardPage(
      icon: Icons.psychology,
      title: 'Deteksi Anomali AI',
      desc: 'Sistem AI mendeteksi pola anomali suhu sebelum mencapai titik kritis.',
    ),
    _OnboardPage(
      icon: Icons.notifications_active,
      title: 'Notifikasi Instan',
      desc: 'Terima peringatan langsung saat kondisi server memasuki status waspada atau berbahaya.',
    ),
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _pages[i],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _page == i ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _page == i ? AppColors.primary : AppColors.bgCardAlt,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text(
                        _page == _pages.length - 1 ? 'Mulai' : 'Lanjut',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  if (_page < _pages.length - 1) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pushReplacement(
                          context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                      child: Text('Lewati', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _OnboardPage({required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.bgCard,
              border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 40, spreadRadius: 4),
              ],
            ),
            child: Icon(icon, size: 56, color: AppColors.primary),
          ),
          const SizedBox(height: 40),
          Text(title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(desc,
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.6),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
