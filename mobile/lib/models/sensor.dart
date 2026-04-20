import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

// Model classes
class Sensor {
  final String id;
  final String name;
  final String location;
  final double temp;
  final double? koleratometer;
  final double? kelambutan;
  final String status;
  final int kelembaban;
  final String type;

  Sensor({
    required this.id,
    required this.name,
    required this.location,
    required this.temp,
    this.koleratometer,
    this.kelambutan,
    required this.status,
    required this.kelembaban,
    required this.type,
  });
}

class NotificationItem {
  final String msg;
  final String time;
  final bool ai;

  NotificationItem({
    required this.msg,
    required this.time,
    required this.ai,
  });
}

// Sample data ported from HTML/JS
List<Sensor> sensorData = [
  Sensor(
    id: "A1",
    name: "Node Sensor A1",
    location: "Rack Server Utama",
    temp: 28.5,
    koleratometer: 45.0,
    status: "Normal",
    kelembaban: 92,
    type: "koleratometer",
  ),
  Sensor(
    id: "B2",
    name: "Node Sensor B2",
    location: "Rack Server Backup",
    temp: 32.1,
    kelambutan: 52.0,
    status: "Normal",
    kelembaban: 70,
    type: "kelambutan",
  ),
  Sensor(
    id: "C3",
    name: "Node Sensor C3",
    location: "Rack Platform",
    temp: 26.8,
    kelambutan: 48.0,
    status: "Normal",
    kelembaban: 95,
    type: "kelambutan",
  ),
  Sensor(
    id: "D4",
    name: "Node Sensor D4",
    location: "Rack Storage",
    temp: 43.2,
    kelambutan: 38.0,
    status: "Warning",
    kelembaban: 60,
    type: "kelambutan",
  ),
];

List<NotificationItem> notifications = [
  NotificationItem(
    msg: "Suhu NODE-004 mencapai 41.2°C - Perlu perhatian",
    time: "NODE-004 02:00:25",
    ai: false,
  ),
  NotificationItem(
    msg: "Pola perubahan suhu tidak wajar terdeteksi pada NODE-002",
    time: "02:20:30",
    ai: false,
  ),
  NotificationItem(
    msg: "Analisis AI: Proyeksi overheating dalam 30 menit",
    time: "NODE-004 02:06:05",
    ai: true,
  ),
];

// Compute warnings (ported from JS)
Map<String, int> computeWarnings(List<Sensor> sensors) {
  int peringatan = 0;
  int kritis = 0;
  for (var sensor in sensors) {
    if (sensor.status == "Warning") peringatan++;
    if (sensor.temp >= 42) kritis++;
  }
  return {'peringatan': peringatan, 'kritis': kritis};
}

// Avg temp
double computeAvgTemp(List<Sensor> sensors) {
  return sensors.map((s) => s.temp).reduce((a, b) => a + b) / sensors.length;
}

// Generate 24-hour temperature trend data for a specific sensor (simulated)
List<FlSpot> generateTempTrend(String nodeId, {int hours = 24}) {
  final sensor = sensorData.firstWhere((s) => s.id == nodeId);
  final baseTemp = sensor.temp;
  final spots = <FlSpot>[];
  
  // Simulate trend: gradual increase if warning/high temp, with some noise
  final isHighRisk = baseTemp > 35;
  double currentTemp = baseTemp - 10; // Start lower
  
  for (int h = 0; h <= hours; h += 2) {
    // Add sinusoidal noise + trend
    currentTemp += (isHighRisk ? 0.4 : 0.1) + (sin(h / 3.0) * 1.2);
    spots.add(FlSpot(h.toDouble(), currentTemp.clamp(20, 50)));
  }
  
  return spots;
}

// Generate dynamic AI insights based on current sensors
List<Map<String, String>> generateAIInsights() {
  final highTempSensors = sensorData.where((s) => s.temp > 40).toList();
  final avgTemp = computeAvgTemp(sensorData);
  
  final insights = <Map<String, String>>[];
  
  if (highTempSensors.isNotEmpty) {
    for (var sensor in highTempSensors) {
      insights.add({
        'title': 'Pola Overheating',
        'confidence': '94%',
        'icon': 'Icons.local_fire_department',
        'description': '${sensor.name} menunjukkan peningkatan suhu ${sensor.temp.toStringAsFixed(1)}°C.',
        'type': 'overheating',
        'nodeId': sensor.id,
      });
    }
  }
  
  // Add anomaly if avg high
  if (avgTemp > 32) {
    insights.add({
      'title': 'Anomali Pola Suhu',
      'confidence': '87%',
      'icon': 'Icons.analytics',
      'description': 'Suhu rata-rata ${avgTemp.toStringAsFixed(1)}°C - pola fluktuasi tidak normal.',
      'type': 'anomali',
      'nodeId': '',
    });
  }
  
  // Fill to 3 with trend
  while (insights.length < 3) {
    insights.add({
      'title': 'Tren Peningkatan',
      'confidence': '91%',
      'icon': 'Icons.trending_up',
      'description': 'Monitoring terus menerus diperlukan.',
      'type': 'tren',
      'nodeId': '',
    });
  }
  
  return insights;
}


