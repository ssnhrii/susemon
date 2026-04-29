import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_config.dart';
import '../models/sensor_model.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  StreamController<List<SensorReading>>? _controller;
  StreamController<Map<String, dynamic>>? _aiController;
  Timer? _reconnectTimer;
  bool _disposed = false;
  int _retrySeconds = 5;  // exponential backoff

  Stream<List<SensorReading>> get stream {
    _controller ??= StreamController<List<SensorReading>>.broadcast();
    return _controller!.stream;
  }

  Stream<Map<String, dynamic>> get aiAlertStream {
    _aiController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _aiController!.stream;
  }

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
        onError: (_) => _scheduleReconnect(),
        onDone: () => _scheduleReconnect(),
        cancelOnError: false,
      );
      _retrySeconds = 5; // reset on success
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw.toString()) as Map<String, dynamic>;
      final type = msg['type'] as String? ?? '';

      // Broadcast semua node (background task 3 detik)
      if (type == 'sensor_update' && msg.containsKey('data')) {
        final readings = (msg['data'] as List)
            .map((e) => SensorReading.fromJson(e as Map<String, dynamic>))
            .toList();
        _controller?.add(readings);
        return;
      }

      // Single node update dari MQTT listener
      if (type == 'sensor_update' && msg.containsKey('node_id')) {
        final r = SensorReading(
          id: 0,
          nodeId: msg['node_id'] ?? '',
          temperature: (msg['temperature'] as num?)?.toDouble() ?? 0,
          humidity: (msg['humidity'] as num?)?.toDouble() ?? 0,
          status: msg['status'] ?? 'AMAN',
          timestamp: DateTime.tryParse(msg['timestamp'] ?? '') ?? DateTime.now(),
        );
        _controller?.add([r]);
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
    _reconnectTimer = Timer(Duration(seconds: _retrySeconds), _tryConnect);
    // Exponential backoff: 5s → 10s → 20s → 40s → max 60s
    if (_retrySeconds < 60) _retrySeconds = (_retrySeconds * 2).clamp(5, 60);
  }

  void disconnect() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _controller?.close();
    _aiController?.close();
    _controller = null;
    _aiController = null;
  }
}
