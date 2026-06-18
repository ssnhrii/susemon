// ── Timestamp helper ─────────────────────────────────────────────────────────
DateTime _parseTs(String? raw) {
  if (raw == null || raw.isEmpty) return DateTime.now().toUtc();
  try {
    final s = raw.endsWith('Z') ? raw.replaceAll('Z', '+00:00') : raw;
    return DateTime.parse(s).toUtc();
  } catch (_) {
    return DateTime.now().toUtc();
  }
}

// ── Sensor Node ───────────────────────────────────────────────────────────────

class SensorNode {
  final int id;
  final String nodeId;
  final String nodeName;
  final String location;
  final bool isActive;
  final double? currentTemp;
  final double? currentHumidity;
  final String? currentStatus;
  final DateTime? lastSeen;
  final int? lastRssi;

  const SensorNode({
    required this.id,
    required this.nodeId,
    required this.nodeName,
    required this.location,
    required this.isActive,
    this.currentTemp,
    this.currentHumidity,
    this.currentStatus,
    this.lastSeen,
    this.lastRssi,
  });

  factory SensorNode.fromJson(Map<String, dynamic> j) => SensorNode(
        id: j['id'] ?? 0,
        nodeId: j['node_id'] ?? '',
        nodeName: j['node_name'] ?? '',
        location: j['location'] ?? '',
        isActive: j['is_active'] == 1 || j['is_active'] == true,
        currentTemp: j['current_temp'] != null
            ? double.tryParse(j['current_temp'].toString())
            : null,
        currentHumidity: j['current_humidity'] != null
            ? double.tryParse(j['current_humidity'].toString())
            : null,
        currentStatus: j['current_status'],
        lastSeen: _parseTs(j['last_seen']?.toString()),
        lastRssi: j['last_rssi'] != null ? int.tryParse(j['last_rssi'].toString()) : null,
      );

  bool get isOnline {
    if (lastSeen == null) return false;
    return DateTime.now().toUtc().difference(lastSeen!).inMinutes < 2;
  }
}

// ── Sensor Reading ────────────────────────────────────────────────────────────

class SensorReading {
  final int id;
  final String nodeId;
  final double temperature;
  final double humidity;
  final String status;
  final DateTime timestamp;
  final String? nodeName;
  final String? location;
  final int? rssi;

  const SensorReading({
    required this.id,
    required this.nodeId,
    required this.temperature,
    required this.humidity,
    required this.status,
    required this.timestamp,
    this.nodeName,
    this.location,
    this.rssi,
  });

  factory SensorReading.fromJson(Map<String, dynamic> j) => SensorReading(
        id: j['id'] ?? 0,
        nodeId: j['node_id'] ?? '',
        temperature: double.tryParse(j['temperature'].toString()) ?? 0,
        humidity: double.tryParse(j['humidity'].toString()) ?? 0,
        status: j['status'] ?? 'AMAN',
        timestamp: _parseTs(j['timestamp']?.toString()),
        nodeName: j['node_name'],
        location: j['location'],
        rssi: j['rssi'] != null ? int.tryParse(j['rssi'].toString()) : null,
      );
}

// ── Statistics ────────────────────────────────────────────────────────────────

class SensorStats {
  final double avgTemp;
  final double maxTemp;
  final double minTemp;
  final double avgHumidity;
  final double maxHumidity;
  final double minHumidity;
  final int totalReadings;
  final int dangerCount;
  final int warningCount;
  final int safeCount;

  const SensorStats({
    required this.avgTemp,
    required this.maxTemp,
    required this.minTemp,
    required this.avgHumidity,
    required this.maxHumidity,
    required this.minHumidity,
    required this.totalReadings,
    required this.dangerCount,
    required this.warningCount,
    required this.safeCount,
  });

  factory SensorStats.fromJson(Map<String, dynamic> j) => SensorStats(
        avgTemp: double.tryParse(j['avg_temp']?.toString() ?? '0') ?? 0,
        maxTemp: double.tryParse(j['max_temp']?.toString() ?? '0') ?? 0,
        minTemp: double.tryParse(j['min_temp']?.toString() ?? '0') ?? 0,
        avgHumidity: double.tryParse(j['avg_humidity']?.toString() ?? '0') ?? 0,
        maxHumidity: double.tryParse(j['max_humidity']?.toString() ?? '0') ?? 0,
        minHumidity: double.tryParse(j['min_humidity']?.toString() ?? '0') ?? 0,
        totalReadings: j['total_readings'] ?? 0,
        dangerCount: j['danger_count'] ?? 0,
        warningCount: j['warning_count'] ?? 0,
        safeCount: j['safe_count'] ?? 0,
      );

  factory SensorStats.empty() => const SensorStats(
        avgTemp: 0, maxTemp: 0, minTemp: 0,
        avgHumidity: 0, maxHumidity: 0, minHumidity: 0,
        totalReadings: 0, dangerCount: 0, warningCount: 0, safeCount: 0,
      );
}

// ── AI Analysis ───────────────────────────────────────────────────────────────

class AiAnalysis {
  final String nodeId;
  final String? nodeName;
  final String? location;
  final bool anomalyDetected;
  final bool overheatingRisk;
  final String riskLevel;
  final int confidence;
  final double currentTemp;
  final double currentHumidity;
  final double avgTemp;
  final double ewmaTemp;
  final double predictedTemp;
  final double zScoreTemp;
  final double zScoreHumidity;
  final double trendPerHour;
  final String trendDirection;
  final double isolationForestScore;
  final List<String> insights;
  final List<String> methodsUsed;
  final int signalCount;

  const AiAnalysis({
    required this.nodeId,
    this.nodeName,
    this.location,
    required this.anomalyDetected,
    required this.overheatingRisk,
    required this.riskLevel,
    required this.confidence,
    required this.currentTemp,
    required this.currentHumidity,
    required this.avgTemp,
    required this.ewmaTemp,
    required this.predictedTemp,
    required this.zScoreTemp,
    required this.zScoreHumidity,
    required this.trendPerHour,
    required this.trendDirection,
    required this.isolationForestScore,
    required this.insights,
    required this.methodsUsed,
    required this.signalCount,
  });

  factory AiAnalysis.fromJson(Map<String, dynamic> j) => AiAnalysis(
        nodeId: j['node_id'] ?? '',
        nodeName: j['node_name'],
        location: j['location'],
        anomalyDetected: j['anomaly_detected'] == true || j['anomaly_detected'] == 1,
        overheatingRisk: j['overheating_risk'] == true || j['overheating_risk'] == 1,
        riskLevel: j['risk_level'] ?? 'LOW',
        confidence: j['confidence'] ?? 0,
        currentTemp: double.tryParse(j['current_temp']?.toString() ?? '0') ?? 0,
        currentHumidity: double.tryParse(j['current_humidity']?.toString() ?? '0') ?? 0,
        avgTemp: double.tryParse(j['avg_temp']?.toString() ?? '0') ?? 0,
        ewmaTemp: double.tryParse(j['ewma_temp']?.toString() ?? '0') ?? 0,
        predictedTemp: double.tryParse(j['predicted_temp']?.toString() ?? '0') ?? 0,
        zScoreTemp: double.tryParse(j['z_score_temp']?.toString() ?? '0') ?? 0,
        zScoreHumidity: double.tryParse(j['z_score_humidity']?.toString() ?? '0') ?? 0,
        trendPerHour: double.tryParse(j['trend_per_hour']?.toString() ?? '0') ?? 0,
        trendDirection: j['trend_direction'] ?? 'stable',
        isolationForestScore: double.tryParse(j['isolation_forest_score']?.toString() ?? '0') ?? 0,
        insights: (j['insights'] as List?)?.map((e) => e.toString()).toList() ?? [],
        methodsUsed: (j['methods_used'] as List?)?.map((e) => e.toString()).toList() ?? [],
        signalCount: j['signal_count'] ?? 0,
      );
}

// ── AI Prediction ─────────────────────────────────────────────────────────────

class AiPrediction {
  final String nodeId;
  final double currentTemp;
  final double predictedTemp;
  final double avgTemp;
  final double zScore;
  final String riskLevel;
  final int confidence;
  final String trend;
  final List<String> insights;

  const AiPrediction({
    required this.nodeId,
    required this.currentTemp,
    required this.predictedTemp,
    required this.avgTemp,
    required this.zScore,
    required this.riskLevel,
    required this.confidence,
    required this.trend,
    required this.insights,
  });

  factory AiPrediction.fromJson(Map<String, dynamic> j) => AiPrediction(
        nodeId: j['node_id'] ?? '',
        currentTemp: double.tryParse(j['current_temp']?.toString() ?? '0') ?? 0,
        predictedTemp: double.tryParse(j['predicted_temp']?.toString() ?? '0') ?? 0,
        avgTemp: double.tryParse(j['avg_temp']?.toString() ?? '0') ?? 0,
        zScore: double.tryParse(j['z_score_temp']?.toString() ?? '0') ?? 0,
        riskLevel: j['risk_level'] ?? 'LOW',
        confidence: j['confidence'] ?? 0,
        trend: j['trend_direction'] ?? 'stable',
        insights: (j['insights'] as List?)?.map((e) => e.toString()).toList() ?? [],
      );
}

// ── Notification ──────────────────────────────────────────────────────────────

class AppNotification {
  final int id;
  final String? nodeId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final String? nodeName;
  final String? location;

  const AppNotification({
    required this.id,
    this.nodeId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.nodeName,
    this.location,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] ?? 0,
        nodeId: j['node_id'],
        title: j['title'] ?? '',
        message: j['message'] ?? '',
        type: j['type'] ?? 'info',
        isRead: j['is_read'] == 1 || j['is_read'] == true,
        createdAt: _parseTs(j['created_at']?.toString()),
        nodeName: j['node_name'],
        location: j['location'],
      );

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        nodeId: nodeId,
        title: title,
        message: message,
        type: type,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        nodeName: nodeName,
        location: location,
      );
}
