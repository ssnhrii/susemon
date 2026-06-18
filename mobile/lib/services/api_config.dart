/// ApiConfig — IP server bisa diubah runtime tanpa rebuild app
class ApiConfig {
  static String _host = '';

  static String get host => _host;
  static void setHost(String ip) => _host = ip.trim();

  static String get baseUrl => 'http://$_host:3000/api';
  static String get wsUrl   => 'ws://$_host:3000/ws';

  // Auth
  static const String login    = '/auth/login';
  static const String logout   = '/auth/logout';
  static const String verify   = '/auth/verify';

  // Users
  static const String users    = '/users';
  static const String userMe   = '/users/me';

  // Sensors
  static const String sensorNodes   = '/sensors/nodes';
  static const String sensorLatest  = '/sensors/latest';
  static const String sensorData    = '/sensors/data';
  static const String sensorStats   = '/sensors/statistics';
  static const String sensorExport  = '/sensors/export';

  // AI
  static const String aiAnalysis   = '/ai/analysis';
  static const String aiPrediction = '/ai/prediction';
  static const String aiSummary    = '/ai/summary';

  // Notifications
  static const String notifications = '/notifications';
  static const String unreadCount   = '/notifications/unread-count';

  // Health
  static const String health = '/health';
}
