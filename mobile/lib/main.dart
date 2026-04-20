import 'package:flutter/material.dart';
import 'features/splash/splash_screen.dart';

void main() {
  runApp(const SusemonApp());
}

class SusemonApp extends StatelessWidget {
  const SusemonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SUSEMON - Smart Server Monitoring',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF64B5F6)),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

