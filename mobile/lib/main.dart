import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'services/websocket_service.dart';
import 'providers/app_provider.dart';
import 'features/splash/splash_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const SusemonApp());
}

class SusemonApp extends StatelessWidget {
  const SusemonApp({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ApiService();
    final ws = WebSocketService();

    final notifProvider  = NotificationProvider(api);
    final sensorProvider = SensorProvider(api, ws);
    // Wire WS AI alerts dari SensorProvider → NotificationProvider
    sensorProvider.onAiAlert = notifProvider.addAiAlert;

    return MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => api),
        ChangeNotifierProvider(create: (_) => AuthProvider(api)),
        ChangeNotifierProvider(create: (_) => sensorProvider),
        ChangeNotifierProvider(create: (_) => notifProvider),
        ChangeNotifierProvider(create: (_) => AiProvider(api)),
      ],
      child: MaterialApp(
        title: 'SUSEMON',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
