import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'services/websocket_service.dart';
import 'providers/app_provider.dart';
import 'features/splash/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const SusemonApp());
}

class SusemonApp extends StatelessWidget {
  const SusemonApp({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ApiService();
    final ws  = WebSocketService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(api)),
        ChangeNotifierProvider(create: (_) => SensorProvider(api, ws)),
        ChangeNotifierProvider(create: (_) => NotificationProvider(api)),
        ChangeNotifierProvider(create: (_) => AiProvider(api)),
      ],
      child: MaterialApp(
        title: 'SUSEMON',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0A0E1A),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00B4FF),
            surface: Color(0xFF111827),
          ),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
