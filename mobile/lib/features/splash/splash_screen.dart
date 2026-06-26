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
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _scale = Tween<double>(
      begin: 0.7,
      end: 1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainLayout()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 2.5,
            colors: [Color(0xFFEBF8FF), Color(0xFFF0F7FF)],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Opacity(
              opacity: _fade.value,
              child: Transform.scale(
                scale: _scale.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.8),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            blurRadius: 40,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.sensors,
                        size: 46,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'SUSEMON',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Infrastructure Monitoring System',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: 120,
                      child: LinearProgressIndicator(
                        backgroundColor: AppColors.surfaceContainerHigh,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.primary,
                        ),
                        minHeight: 2,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Memuat sistem...',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textDim,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
