import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../core/constants/app_colors.dart';
import '../../providers/app_provider.dart';
import '../onboarding/onboarding_screen.dart';
import '../dashboard/main_layout.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _fade  = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _scale = Tween<double>(begin: 0.7, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
    Timer(const Duration(seconds: 2), _navigate);
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    await auth.tryAutoLogin();
    if (!mounted) return;
    if (auth.loggedIn) {
      context.read<SensorProvider>().start();
      context.read<NotificationProvider>().start();
      context.read<AiProvider>().start();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainLayout()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OnboardingScreen()));
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Opacity(
            opacity: _fade.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 110, height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, color: AppColors.bgCard,
                      border: Border.all(color: AppColors.primary, width: 2),
                      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 40, spreadRadius: 8)],
                    ),
                    child: const Icon(Icons.sensors, size: 52, color: AppColors.primary),
                  ),
                  const SizedBox(height: 28),
                  const Text('SUSEMON', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 6)),
                  const SizedBox(height: 8),
                  Text('Smart Server Monitoring', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, letterSpacing: 1.5)),
                  const SizedBox(height: 48),
                  SizedBox(width: 140, child: LinearProgressIndicator(backgroundColor: AppColors.bgCardAlt, color: AppColors.primary, minHeight: 2)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
