import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import '../models/sensor_model.dart';
import '../models/user_model.dart';

class ApiService {
  String? _token;
  String? get token => _token;
  void setToken(String t) => _token = t;
  void clearToken() => _token = null;
  bool get isAuthenticated => _token != null;

  /// Callback dipanggil saat 401 — untuk trigger logout dari provider
  VoidCallback? onUnauthorized;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  /// Parse response — auto-throw on 401/403/4xx/5xx
  Map<String, dynamic> _parse(http.Response res) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Response tidak valid dari server (${res.statusCode})');
    }
    if (res.statusCode == 401) {
      clearToken();
      onUnauthorized?.call();
      throw Exception('Sesi habis, silakan login kembali');
    }
    if (res.statusCode == 403) {
      throw Exception('Akses ditolak');
    }
    if (res.statusCode == 429) {
      throw Exception('Terlalu banyak request, coba lagi nanti');
    }
    if (res.statusCode >= 400) {
      throw Exception(body['detail'] ?? body['message'] ?? 'Terjadi kesalahan (${res.statusCode})');
    }
    return body;
  }

  Future<T> _get<T>(String url, T Function(dynamic) parser) async {
    try {
      final res = await http.get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 15));
      final body = _parse(res);
      if (body['success'] == true) return parser(body['data']);
      throw Exception(body['message'] ?? 'Gagal mengambil data');
    } on SocketException {
      throw Exception('Tidak dapat terhubung ke server. Periksa koneksi jaringan.');
    } on http.ClientException catch (e) {
      throw Exception('Koneksi gagal: ${e.message}');
    }
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String ipAddress, String accessCode) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.login}'),
        headers: _headers,
        body: jsonEncode({'ip_address': ipAddress, 'access_code': accessCode}),
      ).timeout(const Duration(seconds: 15));
      final body = _parse(res);
      if (body['success'] == true) {
        _token = body['data']['token'];
        return body['data'] as Map<String, dynamic>;
      }
      throw Exception(body['message'] ?? 'Login gagal');
    } on SocketException {
      throw Exception('Tidak dapat terhubung ke server. Periksa IP dan koneksi jaringan.');
    } on http.ClientException catch (e) {
      throw Exception('Koneksi gagal: ${e.message}');
    }
  }

  Future<void> logout() async {
    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.logout}'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
    clearToken();
  }

  Future<Map<String, dynamic>?> getMe() async {
    try {
      return await _get('${ApiConfig.baseUrl}${ApiConfig.userMe}',
          (d) => d as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // ── Sensors ───────────────────────────────────────────────────────────────

  Future<List<SensorNode>> getNodes() async =>
      _get('${ApiConfig.baseUrl}${ApiConfig.sensorNodes}',
          (d) => (d as List).map((e) => SensorNode.fromJson(e)).toList());

  Future<List<SensorReading>> getLatest() async =>
      _get('${ApiConfig.baseUrl}${ApiConfig.sensorLatest}',
          (d) => (d as List).map((e) => SensorReading.fromJson(e)).toList());

  Future<Map<String, dynamic>> getThresholds() async {
    return _get('${ApiConfig.baseUrl}/sensors/thresholds',
        (d) => d as Map<String, dynamic>);
  }

  Future<void> updateThresholds(double tempWarning, double tempDanger, {
    double humWarning = 80.0,
    double humDanger = 85.0,
  }) async {
    final res = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/sensors/thresholds'),
      headers: _headers,
      body: jsonEncode({
        'temp_warning': tempWarning,
        'temp_danger': tempDanger,
        'hum_warning': humWarning,
        'hum_danger': humDanger,
      }),
    ).timeout(const Duration(seconds: 10));
    _parse(res);
  }

  Future<List<SensorReading>> getSensorHistory(
    String nodeId, {
    String period = '24h',
    int limit = 100,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.sensorData}/$nodeId')
        .replace(queryParameters: {'period': period, 'limit': '$limit'});
    return _get(uri.toString(),
        (d) => (d as List).map((e) => SensorReading.fromJson(e)).toList());
  }

  Future<SensorStats> getStatistics({String period = '24h', String? nodeId}) async {
    final params = <String, String>{'period': period};
    if (nodeId != null) params['node_id'] = nodeId;
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.sensorStats}')
        .replace(queryParameters: params);
    try {
      return await _get(uri.toString(), (d) => SensorStats.fromJson(d));
    } catch (_) {
      return SensorStats.empty();
    }
  }

  /// Returns download URL for CSV export
  String getExportUrl(String nodeId, {String period = '24h'}) {
    return '${ApiConfig.baseUrl}${ApiConfig.sensorExport}/$nodeId?period=$period';
  }

  // ── AI ────────────────────────────────────────────────────────────────────

  Future<List<AiAnalysis>> getAiAnalysis() async {
    try {
      return await _get('${ApiConfig.baseUrl}${ApiConfig.aiAnalysis}',
          (d) => (d as List).map((e) => AiAnalysis.fromJson(e)).toList());
    } catch (_) {
      return [];
    }
  }

  Future<AiPrediction?> getAiPrediction(String nodeId) async {
    try {
      return await _get(
          '${ApiConfig.baseUrl}${ApiConfig.aiPrediction}/$nodeId',
          (d) => AiPrediction.fromJson(d as Map<String, dynamic>));
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getAiSummary() async {
    try {
      return await _get('${ApiConfig.baseUrl}${ApiConfig.aiSummary}',
          (d) => d as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  Future<List<AppNotification>> getNotifications({
    bool unreadOnly = false,
    int limit = 30,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.notifications}')
        .replace(queryParameters: {
      'unread_only': '$unreadOnly',
      'limit': '$limit',
    });
    try {
      return await _get(uri.toString(),
          (d) => (d as List).map((e) => AppNotification.fromJson(e)).toList());
    } catch (_) {
      return [];
    }
  }

  Future<int> getUnreadCount() async {
    try {
      return await _get(
          '${ApiConfig.baseUrl}${ApiConfig.unreadCount}',
          (d) => (d as Map<String, dynamic>)['count'] as int? ?? 0);
    } catch (_) {
      return 0;
    }
  }

  Future<void> markAsRead(int id) async {
    final res = await http.put(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.notifications}/$id/read'),
      headers: _headers,
    ).timeout(const Duration(seconds: 5));
    _parse(res);
  }

  Future<void> markAllAsRead() async {
    final res = await http.put(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.notifications}/read-all'),
      headers: _headers,
    ).timeout(const Duration(seconds: 5));
    _parse(res);
  }

  // ── Users (admin only) ────────────────────────────────────────────────────

  Future<List<AppUser>> getUsers() async =>
      _get('${ApiConfig.baseUrl}${ApiConfig.users}',
          (d) => (d as List).map((e) => AppUser.fromJson(e)).toList());

  Future<void> createUser(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.users}'),
      headers: _headers,
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 10));
    _parse(res);
  }

  Future<void> updateUser(int id, Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.users}/$id'),
      headers: _headers,
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 10));
    _parse(res);
  }

  Future<void> deleteUser(int id) async {
    final res = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.users}/$id'),
      headers: _headers,
    ).timeout(const Duration(seconds: 10));
    _parse(res);
  }

  // ── Sensor Nodes (admin only) ─────────────────────────────────────────────

  Future<void> createNode(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.sensorNodes}'),
      headers: _headers,
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 10));
    _parse(res);
  }

  Future<void> updateNode(String nodeId, Map<String, dynamic> data) async {
    final res = await http.put(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.sensorNodes}/$nodeId'),
      headers: _headers,
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 10));
    _parse(res);
  }

  Future<void> deleteNode(String nodeId) async {
    final res = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.sensorNodes}/$nodeId'),
      headers: _headers,
    ).timeout(const Duration(seconds: 10));
    _parse(res);
  }

  // ── Health ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getHealth() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.health}'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
