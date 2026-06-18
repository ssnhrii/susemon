import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/user_model.dart';
import '../../../services/api_service.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  List<AppUser> _users = [];
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
      _users = await api.getUsers();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showAddDialog() async {
    final ipCtrl   = TextEditingController();
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    String role = 'pic';

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Tambah User', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            _field('IP Address', ipCtrl, hint: '192.168.1.x atau 0.0.0.0'),
            const SizedBox(height: 10),
            _field('Nama', nameCtrl, hint: 'Nama pengguna'),
            const SizedBox(height: 10),
            _field('Access Code', codeCtrl, hint: 'Min 6 karakter'),
            const SizedBox(height: 10),
            Row(children: [
              const Text('Role:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(width: 12),
              ChoiceChip(
                label: const Text('PIC'),
                selected: role == 'pic',
                onSelected: (_) => setS(() => role = 'pic'),
                selectedColor: AppColors.primary.withOpacity(0.2),
                labelStyle: TextStyle(color: role == 'pic' ? AppColors.primary : AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Admin'),
                selected: role == 'admin',
                onSelected: (_) => setS(() => role = 'admin'),
                selectedColor: AppColors.warning.withOpacity(0.2),
                labelStyle: TextStyle(color: role == 'admin' ? AppColors.warning : AppColors.textSecondary, fontSize: 12),
              ),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: Text('Batal', style: TextStyle(color: AppColors.textSecondary))),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await context.read<ApiService>().createUser({
                    'ip_address': ipCtrl.text.trim(),
                    'name': nameCtrl.text.trim(),
                    'access_code': codeCtrl.text.trim(),
                    'role': role,
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
      ),
    );
  }

  Future<void> _deleteUser(AppUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Hapus User', style: TextStyle(color: Colors.white)),
        content: Text('Hapus user "${user.name}"?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('Batal', style: TextStyle(color: AppColors.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await context.read<ApiService>().deleteUser(user.id);
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
                  Text('Manajemen User', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                  Text('Kelola akses pengguna sistem', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ]),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.person_add_rounded, color: AppColors.primary),
                  onPressed: _showAddDialog,
                  tooltip: 'Tambah User',
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
                            itemCount: _users.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _UserCard(
                              user: _users[i],
                              onDelete: () => _deleteUser(_users[i]),
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
          borderSide: BorderSide(color: AppColors.cardBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.cardBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
  );
}

class _UserCard extends StatelessWidget {
  final AppUser user;
  final VoidCallback onDelete;
  const _UserCard({required this.user, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final roleColor = user.isAdmin ? AppColors.warning : AppColors.primary;
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
            color: roleColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(user.isAdmin ? Icons.admin_panel_settings : Icons.person,
              color: roleColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(user.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: roleColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
              child: Text(user.role.toUpperCase(),
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: roleColor)),
            ),
            if (!user.isActive) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: const Text('NONAKTIF', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.danger)),
              ),
            ],
          ]),
          const SizedBox(height: 2),
          Text(user.ipAddress, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'monospace')),
          if (user.lastLogin != null)
            Text('Login terakhir: ${_fmt(user.lastLogin!)}',
                style: const TextStyle(fontSize: 10, color: AppColors.textDim)),
        ])),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
          onPressed: onDelete,
        ),
      ]),
    );
  }

  String _fmt(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
