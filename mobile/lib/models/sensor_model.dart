// ── Sensor Node ───────────────────────────────────────────────────────────────

class SensorNode {
  final String nodeId;
  final String nodeName;
  final String location;
  final bool isActive;
  final double? currentTemp;
  final double? currentHumidity;
  final String? currentStatus;

  const SensorNode({
    required this.nodeId,
    required this.nodeName,
    required this.location,
    required this.isActive,
    this.currentTemp,
    this.currentHumidity,
    this.currentStatus,
  });

  factory SensorNode.fromJson(Map<String, dynamic> j) => SensorNode(
        nodeId: j['node_id'] ?? '',
        nodeName: j['node_name'] ?? '',
        location: j['location'] ?? '',
        isActive: j['is_active'] == 1 || j['is_active'] == true,
        currentTemp: j['current_temp'] != null ? double.tryParse(j['current_temp'].toString()) : null,
        currentHumidity: j['current_humidity'] != null ? double.tryParse(j['current_humidity'].toString()) : null,
        currentStatus: j['current_status'],
      );
}

// ── Sensor Reading ────────────────────────────────────────────────────────────

class SensorReading {
  final int id;
  final String nodeId;
  final double temperature;
  final double humidity;
  final String status; // AMAN | WASPADA | BERBAHAYA
  final DateTime timestamp;
  // From JOIN with sensor_nodes
  final String? nodeName;
  final String? location;

  const SensorReading({
    required this.id,
    required this.nodeId,
    required this.temperature,
    required this.humidity,
    required this.status,
    required this.timestamp,
    this.nodeName,
    this.location,
  });

  factory SensorReading.fromJson(Map<String, dynamic> j) => SensorReading(
        id: j['id'] ?? 0,
        nodeId: j['node_id'] ?? '',
        temperature: double.tryParse(j['temperature'].toString()) ?? 0,
        humidity: double.tryParse(j['humidity'].toString()) ?? 0,
        status: j['status'] ?? 'AMAN',
        timestamp: DateTime.tryParse(j['timestamp'].toString()) ?? DateTime.now(),
        nodeName: j['node_name'],
        location: j['location'],
      );
}

// ── Statistics ────────────────────────────────────────────────────────────────

class SensorStats {
  final double avgTemp;
  final double maxTemp;
  final double minTemp;
  final double avgHumidity;
  final int dangerCount;
  final int warningCount;
  final int safeCount;

  const SensorStats({
    required this.avgTemp,
    required this.maxTemp,
    required this.minTemp,
    required this.avgHumidity,
    required this.dangerCount,
    required this.warningCount,
    required this.safeCount,
  });

  factory SensorStats.fromJson(Map<String, dynamic> j) => SensorStats(
        avgTemp: double.tryParse(j['avg_temp']?.toString() ?? '0') ?? 0,
        maxTemp: double.tryParse(j['max_temp']?.toString() ?? '0') ?? 0,
        minTemp: double.tryParse(j['min_temp']?.toString() ?? '0') ?? 0,
        avgHumidity: double.tryParse(j['avg_humidity']?.toString() ?? '0') ?? 0,
        dangerCount: j['danger_count'] ?? 0,
        warningCount: j['warning_count'] ?? 0,
        safeCount: j['safe_count'] ?? 0,
      );

  factory SensorStats.empty() => const SensorStats(
        avgTemp: 0, maxTemp: 0, minTemp: 0, avgHumidity: 0,
        dangerCount: 0, warningCount: 0, safeCount: 0,
      );
}

// ── AI Analysis ───────────────────────────────────────────────────────────────

class AiAnalysis {
  final String nodeId;
  final bool anomalyDetected;
  final bool overheatingRisk;
  final int confidence;
  final double currentTemp;
  final double avgTemp;

  const AiAnalysis({
    required this.nodeId,
    required this.anomalyDetected,
    required this.overheatingRisk,
    required this.confidence,
    required this.currentTemp,
    required this.avgTemp,
  });

  factory AiAnalysis.fromJson(Map<String, dynamic> j) => AiAnalysis(
        nodeId: j['node_id'] ?? '',
        anomalyDetected: j['anomaly_detected'] == true || j['anomaly_detected'] == 1,
        overheatingRisk: j['overheating_risk'] == true || j['overheating_risk'] == 1,
        confidence: j['confidence'] ?? 0,
        currentTemp: double.tryParse(j['current_temp']?.toString() ?? '0') ?? 0,
        avgTemp: double.tryParse(j['avg_temp']?.toString() ?? '0') ?? 0,
      );
}

// ── AI Prediction ─────────────────────────────────────────────────────────────

class AiPrediction {
  final String nodeId;
  final double currentTemp;
  final double predictedTemp;
  final double movingAverage;
  final double zScore;
  final String riskLevel; // LOW | MEDIUM | HIGH
  final int confidence;
  final String trend; // increasing | decreasing

  const AiPrediction({
    required this.nodeId,
    required this.currentTemp,
    required this.predictedTemp,
    required this.movingAverage,
    required this.zScore,
    required this.riskLevel,
    required this.confidence,
    required this.trend,
  });

  factory AiPrediction.fromJson(Map<String, dynamic> j) => AiPrediction(
        nodeId: j['node_id'] ?? '',
        currentTemp: double.tryParse(j['current_temp']?.toString() ?? '0') ?? 0,
        predictedTemp: double.tryParse(j['predicted_temp']?.toString() ?? '0') ?? 0,
        movingAverage: double.tryParse(j['avg_temp']?.toString() ?? '0') ?? 0,
        zScore: double.tryParse(j['z_score_temp']?.toString() ?? '0') ?? 0,
        riskLevel: j['risk_level'] ?? 'LOW',
        confidence: j['confidence'] ?? 0,
        trend: j['trend_direction'] ?? 'stable',
      );
}

// ── Notification ──────────────────────────────────────────────────────────────

class AppNotification {
  final int id;
  final String? nodeId;
  final String title;
  final String message;
  final String type; // critical | warning | success | info
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
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
        nodeName: j['node_name'],
        location: j['location'],
      );
}
