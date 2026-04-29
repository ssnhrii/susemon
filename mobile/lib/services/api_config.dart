/// ApiConfig — IP server bisa diubah runtime, disimpan ke storage
/// Tidak perlu rebuild app saat IP berubah
class ApiConfig {
  // IP aktif — diset saat login, default kosong
  static String _host = '';

  static String get host => _host;

  static void setHost(String ip) {
    _host = ip.trim();
  }

  static String get baseUrl => 'http://$_host:3000/api';
  static String get wsUrl   => 'ws://$_host:3000/ws';

  // Endpoints
  static const String login         = '/auth/login';
  static const String health        = '/health';
  static const String sensorNodes   = '/sensors/nodes';
  static const String sensorLatest  = '/sensors/latest';
  static const String sensorData    = '/sensors/data';   // + /:node_id
  static const String sensorStats   = '/sensors/statistics';
  static const String aiAnalysis    = '/ai/analysis';
  static const String aiPrediction  = '/ai/prediction';  // + /:node_id
  static const String aiSummary     = '/ai/summary';
  static const String notifications = '/notifications';
  static const String unreadCount   = '/notifications/unread-count';
}
