import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/app_provider.dart';
import '../../../models/sensor_model.dart';
import '../../../shared/widgets/interactive.dart';
import '../../../shared/widgets/mesh_background.dart';

class AnalisisPage extends StatefulWidget {
  const AnalisisPage({super.key});
  @override
  State<AnalisisPage> createState() => _AnalisisPageState();
}

class _AnalisisPageState extends State<AnalisisPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ai = context.read<AiProvider>();
      final sensor = context.read<SensorProvider>();
      ai.fetchAnalysis();
      final nodeIds = sensor.latest.map((r) => r.nodeId).toSet();
      for (final nodeId in nodeIds) {
        ai.fetchPrediction(nodeId);
      }
      if (nodeIds.isEmpty) {
        ai.fetchAnalysis().then((_) {
          if (!context.mounted) return;
          for (final a in ai.analysis) {
            ai.fetchPrediction(a.nodeId);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiProvider>();
    final sensor = context.watch<SensorProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: MeshBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(sensor.wsConnected),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    HapticFeedback.mediumImpact();
                    await ai.fetchAnalysis();
                  },
                  color: AppColors.primary,
                  backgroundColor: Colors.white,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _AiStatusCard(wsConnected: sensor.wsConnected),
                        const SizedBox(height: 14),
                        if (ai.analysis.isEmpty)
                          _buildFallbackCards(sensor.latest)
                        else
                          ...ai.analysis.map(
                            (a) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: FadeSlideIn(
                                delay: Duration(
                                  milliseconds: 50 * ai.analysis.indexOf(a),
                                ),
                                child: TapScale(
                                  onTap: () => HapticFeedback.selectionClick(),
                                  child: _AiCard(analysis: a),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        if (ai.predictions.isNotEmpty) ...[
                          _PredictionCard(predictions: ai.predictions),
                          const SizedBox(height: 14),
                        ],
                        _GatewayCard(wsConnected: sensor.wsConnected),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool wsConnected) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.7),
      border: Border(
        bottom: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
      ),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.psychology_rounded,
          color: AppColors.primary,
          size: 22,
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Analisis AI',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            Text(
              'Moving Average · Z-score · Isolation Forest',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: const Text(
            'Enterprise',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildFallbackCards(List<SensorReading> latest) {
    if (latest.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.sensors_off, size: 48, color: AppColors.textDim),
            const SizedBox(height: 12),
            Text(
              'Menunggu data dari sensor...',
              style: TextStyle(color: AppColors.textDim),
            ),
          ],
        ),
      );
    }
    return Column(
      children: latest.map((r) {
        final color = AppColors.statusColor(r.status);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: AppColors.glassCard(
              radius: 14,
              borderColor: color.withValues(alpha: 0.2),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    r.status == 'BERBAHAYA'
                        ? Icons.local_fire_department
                        : r.status == 'WASPADA'
                        ? Icons.warning_rounded
                        : Icons.check_circle,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.nodeName ?? r.nodeId,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      Text(
                        '${r.temperature.toStringAsFixed(1)}°C  ·  ${r.humidity.toStringAsFixed(0)}%  ·  ${r.status}',
                        style: TextStyle(fontSize: 11, color: color),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── AI Status Card ────────────────────────────────────────────────────────────

class _AiStatusCard extends StatelessWidget {
  final bool wsConnected;
  const _AiStatusCard({required this.wsConnected});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: AppColors.glassCard(
      radius: 16,
      borderColor: AppColors.primary.withValues(alpha: 0.15),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.15),
            ),
          ),
          child: const Icon(
            Icons.psychology_rounded,
            color: AppColors.primary,
            size: 26,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Analisis Mesin Pembelajaran',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'Enterprise',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Sinkronisasi: Baru saja  ·  Model: v2.4.1',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'AMAN',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ── AI Card ───────────────────────────────────────────────────────────────────

class _AiCard extends StatelessWidget {
  final AiAnalysis analysis;
  const _AiCard({required this.analysis});

  Color get _color => analysis.overheatingRisk
      ? AppColors.danger
      : analysis.anomalyDetected
      ? AppColors.warning
      : AppColors.success;
  String get _title => analysis.overheatingRisk
      ? 'Risiko Overheating'
      : analysis.anomalyDetected
      ? 'Anomali Terdeteksi'
      : 'Kondisi Normal';
  IconData get _icon => analysis.overheatingRisk
      ? Icons.local_fire_department_rounded
      : analysis.anomalyDetected
      ? Icons.show_chart_rounded
      : Icons.check_circle_rounded;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: AppColors.glassCard(
      radius: 14,
      borderColor: _color.withValues(alpha: 0.2),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_icon, color: _color, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      analysis.nodeId,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Suhu: ${analysis.currentTemp.toStringAsFixed(1)}°C  ·  Rata-rata: ${analysis.avgTemp}°C',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          children: [
            Text(
              '${analysis.confidence}%',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: _color,
              ),
            ),
            Text(
              'confidence',
              style: TextStyle(fontSize: 9, color: AppColors.textDim),
            ),
          ],
        ),
      ],
    ),
  );
}

// ── Prediction Card ───────────────────────────────────────────────────────────

class _PredictionCard extends StatelessWidget {
  final Map<String, AiPrediction> predictions;
  const _PredictionCard({required this.predictions});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: AppColors.glassCard(radius: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.timeline_rounded,
                size: 16,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Prediksi 30 Menit ke Depan',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...predictions.entries.map((e) {
          final p = e.value;
          final rc = p.riskLevel == 'HIGH'
              ? AppColors.danger
              : p.riskLevel == 'MEDIUM'
              ? AppColors.warning
              : AppColors.success;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    p.nodeId,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prediksi: ${p.predictedTemp.toStringAsFixed(1)}°C',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurface,
                        ),
                      ),
                      Text(
                        'Z-score: ${p.zScore.toStringAsFixed(2)}  ·  Tren: ${p.trend}',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: rc.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    p.riskLevel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: rc,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    ),
  );
}

// ── Gateway Card ──────────────────────────────────────────────────────────────

class _GatewayCard extends StatelessWidget {
  final bool wsConnected;
  const _GatewayCard({required this.wsConnected});

  @override
  Widget build(BuildContext context) {
    final params = [
      ['Frekuensi', '923.5 MHz'],
      ['Spreading Factor', 'SF7'],
      ['Bandwidth', '125 kHz'],
      ['Tx Power', '20 dBm'],
      ['Koneksi', wsConnected ? 'WebSocket' : 'HTTP Polling'],
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppColors.glassCard(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.router_rounded,
                  color: AppColors.success,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'LoRa Gateway',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Terhubung',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...params.map(
            (p) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    p[0],
                    style: TextStyle(fontSize: 12, color: AppColors.textDim),
                  ),
                  Text(
                    p[1],
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
