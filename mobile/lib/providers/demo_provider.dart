import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/sensor_model.dart';

/// Mode demo: semua data mock, tidak butuh backend
class DemoSensorProvider extends ChangeNotifier {
  final _rng = Random();
  Timer? _timer;

  final List<SensorReading> _latest = [
    SensorReading(id: 1, nodeId: 'A1', temperature: 28.5, humidity: 62.0,
        status: 'AMAN', timestamp: DateTime.now(), nodeName: 'Rack Server Utama', location: 'Lantai 1'),
    SensorReading(id: 2, nodeId: 'B2', temperature: 32.1, humidity: 68.0,
        status: 'WASPADA', timestamp: DateTime.now(), nodeName: 'Rack Server Backup', location: 'Lantai 1'),
    SensorReading(id: 3, nodeId: 'C3', temperature: 26.8, humidity: 58.0,
        status: 'AMAN', timestamp: DateTime.now(), nodeName: 'Rack Network', location: 'Lantai 2'),
    SensorReading(id: 4, nodeId: 'D4', temperature: 41.2, humidity: 75.0,
        status: 'BERBAHAYA', timestamp: DateTime.now(), nodeName: 'Rack Storage', location: 'Lantai 2'),
  ];

  List<SensorReading> get latest => _latest;
  bool get wsConnected => true; // demo selalu "live"

  SensorStats get stats => SensorStats(
    avgTemp: _latest.map((r) => r.temperature).reduce((a, b) => a + b) / _latest.length,
    maxTemp: _latest.map((r) => r.temperature).reduce((a, b) => a > b ? a : b),
    minTemp: _latest.map((r) => r.temperature).reduce((a, b) => a < b ? a : b),
    avgHumidity: _latest.map((r) => r.humidity).reduce((a, b) => a + b) / _latest.length,
    dangerCount: _latest.where((r) => r.status == 'BERBAHAYA').length,
    warningCount: _latest.where((r) => r.status == 'WASPADA').length,
    safeCount: _latest.where((r) => r.status == 'AMAN').length,
  );

  String get globalStatus {
    if (_latest.any((r) => r.status == 'BERBAHAYA')) return 'BERBAHAYA';
    if (_latest.any((r) => r.status == 'WASPADA')) return 'WASPADA';
    return 'AMAN';
  }

  int get problemCount => _latest.where((r) => r.status != 'AMAN').length;

  void start() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _tick());
  }

  void _tick() {
    for (int i = 0; i < _latest.length; i++) {
      final r = _latest[i];
      final newTemp = (r.temperature + (_rng.nextDouble() * 1.4 - 0.7)).clamp(20.0, 50.0);
      final newHum  = (r.humidity  + (_rng.nextDouble() * 1.0 - 0.5)).clamp(30.0, 95.0);
      final newStatus = newTemp >= 40 ? 'BERBAHAYA' : newTemp >= 35 ? 'WASPADA' : 'AMAN';
      _latest[i] = SensorReading(
        id: r.id, nodeId: r.nodeId,
        temperature: double.parse(newTemp.toStringAsFixed(1)),
        humidity: double.parse(newHum.toStringAsFixed(1)),
        status: newStatus,
        timestamp: DateTime.now(),
        nodeName: r.nodeName, location: r.location,
      );
    }
    notifyListeners();
  }

  List<SensorReading> getHistory(String nodeId) {
    final base = _latest.firstWhere((r) => r.nodeId == nodeId,
        orElse: () => _latest.first);
    return List.generate(30, (i) {
      final t = base.temperature + (_rng.nextDouble() * 6 - 3);
      final h = base.humidity + (_rng.nextDouble() * 10 - 5);
      final s = t >= 40 ? 'BERBAHAYA' : t >= 35 ? 'WASPADA' : 'AMAN';
      return SensorReading(
        id: i, nodeId: nodeId,
        temperature: double.parse(t.clamp(20, 50).toStringAsFixed(1)),
        humidity: double.parse(h.clamp(30, 95).toStringAsFixed(1)),
        status: s,
        timestamp: DateTime.now().subtract(Duration(minutes: (30 - i) * 30)),
        nodeName: base.nodeName, location: base.location,
      );
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }
}

class DemoNotificationProvider extends ChangeNotifier {
  final List<AppNotification> _notifications = [
    AppNotification(id: 1, nodeId: 'D4', title: 'Suhu Kritis - Node D4',
        message: 'Suhu mencapai 41.2°C pada Rack Storage. Tindakan segera diperlukan!',
        type: 'critical', isRead: false, createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
        nodeName: 'Rack Storage'),
    AppNotification(id: 2, nodeId: 'B2', title: 'Anomali Terdeteksi',
        message: 'Pola anomali suhu tidak normal pada Node B2. AI confidence: 87%',
        type: 'warning', isRead: false, createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        nodeName: 'Rack Server Backup'),
    AppNotification(id: 3, nodeId: 'D4', title: 'Prediksi Overheating',
        message: 'AI memprediksi overheating dalam 30 menit pada Node D4',
        type: 'warning', isRead: true, createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
        nodeName: 'Rack Storage'),
    AppNotification(id: 4, nodeId: null, title: 'Koneksi LoRa Berhasil',
        message: 'Semua node sensor terhubung dengan gateway. Signal: Excellent',
        type: 'success', isRead: true, createdAt: DateTime.now().subtract(const Duration(minutes: 30))),
  ];

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void markRead(int id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      final n = _notifications[idx];
      _notifications[idx] = AppNotification(
        id: n.id, nodeId: n.nodeId, title: n.title, message: n.message,
        type: n.type, isRead: true, createdAt: n.createdAt,
        nodeName: n.nodeName, location: n.location,
      );
      notifyListeners();
    }
  }
}

class DemoAiProvider extends ChangeNotifier {
  final List<AiAnalysis> analysis = [
    AiAnalysis(nodeId: 'D4', anomalyDetected: true, overheatingRisk: true,
        confidence: 94, currentTemp: 41.2, avgTemp: 38.5),
    AiAnalysis(nodeId: 'B2', anomalyDetected: true, overheatingRisk: false,
        confidence: 87, currentTemp: 32.1, avgTemp: 30.2),
    AiAnalysis(nodeId: 'A1', anomalyDetected: false, overheatingRisk: false,
        confidence: 91, currentTemp: 28.5, avgTemp: 27.8),
    AiAnalysis(nodeId: 'C3', anomalyDetected: false, overheatingRisk: false,
        confidence: 95, currentTemp: 26.8, avgTemp: 26.1),
  ];

  final Map<String, AiPrediction> predictions = {
    'D4': AiPrediction(nodeId: 'D4', currentTemp: 41.2, predictedTemp: 43.5,
        movingAverage: 38.5, zScore: 2.8, riskLevel: 'HIGH', confidence: 94, trend: 'increasing'),
    'B2': AiPrediction(nodeId: 'B2', currentTemp: 32.1, predictedTemp: 33.0,
        movingAverage: 30.2, zScore: 1.6, riskLevel: 'MEDIUM', confidence: 87, trend: 'increasing'),
    'A1': AiPrediction(nodeId: 'A1', currentTemp: 28.5, predictedTemp: 28.2,
        movingAverage: 27.8, zScore: 0.4, riskLevel: 'LOW', confidence: 91, trend: 'stable'),
    'C3': AiPrediction(nodeId: 'C3', currentTemp: 26.8, predictedTemp: 26.5,
        movingAverage: 26.1, zScore: 0.3, riskLevel: 'LOW', confidence: 95, trend: 'decreasing'),
  };
}
