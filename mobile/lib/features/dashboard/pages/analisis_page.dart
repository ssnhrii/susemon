import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/app_provider.dart';
import '../../../models/sensor_model.dart';
import '../../../shared/widgets/interactive.dart';

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
      final ai     = context.read<AiProvider>();
      final sensor = context.read<SensorProvider>();
      final nodeIds = sensor.latest.map((r) => r.nodeId).toSet();
      if (nodeIds.isNotEmpty) {
        ai.fetchAnalysis();
        for (final nodeId in nodeIds) {
          ai.fetchPrediction(nodeId);
        }
      } else {
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
    final ai     = context.watch<AiProvider>();
    final sensor = context.watch<SensorProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  HapticFeedback.mediumImpact();
                  await ai.fetchAnalysis();
                },
                color: AppColors.primary,
                backgroundColor: AppColors.bgCard,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (ai.analysis.isEmpty)
                        _buildFallbackCards(sensor.latest)
                      else
                        ...ai.analysis.map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: FadeSlideIn(
                            delay: Duration(milliseconds: 50 * ai.analysis.indexOf(a)),
                            child: TapScale(
                              onTap: () => HapticFeedback.selectionClick(),
                              child: _AiCard(analysis: a),
                            ),
                          ),
                        )),
                      const SizedBox(height: 4),
                      if (ai.predictions.isNotEmpty)
                        _PredictionCard(predictions: ai.predictions),
                      const SizedBox(height: 12),
                      _GatewayCard(wsConnected: sensor.wsConnected),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    color: AppColors.bgCard,
    child: Row(children: [
      const Icon(Icons.psychology_rounded, color: AppColors.primary, size: 22),
      const SizedBox(width: 10),
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Analisis AI', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
        Text('EWMA · Z-score · Trend · Isolation Forest', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ]),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.warning.withValues(alpha: 0.3))),
        child: const Text('Prediktif', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.warning)),
      ),
    ]),
  );

  Widget _buildFallbackCards(List<SensorReading> latest) {
    if (latest.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: const Column(children: [
          Icon(Icons.sensors_off, size: 48, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Text('Menunggu data dari sensor...', style: TextStyle(color: AppColors.textSecondary)),
        ]),
      );
    }
    return Column(children: latest.map((r) {
      final color = AppColors.statusColor(r.status);
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.3))),
          child: Row(children: [
            Container(width: 44, height: 44,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(r.status == 'BERBAHAYA' ? Icons.local_fire_department : r.status == 'WASPADA' ? Icons.warning_rounded : Icons.check_circle,
                    color: color, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.nodeName ?? r.nodeId, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              Text('${r.temperature.toStringAsFixed(1)}°C  ·  ${r.humidity.toStringAsFixed(0)}%  ·  ${r.status}',
                  style: TextStyle(fontSize: 11, color: color)),
            ])),
          ]),
        ),
      );
    }).toList());
  }
}

class _AiCard extends StatelessWidget {
  final AiAnalysis analysis;
  const _AiCard({required this.analysis});

  Color get _color => analysis.overheatingRisk ? AppColors.danger : analysis.anomalyDetected ? AppColors.warning : AppColors.success;
  String get _title => analysis.overheatingRisk ? 'Risiko Overheating' : analysis.anomalyDetected ? 'Anomali Terdeteksi' : 'Kondisi Normal';
  IconData get _icon => analysis.overheatingRisk ? Icons.local_fire_department : analysis.anomalyDetected ? Icons.show_chart : Icons.check_circle;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _color.withValues(alpha: 0.3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Baris 1: Node + Status + Confidence ──
      Row(children: [
        Container(width: 44, height: 44,
            decoration: BoxDecoration(color: _color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(_icon, color: _color, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(analysis.nodeId, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary))),
            const SizedBox(width: 8),
            Text(_title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _color)),
          ]),
          const SizedBox(height: 3),
          Text('${analysis.currentTemp.toStringAsFixed(1)}°C  ·  ${analysis.currentHumidity.toStringAsFixed(0)}%  ·  avg ${analysis.avgTemp}°C',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${analysis.confidence}%', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _color)),
          const Text('confidence', style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
        ]),
      ]),

      // ── Baris 2: Metrik AI ──
      const SizedBox(height: 10),
      Row(children: [
        _metric('Tren', '${analysis.trendPerHour >= 0 ? '+' : ''}${analysis.trendPerHour.toStringAsFixed(1)}°C/h',
            analysis.trendPerHour.abs() > 3 ? AppColors.warning : AppColors.textSecondary),
        const SizedBox(width: 12),
        _metric('Z-score', analysis.zScoreTemp.toStringAsFixed(2),
            analysis.zScoreTemp.abs() > 2.5 ? AppColors.warning : AppColors.textSecondary),
        const SizedBox(width: 12),
        _metric('Sinyal', '${analysis.signalCount}/6',
            analysis.signalCount >= 2 ? AppColors.warning : AppColors.textSecondary),
        const SizedBox(width: 12),
        _metric('Tren arah', analysis.trendDirection == 'increasing' ? '↑ naik'
            : analysis.trendDirection == 'decreasing' ? '↓ turun' : '→ stabil', AppColors.textSecondary),
      ]),

      // ── Baris 3: Insights ──
      if (analysis.insights.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _color.withValues(alpha: 0.2))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: analysis.insights.take(3).map((insight) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline, size: 11, color: _color),
                  const SizedBox(width: 5),
                  Expanded(child: Text(insight, style: TextStyle(fontSize: 10, color: _color.withValues(alpha: 0.9)))),
                ]),
              )).toList()),
        ),
      ],
    ]),
  );

  Widget _metric(String label, String value, Color color) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
      Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}

class _PredictionCard extends StatelessWidget {
  final Map<String, AiPrediction> predictions;
  const _PredictionCard({required this.predictions});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.timeline, size: 16, color: AppColors.primary),
        SizedBox(width: 8),
        Text('Prediksi 30 Menit ke Depan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
      ]),
      const SizedBox(height: 14),
      ...predictions.entries.map((e) {
        final p = e.value;
        final rc = p.riskLevel == 'HIGH' ? AppColors.danger : p.riskLevel == 'MEDIUM' ? AppColors.warning : AppColors.success;
        return Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                  child: Text(p.nodeId, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Prediksi: ${p.predictedTemp.toStringAsFixed(1)}°C', style: const TextStyle(fontSize: 12, color: Colors.white)),
                Text('Z-score: ${p.zScore.toStringAsFixed(2)}  ·  Tren: ${p.trend}',
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              ])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: rc.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(p.riskLevel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: rc))),
            ]),
            if (p.insights.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 2),
                child: Text('• ${p.insights.first}',
                    style: TextStyle(fontSize: 10, color: rc.withValues(alpha: 0.8))),
              ),
          ],
        ));
      }),
    ]),
  );
}

class _GatewayCard extends StatelessWidget {
  final bool wsConnected;
  const _GatewayCard({required this.wsConnected});

  @override
  Widget build(BuildContext context) {
    final statusColor = wsConnected ? AppColors.success : AppColors.warning;
    final statusLabel = wsConnected ? 'Terhubung' : 'Polling';
    final params = [
      ['Gateway', 'Dragino LG02'],
      ['Frekuensi', '915 MHz'],
      ['Spreading Factor', 'SF7'],
      ['Bandwidth', '125 kHz'],
      ['Sync Word', '0x12 (18)'],
      ['Tx Power', '20 dBm'],
      ['Koneksi', wsConnected ? 'WebSocket' : 'HTTP Polling'],
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.router, color: AppColors.success, size: 20),
          const SizedBox(width: 10),
          const Text('LoRa Gateway', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3))),
              child: Row(children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
              ])),
        ]),
        const SizedBox(height: 14),
        ...params.map((p) => Padding(padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(p[0], style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              Text(p[1], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ]))),
      ]),
    );
  }
}
