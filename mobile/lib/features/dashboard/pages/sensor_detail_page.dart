import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/sensor_model.dart';
import '../../../services/api_service.dart';
import '../../../providers/app_provider.dart';

class SensorDetailPage extends StatefulWidget {
  final SensorNode node;
  const SensorDetailPage({super.key, required this.node});
  @override
  State<SensorDetailPage> createState() => _SensorDetailPageState();
}

class _SensorDetailPageState extends State<SensorDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<SensorReading> _history = [];
  SensorStats _stats = SensorStats.empty();
  AiAnalysis? _ai;
  List<AppNotification> _anomalies = [];
  bool _loadingHistory = true;/*  */
  bool _loadingAi = true;
  String _chartMetric = 'temp';
  String _period = '24h';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _fetchAll();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) { if (mounted) _fetchAll(); });
  }

  @override
  void dispose() { _tabCtrl.dispose(); _refreshTimer?.cancel(); super.dispose(); }

  Future<void> _fetchAll() => Future.wait([_fetchHistory(), _fetchAi(), _fetchAnomalies()]);

  Future<void> _fetchHistory() async {
    if (mounted) setState(() => _loadingHistory = true);
    try {
      final api = context.read<ApiService>();
      final hist  = await api.getSensorHistory(widget.node.nodeId, period: _period, limit: 50);
      final stats = await api.getStatistics(period: _period, nodeId: widget.node.nodeId);
      if (!mounted) return;
      setState(() { _history = hist; _stats = stats; });
    } catch (_) {}
    if (mounted) setState(() => _loadingHistory = false);
  }

  Future<void> _fetchAi() async {
    if (mounted) setState(() => _loadingAi = true);
    try {
      final api  = context.read<ApiService>();
      final pred = await api.getAiPrediction(widget.node.nodeId);
      if (!mounted) return;
      setState(() => _ai = pred != null ? _fromPred(pred) : null);
    } catch (_) {}
    if (mounted) setState(() => _loadingAi = false);
  }

  Future<void> _fetchAnomalies() async {
    try {
      final api = context.read<ApiService>();
      final all = await api.getNotifications(limit: 50);
      if (!mounted) return;
      setState(() {
        _anomalies = all.where((n) => n.nodeId == widget.node.nodeId &&
            (n.type == 'critical' || n.type == 'warning')).take(10).toList();
      });
    } catch (_) {}
  }

  AiAnalysis _fromPred(AiPrediction p) => AiAnalysis(
    nodeId: p.nodeId, nodeName: widget.node.nodeName, location: widget.node.location,
    anomalyDetected: p.riskLevel != 'LOW', overheatingRisk: p.riskLevel == 'HIGH',
    riskLevel: p.riskLevel, confidence: p.confidence,
    currentTemp: p.currentTemp, currentHumidity: widget.node.currentHumidity ?? 0,
    avgTemp: p.avgTemp, ewmaTemp: p.avgTemp, predictedTemp: p.predictedTemp,
    zScoreTemp: p.zScore, zScoreHumidity: 0, trendPerHour: 0,
    trendDirection: p.trend, isolationForestScore: 0,
    insights: p.insights, methodsUsed: const [], signalCount: 0,
  );

  Color _tempColor(double? t) {
    if (t == null) return AppColors.textDim;
    if (t >= 40) return AppColors.danger;
    if (t >= 35) return AppColors.warning;
    return const Color(0xFF3B82F6);
  }
  Color _humColor(double? h) {
    if (h == null) return AppColors.textDim;
    if (h >= 85) return AppColors.danger;
    if (h >= 80) return AppColors.warning;
    return const Color(0xFF3B82F6);
  }

  @override
  Widget build(BuildContext context) {
    final node  = widget.node;
    final live  = context.watch<SensorProvider>().latest.where((r) => r.nodeId == node.nodeId).firstOrNull;
    final temp   = live?.temperature ?? node.currentTemp;
    final hum    = live?.humidity    ?? node.currentHumidity;
    final status = live?.status      ?? node.currentStatus ?? 'AMAN';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FF),
      body: Column(children: [
        _buildAppBar(node),
        _buildTabBar(),
        Expanded(child: TabBarView(controller: _tabCtrl, children: [
          _buildMonitoringTab(node, temp, hum, status),
          _buildAiTab(),
        ])),
      ]),
    );
  }

  Widget _buildAppBar(SensorNode node) => Container(
    decoration: const BoxDecoration(
      color: Color(0xFF0058BE),
      boxShadow: [BoxShadow(color: Color(0x18000000), blurRadius:8, offset:Offset(0,2))],
    ),
    child: SafeArea(bottom: false, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Baris 1: icon + SUSEMON + notif + avatar
      Padding(padding: const EdgeInsets.symmetric(horizontal:16, vertical:10),
        child: Row(children: [
          const Icon(Icons.menu_rounded, color: Colors.white, size:22),
          const SizedBox(width:8),
          const Icon(Icons.sensors_rounded, color: Colors.white, size:16),
          const SizedBox(width:5),
          const Text('SUSEMON', style: TextStyle(fontSize:15, fontWeight:FontWeight.w900, color:Colors.white, letterSpacing:1.5)),
          const Spacer(),
          _wBtn(Icons.notifications_outlined),
          const SizedBox(width:8),
          Container(width:32,height:32,
            decoration:BoxDecoration(color:Colors.white.withValues(alpha:0.18),shape:BoxShape.circle),
            child:const Icon(Icons.person_outline_rounded,color:Colors.white,size:18)),
        ]),
      ),
      // Baris 2: KEMBALI + breadcrumb
      Padding(padding: const EdgeInsets.fromLTRB(16,0,16,12),
        child: Row(children: [
          GestureDetector(
            onTap: () { HapticFeedback.lightImpact(); Navigator.pop(context); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal:10,vertical:5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.18),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color:Colors.white.withValues(alpha:0.3)),
              ),
              child: const Row(mainAxisSize:MainAxisSize.min, children:[
                Icon(Icons.arrow_back_ios_rounded,size:11,color:Colors.white),
                SizedBox(width:3),
                Text('KEMBALI',style:TextStyle(fontSize:10,fontWeight:FontWeight.w700,color:Colors.white,letterSpacing:0.5)),
              ]),
            ),
          ),
          const SizedBox(width:10),
          Expanded(child: Text(
            'SENSOR  ›  ${node.location.isEmpty ? 'RACK' : node.location.toUpperCase()}  ›  ${node.nodeId}',
            style: TextStyle(fontSize:9, color:Colors.white.withValues(alpha:0.75), fontWeight:FontWeight.w500, letterSpacing:0.3),
            overflow: TextOverflow.ellipsis,
          )),
        ]),
      ),
    ])),
  );

  Widget _wBtn(IconData icon) => Container(width:32,height:32,
    decoration:BoxDecoration(color:Colors.white.withValues(alpha:0.18),borderRadius:BorderRadius.circular(8)),
    child:Icon(icon,color:Colors.white,size:18));

  Widget _buildTabBar() => Container(
    color: Colors.white,
    child: TabBar(
      controller: _tabCtrl,
      labelStyle: const TextStyle(fontSize:13,fontWeight:FontWeight.w700),
      unselectedLabelStyle: const TextStyle(fontSize:13,fontWeight:FontWeight.w500),
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textDim,
      indicatorColor: AppColors.primary,
      indicatorWeight: 3,
      tabs: const [Tab(text:'Monitoring'), Tab(text:'Analisis AI')],
    ),
  );
  Widget _buildMonitoringTab(SensorNode node, double? temp, double? hum, String status) {
    return RefreshIndicator(
      onRefresh: _fetchAll,
      color: AppColors.primary,
      child: ListView(padding: const EdgeInsets.fromLTRB(16,16,16,32), children: [

        // ── 1. Info Card ──────────────────────────────────────────────
        _InfoCard(node: node, status: status),
        const SizedBox(height:14),

        // ── 2. Temperatur Card ────────────────────────────────────────
        _MetricCard(
          label: 'TEMPERATUR',
          value: temp,
          unit: '°C',
          icon: Icons.thermostat_rounded,
          color: _tempColor(temp),
          min: _stats.minTemp,
          avg: _stats.avgTemp,
          max: _stats.maxTemp,
          maxAllowed: 40,
        ),
        const SizedBox(height:12),

        // ── 3. Kelembapan Card ────────────────────────────────────────
        _MetricCard(
          label: 'KELEMBAPAN',
          value: hum,
          unit: '%',
          icon: Icons.water_drop_rounded,
          color: _humColor(hum),
          min: _stats.minHumidity,
          avg: _stats.avgHumidity,
          max: _stats.maxHumidity,
          maxAllowed: 100,
        ),
        const SizedBox(height:16),

        // ── 4. Tren Historis Card ─────────────────────────────────────
        _buildChartCard(),
        const SizedBox(height:16),

        // ── 5. Log Anomali ────────────────────────────────────────────
        _buildAnomalyLog(),
      ]),
    );
  }

  Widget _buildChartCard() => _Card(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
    // Header
    Row(children:[
      Container(width:28,height:28,
        decoration:BoxDecoration(color:AppColors.primary.withValues(alpha:0.1),borderRadius:BorderRadius.circular(8)),
        child:const Icon(Icons.show_chart_rounded,color:AppColors.primary,size:16)),
      const SizedBox(width:10),
      const Expanded(child:Text('Tren Historis (24 Jam)',
        style:TextStyle(fontSize:14,fontWeight:FontWeight.w800,color:AppColors.textPrimary))),
      _PeriodSelector(selected:_period, onChanged:(p){ setState(()=>_period=p); _fetchHistory(); }),
    ]),
    const SizedBox(height:12),
    // Tab TEMP | HUMIDITY
    Row(children:[
      _ChartTab(label:'TEMP', active:_chartMetric=='temp', color:AppColors.primary,
        onTap:()=>setState(()=>_chartMetric='temp')),
      const SizedBox(width:8),
      _ChartTab(label:'HUMIDITY', active:_chartMetric=='humidity', color:const Color(0xFF0EA5E9),
        onTap:()=>setState(()=>_chartMetric='humidity')),
    ]),
    const SizedBox(height:16),
    // Chart area
    SizedBox(height:180,
      child: _loadingHistory
        ? const Center(child:CircularProgressIndicator(color:AppColors.primary,strokeWidth:2))
        : _history.isEmpty
          ? const Center(child:Text('Belum ada data historis',style:TextStyle(color:AppColors.textDim,fontSize:12)))
          : _LineChart(readings:_history, metric:_chartMetric)),
  ]));

  Widget _buildAnomalyLog() => _Card(child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
    Row(children:[
      Container(padding:const EdgeInsets.all(6),
        decoration:BoxDecoration(color:AppColors.warning.withValues(alpha:0.12),borderRadius:BorderRadius.circular(8)),
        child:const Icon(Icons.warning_amber_rounded,color:AppColors.warning,size:16)),
      const SizedBox(width:10),
      const Expanded(child:Text('Log Anomali',
        style:TextStyle(fontSize:14,fontWeight:FontWeight.w800,color:AppColors.textPrimary))),
      GestureDetector(onTap:(){},
        child:Row(mainAxisSize:MainAxisSize.min,children:[
          const Icon(Icons.picture_as_pdf_rounded,size:13,color:AppColors.primary),
          const SizedBox(width:4),
          const Text('PDF REPORT',style:TextStyle(fontSize:10,fontWeight:FontWeight.w800,color:AppColors.primary)),
        ])),
    ]),
    const SizedBox(height:14),
    // Table header
    Row(children:[
      Expanded(flex:2,child:Text('WAKTU',style:TextStyle(fontSize:9,fontWeight:FontWeight.w700,color:AppColors.textDim,letterSpacing:0.5))),
      Expanded(flex:2,child:Text('TINGKAT',style:TextStyle(fontSize:9,fontWeight:FontWeight.w700,color:AppColors.textDim,letterSpacing:0.5))),
      Expanded(flex:3,child:Text('DESKRIPSI',style:TextStyle(fontSize:9,fontWeight:FontWeight.w700,color:AppColors.textDim,letterSpacing:0.5))),
    ]),
    const Divider(height:14,color:Color(0xFFEEF0F8)),
    if (_anomalies.isEmpty)
      Padding(padding:const EdgeInsets.symmetric(vertical:16),
        child:Center(child:Text('Tidak ada anomali tercatat',style:TextStyle(color:AppColors.textDim,fontSize:12))))
    else ..._anomalies.take(5).map((n)=>_AnomalyRow(notif:n)),
    const SizedBox(height:8),
    Center(child:GestureDetector(onTap:(){},
      child:const Text('LIHAT SEMUA RIWAYAT',
        style:TextStyle(fontSize:11,fontWeight:FontWeight.w700,color:AppColors.primary)))),
  ]));

  Widget _buildAiTab() {
    if (_loadingAi) return const Center(child:CircularProgressIndicator(color:AppColors.primary,strokeWidth:2));
    if (_ai == null) {
      return Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      Icon(Icons.psychology_outlined,size:48,color:AppColors.textDim.withValues(alpha:0.4)),
      const SizedBox(height:12),
      const Text('Data AI belum tersedia',style:TextStyle(color:AppColors.textDim,fontSize:13)),
      const SizedBox(height:4),
      const Text('Diperlukan minimal 10 data pembacaan',style:TextStyle(color:AppColors.textDim,fontSize:11)),
      const SizedBox(height:20),
      ElevatedButton(onPressed:_fetchAi,
        style:ElevatedButton.styleFrom(backgroundColor:AppColors.primary,foregroundColor:Colors.white,
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),
        child:const Text('Refresh')),
    ]));
    }
    final ai=_ai!;
    final rc=AppColors.statusColor(ai.riskLevel);
    return ListView(padding:const EdgeInsets.all(16), children:[
      // Risk card
      Container(padding:const EdgeInsets.all(16),
        decoration:BoxDecoration(
          gradient:LinearGradient(colors:[rc.withValues(alpha:0.08),rc.withValues(alpha:0.03)]),
          borderRadius:BorderRadius.circular(16),
          border:Border.all(color:rc.withValues(alpha:0.25)),
        ),
        child:Row(children:[
          Container(width:48,height:48,decoration:BoxDecoration(color:rc.withValues(alpha:0.12),shape:BoxShape.circle),
            child:Icon(ai.riskLevel=='HIGH'?Icons.dangerous_rounded:ai.riskLevel=='MEDIUM'?Icons.warning_rounded:Icons.check_circle_rounded,color:rc,size:26)),
          const SizedBox(width:14),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(_riskLabel(ai.riskLevel),style:TextStyle(fontSize:16,fontWeight:FontWeight.w800,color:rc)),
            Text('Tingkat Risiko: ${ai.riskLevel}',style:TextStyle(fontSize:11,color:rc.withValues(alpha:0.7))),
          ])),
          Column(children:[
            Text('${ai.confidence}%',style:TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:rc)),
            const Text('Confidence',style:TextStyle(fontSize:9,color:AppColors.textDim)),
          ]),
        ])),
      const SizedBox(height:14),
      Row(children:[
        Expanded(child:_AiMetric(label:'Suhu Saat Ini',value:'${ai.currentTemp.toStringAsFixed(1)}°C',icon:Icons.thermostat_rounded,color:_tempColor(ai.currentTemp))),
        const SizedBox(width:10),
        Expanded(child:_AiMetric(label:'Prediksi 1j',value:'${ai.predictedTemp.toStringAsFixed(1)}°C',icon:Icons.trending_up_rounded,color:AppColors.primary)),
        const SizedBox(width:10),
        Expanded(child:_AiMetric(label:'Rata-rata',value:'${ai.avgTemp.toStringAsFixed(1)}°C',icon:Icons.analytics_rounded,color:AppColors.success)),
      ]),
      const SizedBox(height:14),
      _Card(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Z-Score Anomali',style:TextStyle(fontSize:13,fontWeight:FontWeight.w700,color:AppColors.textPrimary)),
        const SizedBox(height:12),
        _scoreRow('Temperatur',ai.zScoreTemp),
        const SizedBox(height:6),
        _scoreRow('Kelembapan',ai.zScoreHumidity),
      ])),
      if (ai.insights.isNotEmpty)...[
        const SizedBox(height:14),
        _Card(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Row(children:[
            Icon(Icons.lightbulb_outline_rounded,color:AppColors.warning,size:16),
            SizedBox(width:8),
            Text('Rekomendasi AI',style:TextStyle(fontSize:13,fontWeight:FontWeight.w700,color:AppColors.textPrimary)),
          ]),
          const SizedBox(height:10),
          ...ai.insights.map((ins)=>Padding(padding:const EdgeInsets.only(bottom:8),
            child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Container(width:6,height:6,margin:const EdgeInsets.only(top:5,right:10),
                decoration:const BoxDecoration(color:AppColors.primary,shape:BoxShape.circle)),
              Expanded(child:Text(ins,style:const TextStyle(fontSize:12,color:AppColors.textSecondary,height:1.4))),
            ]))),
        ])),
      ],
      const SizedBox(height:16),
    ]);
  }

  Widget _scoreRow(String label, double score) {
    final abs=score.abs();
    final color=abs>2?AppColors.danger:abs>1?AppColors.warning:AppColors.success;
    return Row(children:[
      Expanded(child:Text(label,style:const TextStyle(fontSize:12,color:AppColors.textSecondary))),
      Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:3),
        decoration:BoxDecoration(color:color.withValues(alpha:0.1),borderRadius:BorderRadius.circular(6)),
        child:Text(score.toStringAsFixed(2),style:TextStyle(fontSize:12,fontWeight:FontWeight.w700,color:color))),
    ]);
  }
  String _riskLabel(String l) { switch(l){case 'HIGH':return 'Risiko Tinggi';case 'MEDIUM':return 'Risiko Sedang';default:return 'Risiko Rendah';} }
}
// ─── END STATE CLASS ──────────────────────────────────────────────────────────

// ── _Card ────────────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE8EAF0)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.04), blurRadius:12, offset: const Offset(0,4))],
    ),
    child: child,
  );
}

// ── _InfoCard ─────────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final SensorNode node;
  final String status;
  const _InfoCard({required this.node, required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = node.isActive;
    final sc = isActive ? AppColors.success : AppColors.textDim;
    final ls = node.lastSeen;
    final kalStr = ls != null
      ? '${ls.toLocal().day} ${_mon(ls.toLocal().month)} ${ls.toLocal().year}'
      : '—';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EAF0)),
        boxShadow: [BoxShadow(color:Colors.black.withValues(alpha:0.05),blurRadius:12,offset:const Offset(0,4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Ikon sensor — lingkaran biru besar
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha:0.1),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withValues(alpha:0.2)),
            ),
            child: const Icon(Icons.sensors_rounded, color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Nama node — bold besar
            Text(node.nodeName,
              style: const TextStyle(fontSize:18, fontWeight:FontWeight.w900, color:AppColors.textPrimary, height:1.2)),
            const SizedBox(height:4),
            // Lokasi
            Text(node.location,
              style: const TextStyle(fontSize:12, color:AppColors.textSecondary)),
          ])),
          // Badge AKTIF
          Container(
            padding: const EdgeInsets.symmetric(horizontal:10, vertical:4),
            decoration: BoxDecoration(
              color: sc.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sc.withValues(alpha:0.35)),
            ),
            child: Row(mainAxisSize:MainAxisSize.min, children:[
              Container(width:7,height:7,decoration:BoxDecoration(color:sc,shape:BoxShape.circle)),
              const SizedBox(width:5),
              Text(isActive?'AKTIF':'MATI',
                style:TextStyle(fontSize:11,fontWeight:FontWeight.w800,color:sc,letterSpacing:0.5)),
            ]),
          ),
        ]),
        const SizedBox(height:16),
        const Divider(height:1,color:Color(0xFFEEF0F8)),
        const SizedBox(height:14),
        Row(children:[
          // IP ADDRESS
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('IP ADDRESS',
              style:TextStyle(fontSize:9,fontWeight:FontWeight.w700,color:AppColors.textDim,letterSpacing:0.6)),
            const SizedBox(height:4),
            Text(node.nodeId,
              style:const TextStyle(fontSize:13,fontWeight:FontWeight.w700,color:AppColors.primary)),
          ])),
          // TERAKHIR KALIBRASI
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('TERAKHIR KALIBRASI',
              style:TextStyle(fontSize:9,fontWeight:FontWeight.w700,color:AppColors.textDim,letterSpacing:0.6)),
            const SizedBox(height:4),
            Text(kalStr,
              style:const TextStyle(fontSize:13,fontWeight:FontWeight.w700,color:AppColors.textPrimary)),
          ])),
        ]),
      ]),
    );
  }
  String _mon(int m) { const b=['','Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des']; return b[m]; }
}

// ── _MetricCard ───────────────────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final String label, unit;
  final double? value;
  final IconData icon;
  final Color color;
  final double min, avg, max, maxAllowed;
  const _MetricCard({required this.label, required this.value, required this.unit,
    required this.icon, required this.color, required this.min, required this.avg,
    required this.max, required this.maxAllowed});

  @override
  Widget build(BuildContext context) {
    final progress = value != null ? (value! / maxAllowed).clamp(0.0,1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EAF0)),
        boxShadow: [BoxShadow(color:Colors.black.withValues(alpha:0.04),blurRadius:12,offset:const Offset(0,4))],
      ),
      child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
        // Label + ikon kanan
        Row(children:[
          Text(label, style:const TextStyle(fontSize:10,fontWeight:FontWeight.w700,color:AppColors.textDim,letterSpacing:0.5)),
          const Spacer(),
          Container(padding:const EdgeInsets.all(7),
            decoration:BoxDecoration(color:color.withValues(alpha:0.1),borderRadius:BorderRadius.circular(9)),
            child:Icon(icon,size:15,color:color)),
        ]),
        const SizedBox(height:6),
        // Nilai besar — misal 24.6°C
        RichText(text:TextSpan(children:[
          TextSpan(text: value!=null ? value!.toStringAsFixed(1) : '--',
            style:TextStyle(fontSize:36,fontWeight:FontWeight.w900,color:color,height:1.1)),
          TextSpan(text: unit,
            style:TextStyle(fontSize:18,fontWeight:FontWeight.w700,color:color.withValues(alpha:0.8))),
        ])),
        const SizedBox(height:10),
        // Progress bar biru
        ClipRRect(borderRadius:BorderRadius.circular(4),
          child:LinearProgressIndicator(
            value:progress,
            backgroundColor:const Color(0xFFF0F2FA),
            valueColor:AlwaysStoppedAnimation(color),
            minHeight:6,
          )),
        const SizedBox(height:10),
        // Min / Avg / Max bawah
        Row(children:[
          _MinMax(label:'Min',value:'${min.toStringAsFixed(1)}$unit',color:color.withValues(alpha:0.65)),
          _MinMax(label:'Avg',value:'${avg.toStringAsFixed(1)}$unit',color:color.withValues(alpha:0.8)),
          _MinMax(label:'Max',value:'${max.toStringAsFixed(1)}$unit',color:color),
        ]),
      ]),
    );
  }
}
class _MinMax extends StatelessWidget {
  final String label,value; final Color color;
  const _MinMax({required this.label,required this.value,required this.color});
  @override Widget build(BuildContext context) => Expanded(child:Column(children:[
    Text(value,style:TextStyle(fontSize:11,fontWeight:FontWeight.w700,color:color)),
    const SizedBox(height:2),
    Text(label,style:const TextStyle(fontSize:9,color:AppColors.textDim)),
  ]));
}

// ── _LineChart ────────────────────────────────────────────────────────────────
class _LineChart extends StatelessWidget {
  final List<SensorReading> readings;
  final String metric;
  const _LineChart({required this.readings, required this.metric});
  @override
  Widget build(BuildContext context) {
    final sorted = [...readings]..sort((a,b)=>a.timestamp.compareTo(b.timestamp));
    final spots = sorted.asMap().entries.map((e) {
      final val = metric=='temp' ? e.value.temperature : e.value.humidity;
      return FlSpot(e.key.toDouble(), val);
    }).toList();
    final lineColor = metric=='temp' ? AppColors.primary : const Color(0xFF0EA5E9);
    final yVals = spots.map((s)=>s.y).toList();
    final minY = yVals.isEmpty ? 0.0 : (yVals.reduce((a,b)=>a<b?a:b)-3).clamp(0.0,100.0);
    final maxY = yVals.isEmpty ? 50.0 : yVals.reduce((a,b)=>a>b?a:b)+3;
    return LineChart(LineChartData(
      minY:minY, maxY:maxY,
      gridData: FlGridData(show:true, drawVerticalLine:false,
        horizontalInterval:(maxY-minY)/4,
        getDrawingHorizontalLine:(_)=>const FlLine(color:Color(0xFFF0F2FA),strokeWidth:1)),
      borderData: FlBorderData(show:false),
      titlesData: FlTitlesData(
        leftTitles:   const AxisTitles(sideTitles:SideTitles(showTitles:false)),
        topTitles:    const AxisTitles(sideTitles:SideTitles(showTitles:false)),
        rightTitles:  const AxisTitles(sideTitles:SideTitles(showTitles:false)),
        bottomTitles: AxisTitles(sideTitles:SideTitles(
          showTitles:true, reservedSize:22,
          getTitlesWidget:(val,meta){
            if (spots.isEmpty) return const SizedBox.shrink();
            final step=(spots.length/5).ceil();
            if (val.toInt()%step!=0) return const SizedBox.shrink();
            final idx=val.toInt().clamp(0,sorted.length-1);
            final t=sorted[idx].timestamp.toLocal();
            return Text('${t.hour.toString().padLeft(2,"0")}:${t.minute.toString().padLeft(2,"0")}',
              style:const TextStyle(fontSize:8,color:AppColors.textDim));
          },
        )),
      ),
      lineBarsData:[LineChartBarData(
        spots:spots, isCurved:true, curveSmoothness:0.3,
        color:lineColor, barWidth:2.5,
        dotData:const FlDotData(show:false),
        belowBarData:BarAreaData(show:true,
          gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,
            colors:[lineColor.withValues(alpha:0.2),lineColor.withValues(alpha:0.0)])),
      )],
    ));
  }
}

// ── _AnomalyRow ───────────────────────────────────────────────────────────────
class _AnomalyRow extends StatelessWidget {
  final AppNotification notif;
  const _AnomalyRow({required this.notif});
  @override
  Widget build(BuildContext context) {
    final isCrit = notif.type=='critical';
    final color  = isCrit ? AppColors.danger : AppColors.warning;
    final ts     = notif.createdAt.toLocal();
    final mon    = ['','Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'][ts.month];
    final timeStr= '${ts.day}\n$mon,\n${ts.hour.toString().padLeft(2,"0")}:${ts.minute.toString().padLeft(2,"0")}';
    return Padding(padding:const EdgeInsets.symmetric(vertical:7),
      child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Expanded(flex:2,child:Text(timeStr,style:const TextStyle(fontSize:9,color:AppColors.textSecondary,height:1.5))),
        Expanded(flex:2,child:Container(
          padding:const EdgeInsets.symmetric(horizontal:6,vertical:3),
          decoration:BoxDecoration(color:color.withValues(alpha:0.1),borderRadius:BorderRadius.circular(6)),
          child:Text(isCrit?'CRITICAL':'WARNING',
            style:TextStyle(fontSize:9,fontWeight:FontWeight.w800,color:color)))),
        Expanded(flex:3,child:Text(notif.message,
          style:const TextStyle(fontSize:9,color:AppColors.textSecondary,height:1.4),
          maxLines:3,overflow:TextOverflow.ellipsis)),
      ]));
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────
class _ChartTab extends StatelessWidget {
  final String label; final bool active; final Color color; final VoidCallback onTap;
  const _ChartTab({required this.label,required this.active,required this.color,required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(onTap:onTap,
    child:Container(padding:const EdgeInsets.symmetric(horizontal:14,vertical:6),
      decoration:BoxDecoration(
        color:active?color:Colors.transparent,
        borderRadius:BorderRadius.circular(8),
        border:Border.all(color:active?color:const Color(0xFFE8EAF0)),
      ),
      child:Text(label,style:TextStyle(fontSize:11,fontWeight:FontWeight.w700,
        color:active?Colors.white:AppColors.textDim))));
}

class _PeriodSelector extends StatelessWidget {
  final String selected; final Function(String) onChanged;
  const _PeriodSelector({required this.selected,required this.onChanged});
  @override Widget build(BuildContext context) => Row(mainAxisSize:MainAxisSize.min,
    children:['24h','7d','30d'].map((p)=>GestureDetector(onTap:()=>onChanged(p),
      child:Container(margin:const EdgeInsets.only(left:4),
        padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
        decoration:BoxDecoration(
          color:selected==p?AppColors.primary:Colors.transparent,
          borderRadius:BorderRadius.circular(6),
          border:Border.all(color:selected==p?AppColors.primary:const Color(0xFFE8EAF0)),
        ),
        child:Text(p,style:TextStyle(fontSize:10,fontWeight:FontWeight.w700,
          color:selected==p?Colors.white:AppColors.textDim))))).toList());
}

class _AiMetric extends StatelessWidget {
  final String label,value; final IconData icon; final Color color;
  const _AiMetric({required this.label,required this.value,required this.icon,required this.color});
  @override Widget build(BuildContext context) => Container(
    padding:const EdgeInsets.all(12),
    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
      border:Border.all(color:color.withValues(alpha:0.2)),
      boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.03),blurRadius:8,offset:const Offset(0,2))]),
    child:Column(children:[
      Icon(icon,size:20,color:color),
      const SizedBox(height:6),
      Text(value,style:TextStyle(fontSize:14,fontWeight:FontWeight.w900,color:color)),
      const SizedBox(height:2),
      Text(label,style:const TextStyle(fontSize:9,color:AppColors.textDim),textAlign:TextAlign.center),
    ]));
}
