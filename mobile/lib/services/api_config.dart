class ApiConfig {
  // IP komputer di jaringan saat ini
  // Ganti jika IP berubah (cek dengan: ipconfig)
  static const String _host   = '10.171.144.244';
  static const String baseUrl = 'http://$_host:3000/api';
  static const String wsUrl   = 'ws://$_host:3000/ws';

  // Endpoints
  static const String login          = '/auth/login';
  static const String health         = '/health';
  static const String sensorNodes    = '/sensors/nodes';
  static const String sensorLatest   = '/sensors/latest';
  static const String sensorData     = '/sensors/data';   // + /:node_id
  static const String sensorStats    = '/sensors/statistics';
  static const String aiAnalysis     = '/ai/analysis';
  static const String aiPrediction   = '/ai/prediction';  // + /:node_id
  static const String notifications  = '/notifications';
  static const String unreadCount    = '/notifications/unread-count';
}
