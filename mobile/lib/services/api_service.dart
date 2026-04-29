import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import '../models/sensor_model.dart';

class ApiService {
  String? _token;
  String? get token => _token;

  void setToken(String token) => _token = token;
  void clearToken() => _token = null;
  bool get isAuthenticated => _token != null;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String ipAddress, String accessCode) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.login}'),
        headers: _headers,
        body: jsonEncode({'ip_address': ipAddress, 'access_code': accessCode}),
      ).timeout(const Duration(seconds: 15));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        _token = body['data']['token'];
        return body['data'];
      }
      throw Exception(body['message'] ?? 'Login gagal');
    } on http.ClientException catch (e) {
      throw Exception('Tidak dapat terhubung ke server: ${e.message}');
    } on Exception {
      rethrow;
    }
  }

  // ── Sensors ───────────────────────────────────────────────────────────────

  Future<List<SensorNode>> getNodes() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.sensorNodes}'),
      headers: _headers,
    ).timeout(const Duration(seconds: 10));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['success'] == true) {
      return (body['data'] as List).map((e) => SensorNode.fromJson(e)).toList();
    }
    throw Exception(body['message'] ?? 'Gagal mengambil data node');
  }

  Future<List<SensorReading>> getLatest() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.sensorLatest}'),
      headers: _headers,
    ).timeout(const Duration(seconds: 10));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['success'] == true) {
      return (body['data'] as List).map((e) => SensorReading.fromJson(e)).toList();
    }
    throw Exception(body['message'] ?? 'Gagal mengambil data terbaru');
  }

  Future<List<SensorReading>> getSensorHistory(String nodeId, {String period = '24h', int limit = 50}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.sensorData}/$nodeId')
        .replace(queryParameters: {'period': period, 'limit': '$limit'});

    final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['success'] == true) {
      return (body['data'] as List).map((e) => SensorReading.fromJson(e)).toList();
    }
    throw Exception(body['message'] ?? 'Gagal mengambil histori');
  }

  Future<SensorStats> getStatistics({String period = '24h'}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.sensorStats}')
        .replace(queryParameters: {'period': period});

    final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['success'] == true) {
      return SensorStats.fromJson(body['data']);
    }
    return SensorStats.empty();
  }

  // ── AI ────────────────────────────────────────────────────────────────────

  Future<List<AiAnalysis>> getAiAnalysis() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.aiAnalysis}'),
      headers: _headers,
    ).timeout(const Duration(seconds: 10));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['success'] == true) {
      return (body['data'] as List).map((e) => AiAnalysis.fromJson(e)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>?> getAiSummary() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.aiSummary}'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['success'] == true) return body['data'] as Map<String, dynamic>;
    } catch (_) {}
    return null;
  }

  Future<AiPrediction?> getAiPrediction(String nodeId) async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.aiPrediction}/$nodeId'),
      headers: _headers,
    ).timeout(const Duration(seconds: 10));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['success'] == true && body['data'] != null) {
      return AiPrediction.fromJson(body['data']);
    }
    return null;
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  Future<List<AppNotification>> getNotifications({bool unreadOnly = false}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.notifications}')
        .replace(queryParameters: {'unread_only': '$unreadOnly', 'limit': '30'});

    final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['success'] == true) {
      return (body['data'] as List).map((e) => AppNotification.fromJson(e)).toList();
    }
    return [];
  }

  Future<int> getUnreadCount() async {
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.unreadCount}'),
      headers: _headers,
    ).timeout(const Duration(seconds: 5));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['success'] == true) {
      return body['data']['count'] ?? 0;
    }
    return 0;
  }

  Future<void> markAsRead(int id) async {
    await http.put(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.notifications}/$id/read'),
      headers: _headers,
    ).timeout(const Duration(seconds: 5));
  }
}
