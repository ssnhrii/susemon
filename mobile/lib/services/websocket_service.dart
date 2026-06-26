import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_config.dart';
import '../models/sensor_model.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  StreamController<List<SensorReading>>? _controller;
  StreamController<Map<String, dynamic>>? _aiController;
  Timer? _reconnectTimer;
  bool _disposed = false;
  int _retrySeconds = 5;
  bool _connected = false;
  final _rng = Random();

  Stream<List<SensorReading>> get stream {
    _controller ??= StreamController<List<SensorReading>>.broadcast();
    return _controller!.stream;
  }

  Stream<Map<String, dynamic>> get aiAlertStream {
    _aiController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _aiController!.stream;
  }

  bool get isConnected => _connected;

  void connect() {
    _disposed = false;
    _retrySeconds = 5;
    _tryConnect();
  }

  void _tryConnect() {
    if (_disposed) return;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(ApiConfig.wsUrl));
      _channel!.stream.listen(
        _onMessage,
        onError: (_) {
          _connected = false;
          _scheduleReconnect();
        },
        onDone: () {
          _connected = false;
          _scheduleReconnect();
        },
        cancelOnError: false,
      );
      // Anggap connected setelah stream terbuka — akan di-reset jika error
      _connected = true;
      _retrySeconds = 5; // reset backoff on success
    } catch (_) {
      _connected = false;
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw.toString()) as Map<String, dynamic>;
      final type = msg['type'] as String? ?? '';

      // Konfirmasi koneksi dari server
      if (type == 'connection') {
        _connected = true;
        _retrySeconds = 5;
        return;
      }

      // Broadcast semua node (background task 3 detik)
      if (type == 'sensor_update' && msg.containsKey('data')) {
        final readings = (msg['data'] as List)
            .map((e) => SensorReading.fromJson(e as Map<String, dynamic>))
            .toList();
        _controller?.add(readings);
        return;
      }

      // Single node update dari MQTT listener (real-time per paket)
      if (type == 'sensor_update' && msg.containsKey('node_id')) {
        final aiMap = msg['ai'] as Map<String, dynamic>?;
        final r = SensorReading(
          id: 0,
          nodeId: msg['node_id'] ?? '',
          temperature: (msg['temperature'] as num?)?.toDouble() ?? 0,
          humidity: (msg['humidity'] as num?)?.toDouble() ?? 0,
          status: msg['status'] ?? 'AMAN',
          rssi: (msg['rssi'] as num?)?.toInt(),
          timestamp: DateTime.tryParse(msg['timestamp'] ?? '')?.toUtc() ?? DateTime.now().toUtc(),
        );
        _controller?.add([r]);
        // Kirim juga sebagai AI alert jika ada data AI
        if (aiMap != null && (aiMap['anomaly_detected'] == true || aiMap['overheating_risk'] == true)) {
          _aiController?.add({
            'type': 'ai_alert',
            'node_id': msg['node_id'],
            'risk_level': aiMap['risk_level'] ?? 'LOW',
            'confidence': aiMap['confidence'] ?? 0,
            'insights': aiMap['insights'] ?? [],
            'timestamp': msg['timestamp'],
          });
        }
        return;
      }

      // AI alert
      if (type == 'ai_alert') {
        _aiController?.add(msg);
      }
    } catch (_) {}
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    // Jitter ±20% untuk hindari thundering herd saat banyak client reconnect bersamaan
    final jitter = (_rng.nextDouble() * 0.4 - 0.2) * _retrySeconds;
    final delay = (_retrySeconds + jitter).clamp(5.0, 65.0);
    _reconnectTimer = Timer(Duration(milliseconds: (delay * 1000).toInt()), _tryConnect);
    // Exponential backoff: 5s → 10s → 20s → 40s → max 60s
    _retrySeconds = (_retrySeconds * 2).clamp(5, 60);
  }

  void disconnect() {
    _disposed = true;
    _connected = false;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _controller?.close();
    _aiController?.close();
    _controller = null;
    _aiController = null;
  }
}
