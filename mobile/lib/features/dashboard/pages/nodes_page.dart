import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/sensor_model.dart';
import '../../../services/api_service.dart';

class NodesPage extends StatefulWidget {
  const NodesPage({super.key});
  @override
  State<NodesPage> createState() => _NodesPageState();
}

class _NodesPageState extends State<NodesPage> {
  List<SensorNode> _nodes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<ApiService>();
      _nodes = await api.getNodes();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showAddDialog() async {
    final idCtrl   = TextEditingController();
    final nameCtrl = TextEditingController();
    final locCtrl  = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tambah Perangkat', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _field('Node ID (Unique)', idCtrl, hint: 'Contoh: A1, B2, C3'),
          const SizedBox(height: 10),
          _field('Nama Perangkat', nameCtrl, hint: 'Contoh: Node Sensor A1'),
          const SizedBox(height: 10),
          _field('Lokasi', locCtrl, hint: 'Contoh: Rack Server Utama'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () async {
              if (idCtrl.text.isEmpty || nameCtrl.text.isEmpty || locCtrl.text.isEmpty) return;
              Navigator.pop(context);
              try {
                await context.read<ApiService>().createNode({
                  'node_id': idCtrl.text.trim().toUpperCase(),
                  'node_name': nameCtrl.text.trim(),
                  'location': locCtrl.text.trim(),
                  'is_active': true,
                });
                _fetch();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')),
                        backgroundColor: AppColors.danger),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNode(SensorNode node) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Hapus Perangkat', style: TextStyle(color: Colors.white)),
        content: Text('Hapus perangkat "${node.nodeName}" (${node.nodeId})? Semua riwayat data juga akan terhapus.',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await context.read<ApiService>().deleteNode(node.nodeId);
        _fetch();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')),
                backgroundColor: AppColors.danger),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: AppColors.bgCard,
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Manajemen Perangkat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                  Text('Kelola node sensor IoT', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ]),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_to_queue_rounded, color: AppColors.primary),
                  onPressed: _showAddDialog,
                  tooltip: 'Tambah Perangkat',
                ),
              ]),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.danger)))
                      : RefreshIndicator(
                          onRefresh: _fetch,
                          color: AppColors.primary,
                          backgroundColor: AppColors.bgCard,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _nodes.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _NodeCard(
                              node: _nodes[i],
                              onDelete: () => _deleteNode(_nodes[i]),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {String? hint}) => TextField(
    controller: ctrl,
    style: const TextStyle(color: Colors.white, fontSize: 13),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      hintStyle: const TextStyle(color: AppColors.textDim, fontSize: 12),
      filled: true,
      fillColor: AppColors.bgCardAlt,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.cardBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.cardBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
  );
}

class _NodeCard extends StatelessWidget {
  final SensorNode node;
  final VoidCallback onDelete;
  const _NodeCard({required this.node, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.sensors, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(node.nodeName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
              child: Text(node.nodeId,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
          ]),
          const SizedBox(height: 2),
          Text(node.location, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ])),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
          onPressed: onDelete,
        ),
      ]),
    );
  }
}
