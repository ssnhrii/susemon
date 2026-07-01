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
  String _role = 'pic';
  bool _loading = false;
  String? _error;

  AuthProvider(this._api) {
    _api.onUnauthorized = _handleUnauthorized;
  }

  void _handleUnauthorized() {
    if (!_loggedIn) return;
    _loggedIn = false;
    _userName = null;
    _role     = 'pic';
    _storage.delete(key: 'token');
    _storage.delete(key: 'user_role');
    _storage.delete(key: 'user_name');
    notifyListeners();
  }

  bool get loggedIn    => _loggedIn;
  String? get userName => _userName;
  String get role      => _role;
  bool get isAdmin     => _role == 'admin';
  bool get isPic       => _role == 'pic';
  bool get isStaff     => _role == 'admin' || _role == 'pic';
  bool get loading     => _loading;
  String? get error    => _error;

  Future<bool> login(String ipAddress, String accessCode) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      ApiConfig.setHost(ipAddress);
      final data = await _api.login(ipAddress, accessCode);
      final user = data['user'] as Map<String, dynamic>? ?? {};
      _userName = user['name'] ?? ipAddress;
      _role     = user['role'] ?? 'pic';
      _loggedIn = true;
      await _storage.write(key: 'token',     value: _api.token ?? '');
      await _storage.write(key: 'server_ip', value: ipAddress);
      await _storage.write(key: 'user_role', value: _role);
      await _storage.write(key: 'user_name', value: _userName ?? '');
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
    final role  = await _storage.read(key: 'user_role');
    final name  = await _storage.read(key: 'user_name');

    if (token != null && token.isNotEmpty) {
      if (ip != null && ip.isNotEmpty) ApiConfig.setHost(ip);
      _api.setToken(token);
      _role     = role ?? 'pic';
      _userName = name;
      _loggedIn = true;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _api.logout();
    _loggedIn = false;
    _userName = null;
    _role     = 'pic';
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'user_role');
    await _storage.delete(key: 'user_name');
    notifyListeners();
  }
}

// ── Sensor Provider ───────────────────────────────────────────────────────────

class SensorProvider extends ChangeNotifier {
  final ApiService _api;
  final WebSocketService _ws;

  List<SensorReading> _latest  = [];
  SensorStats _stats           = SensorStats.empty();
  bool _loading                = false;
  bool _wsConnected            = false;
  String? _error;

  // Thresholds — sinkron dengan backend system_settings
  double _tempDanger  = 40.0;
  double _tempWarning = 30.0;
  double _humWarning  = 80.0;
  double _humDanger   = 85.0;

  // Polling interval (detik) — bisa diubah dari settings UI
  int _pollIntervalSec = 5;

  Timer? _pollTimer;
  Timer? _statsTimer;
  StreamSubscription? _wsSub;
  StreamSubscription? _aiSub;

  // Callback ke NotificationProvider untuk WS AI alert
  void Function(Map<String, dynamic>)? onAiAlert;

  SensorProvider(this._api, this._ws);

  List<SensorReading> get latest  => _latest;
  SensorStats get stats           => _stats;
  bool get loading                => _loading;
  bool get wsConnected            => _wsConnected;
  String? get error               => _error;
  double get tempThreshold        => _tempDanger;
  double get tempWarning          => _tempWarning;
  double get humWarning           => _humWarning;
  double get humDanger            => _humDanger;
  int get pollIntervalSec         => _pollIntervalSec;

  String get globalStatus {
    if (_latest.any((r) => r.status == 'BERBAHAYA')) return 'BERBAHAYA';
    if (_latest.any((r) => r.status == 'WASPADA'))   return 'WASPADA';
    if (_latest.isEmpty)                              return 'MEMUAT';
    return 'AMAN';
  }

  int get problemCount => _latest.where((r) => r.status != 'AMAN').length;
  int get nodeCount    => _latest.length;

  /// Fetch thresholds dari backend dan simpan semua 4 nilai
  Future<void> fetchThresholds() async {
    try {
      final data  = await _api.getThresholds();
      _tempDanger  = (data['temp_danger']  as num?)?.toDouble() ?? 40.0;
      _tempWarning = (data['temp_warning'] as num?)?.toDouble() ?? 30.0;
      _humWarning  = (data['hum_warning']  as num?)?.toDouble() ?? 80.0;
      _humDanger   = (data['hum_danger']   as num?)?.toDouble() ?? 85.0;
      notifyListeners();
    } catch (_) {}
  }

  /// Update batas suhu kritis — kirim semua 4 nilai ke backend
  Future<void> updateTempThreshold(double danger) async {
    try {
      _tempDanger  = danger;
      _tempWarning = 30.0;  // warning tetap 30°C
      notifyListeners();
      await _api.updateThresholds(
        _tempWarning, danger,
        humWarning: _humWarning,
        humDanger:  _humDanger,
      );
    } catch (_) {}
  }

  /// Ubah interval fallback polling — restart timer secara efektif
  void setPollInterval(int seconds) {
    if (seconds == _pollIntervalSec) return;
    _pollIntervalSec = seconds;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(Duration(seconds: seconds), (_) {
      if (!_wsConnected) _fetchLatest();
    });
    notifyListeners();
  }

  void start() {
    _fetchLatest();
    _fetchStats();
    fetchThresholds();
    _ws.connect();

    // WS sensor updates
    _wsSub = _ws.stream.listen((readings) {
      if (readings.length > 1) {
        _latest = readings;
      } else if (readings.length == 1) {
        final updated = readings.first;
        final idx = _latest.indexWhere((r) => r.nodeId == updated.nodeId);
        if (idx >= 0) {
          _latest[idx] = updated;
        } else {
          _latest.add(updated);
        }
      }
      _wsConnected = _ws.isConnected;
      _error = null;
      notifyListeners();
    });

    // WS AI alerts — forward ke callback (NotificationProvider)
    _aiSub = _ws.aiAlertStream.listen((alert) {
      onAiAlert?.call(alert);
    });

    // Fallback polling jika WS tidak tersedia
    _pollTimer = Timer.periodic(Duration(seconds: _pollIntervalSec), (_) {
      if (!_wsConnected) _fetchLatest();
    });

    // Refresh stats setiap 30 detik
    _statsTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchStats());
  }

  Future<void> _fetchLatest() async {
    try {
      _latest = await _api.getLatest();
      _error  = null;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
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

  Future<List<SensorReading>> getHistory(
    String nodeId, {
    String period = '24h',
    int limit = 100,
  }) =>
      _api.getSensorHistory(nodeId, period: period, limit: limit);

  Future<SensorStats> getNodeStats(String nodeId, {String period = '24h'}) =>
      _api.getStatistics(period: period, nodeId: nodeId);

  String getExportUrl(String nodeId, {String period = '24h'}) =>
      _api.getExportUrl(nodeId, period: period);

  void stop() {
    _pollTimer?.cancel();
    _statsTimer?.cancel();
    _wsSub?.cancel();
    _aiSub?.cancel();
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
  final bool _loading    = false;
  Timer? _pollTimer;

  NotificationProvider(this._api);

  List<AppNotification> get notifications => _notifications;
  int get unreadCount                      => _unreadCount;
  bool get loading                         => _loading;

  void start() {
    fetch();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => fetch());
  }

  Future<void> fetch() async {
    try {
      _notifications = await _api.getNotifications(limit: 50);
      _unreadCount   = _notifications.where((n) => !n.isRead).length;
    } catch (_) {}
    notifyListeners();
  }

  /// Dipanggil oleh SensorProvider.onAiAlert ketika WS AI alert masuk
  void addAiAlert(Map<String, dynamic> alert) {
    final nodeId    = alert['node_id'] as String? ?? '';
    final riskLevel = alert['risk_level'] as String? ?? 'MEDIUM';
    final insights  = (alert['insights'] as List?)?.cast<String>() ?? [];
    final type      = riskLevel == 'HIGH' ? 'critical' : 'warning';

    final notif = AppNotification(
      id:        -DateTime.now().millisecondsSinceEpoch, // ID sementara negatif
      nodeId:    nodeId,
      title:     'AI Alert - Node $nodeId',
      message:   insights.isNotEmpty ? insights.first : 'Anomali terdeteksi ($riskLevel)',
      type:      type,
      isRead:    false,
      createdAt: DateTime.now().toUtc(),
    );

    // Hindari duplikat — cek jika sudah ada alert dari node yang sama dalam 1 menit
    final cutoff = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
    final hasDuplicate = _notifications.any(
      (n) => n.nodeId == nodeId && !n.isRead && n.createdAt.isAfter(cutoff),
    );

    if (!hasDuplicate) {
      _notifications.insert(0, notif);
      _unreadCount++;
      notifyListeners();
    }
  }

  Future<void> markRead(int id) async {
    try {
      if (id > 0) await _api.markAsRead(id);
      final idx = _notifications.indexWhere((n) => n.id == id);
      if (idx != -1) {
        _notifications[idx] = _notifications[idx].copyWith(isRead: true);
        _unreadCount = _notifications.where((n) => !n.isRead).length;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await _api.markAllAsRead();
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
      _unreadCount   = 0;
      notifyListeners();
    } catch (_) {}
  }

  void stop() {
    _pollTimer?.cancel();
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
  final Map<String, AiPrediction> _predictions = {};
  Map<String, dynamic>? _summary;
  bool _loading = false;
  Timer? _pollTimer;

  AiProvider(this._api);

  List<AiAnalysis> get analysis             => _analysis;
  Map<String, AiPrediction> get predictions => _predictions;
  Map<String, dynamic>? get summary         => _summary;
  bool get loading                          => _loading;

  void start() {
    fetchAnalysis();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => fetchAnalysis());
  }

  Future<void> fetchAnalysis() async {
    _loading = true;
    notifyListeners();
    try {
      _analysis = await _api.getAiAnalysis();
      _summary  = await _api.getAiSummary();
    } catch (_) {}
    _loading = false;
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

  void stop() {
    _pollTimer?.cancel();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
