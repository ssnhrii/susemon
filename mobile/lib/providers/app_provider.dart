import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/sensor_model.dart';
import '../services/api_service.dart';
import '../services/api_config.dart';
import '../services/websocket_service.dart';

// ── Auth Provider ─────────────────────────────────────────────────────────────

class AuthProvider extends ChangeNotifier {
  final ApiService _api;
  final _storage = const FlutterSecureStorage();
  bool _loggedIn = false;
  String? _userName;
  bool _loading = false;
  String? _error;

  AuthProvider(this._api);

  bool get loggedIn => _loggedIn;
  String? get userName => _userName;
  bool get loading => _loading;
  String? get error => _error;

  Future<bool> login(String ipAddress, String accessCode) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      // Set IP ke ApiConfig sebelum request — ini yang fix masalah IP berubah
      ApiConfig.setHost(ipAddress);

      final data = await _api.login(ipAddress, accessCode);
      _userName = data['user']?['name'] ?? ipAddress;
      _loggedIn = true;

      // Simpan token + IP ke secure storage
      await _storage.write(key: 'token', value: _api.token ?? '');
      await _storage.write(key: 'server_ip', value: ipAddress);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> tryAutoLogin() async {
    final token = await _storage.read(key: 'token');
    final ip    = await _storage.read(key: 'server_ip');

    if (token != null && token.isNotEmpty) {
      // Restore IP yang terakhir dipakai
      if (ip != null && ip.isNotEmpty) {
        ApiConfig.setHost(ip);
      }
      _api.setToken(token);
      _loggedIn = true;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _api.clearToken();
    _loggedIn = false;
    _userName = null;
    await _storage.delete(key: 'token');
    // Tidak hapus server_ip supaya field login terisi otomatis
    notifyListeners();
  }
}

// ── Sensor Provider ───────────────────────────────────────────────────────────

class SensorProvider extends ChangeNotifier {
  final ApiService _api;
  final WebSocketService _ws;

  List<SensorReading> _latest = [];
  SensorStats _stats = SensorStats.empty();
  bool _loading = false;
  bool _wsConnected = false;
  String? _error;
  Timer? _pollTimer;
  StreamSubscription? _wsSub;

  SensorProvider(this._api, this._ws);

  List<SensorReading> get latest => _latest;
  SensorStats get stats => _stats;
  bool get loading => _loading;
  bool get wsConnected => _wsConnected;
  String? get error => _error;

  String get globalStatus {
    if (_latest.any((r) => r.status == 'BERBAHAYA')) return 'BERBAHAYA';
    if (_latest.any((r) => r.status == 'WASPADA')) return 'WASPADA';
    if (_latest.isEmpty) return 'MEMUAT';
    return 'AMAN';
  }

  int get problemCount => _latest.where((r) => r.status != 'AMAN').length;

  void start() {
    _fetchLatest();
    _fetchStats();
    _ws.connect();

    // Handle bulk update (semua node sekaligus dari background task)
    _wsSub = _ws.stream.listen((readings) {
      if (readings.length > 1) {
        // Bulk update — replace semua
        _latest = readings;
      } else if (readings.length == 1) {
        // Single node update dari MQTT — update hanya node tersebut
        final updated = readings.first;
        final idx = _latest.indexWhere((r) => r.nodeId == updated.nodeId);
        if (idx >= 0) {
          _latest[idx] = updated;
        } else {
          _latest.add(updated);
        }
      }
      _wsConnected = true;
      _error = null;
      notifyListeners();
    });

    // Fallback polling setiap 5s jika WS tidak tersedia
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_wsConnected) _fetchLatest();
    });
  }

  Future<void> _fetchLatest() async {
    try {
      _latest = await _api.getLatest();
      _error = null;
    } catch (e) {
      _error = 'Gagal terhubung ke server';
    }
    notifyListeners();
  }

  Future<void> _fetchStats() async {
    try {
      _stats = await _api.getStatistics();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    await Future.wait([_fetchLatest(), _fetchStats()]);
    _loading = false;
    notifyListeners();
  }

  Future<List<SensorReading>> getHistory(String nodeId, {String period = '24h'}) async {
    return _api.getSensorHistory(nodeId, period: period, limit: 50);
  }

  void stop() {
    _pollTimer?.cancel();
    _wsSub?.cancel();
    _ws.disconnect();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

// ── Notification Provider ─────────────────────────────────────────────────────

class NotificationProvider extends ChangeNotifier {
  final ApiService _api;

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _loading = false;
  Timer? _pollTimer;

  NotificationProvider(this._api);

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get loading => _loading;

  void start() {
    fetch();
    // Poll setiap 10 detik
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => fetch());
  }

  Future<void> fetch() async {
    try {
      _notifications = await _api.getNotifications();
      _unreadCount = _notifications.where((n) => !n.isRead).length;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> markRead(int id) async {
    try {
      await _api.markAsRead(id);
      final idx = _notifications.indexWhere((n) => n.id == id);
      if (idx != -1) {
        _notifications[idx] = AppNotification(
          id: _notifications[idx].id,
          nodeId: _notifications[idx].nodeId,
          title: _notifications[idx].title,
          message: _notifications[idx].message,
          type: _notifications[idx].type,
          isRead: true,
          createdAt: _notifications[idx].createdAt,
          nodeName: _notifications[idx].nodeName,
          location: _notifications[idx].location,
        );
        _unreadCount = _notifications.where((n) => !n.isRead).length;
        notifyListeners();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

// ── AI Provider ───────────────────────────────────────────────────────────────

class AiProvider extends ChangeNotifier {
  final ApiService _api;

  List<AiAnalysis> _analysis = [];
  Map<String, AiPrediction> _predictions = {};
  bool _loading = false;
  Timer? _pollTimer;

  AiProvider(this._api);

  List<AiAnalysis> get analysis => _analysis;
  Map<String, AiPrediction> get predictions => _predictions;
  bool get loading => _loading;

  void start() {
    fetchAnalysis();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => fetchAnalysis());
  }

  Future<void> fetchAnalysis() async {
    try {
      _analysis = await _api.getAiAnalysis();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> fetchPrediction(String nodeId) async {
    try {
      final pred = await _api.getAiPrediction(nodeId);
      if (pred != null) {
        _predictions[nodeId] = pred;
        notifyListeners();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
