import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/app_provider.dart';
import '../dashboard/main_layout.dart';

/// V380 Pro style login: IP Address + Access Code
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _ipCtrl   = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _storage  = const FlutterSecureStorage();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    // Isi field IP dari IP terakhir yang berhasil login
    _storage.read(key: 'server_ip').then((ip) {
      if (ip != null && ip.isNotEmpty && mounted) {
        _ipCtrl.text = ip;
      }
    });
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_ipCtrl.text.trim(), _codeCtrl.text.trim());
    if (!mounted) return;
    if (ok) {
      // Start providers setelah login
      context.read<SensorProvider>().start();
      context.read<NotificationProvider>().start();
      context.read<AiProvider>().start();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainLayout()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const SizedBox(height: 48),
              // Logo
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.bgCard,
                  border: Border.all(color: AppColors.primary, width: 2),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 30, spreadRadius: 6)],
                ),
                child: const Icon(Icons.sensors, size: 42, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              const Text('SUSEMON',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 5)),
              const SizedBox(height: 4),
              Text('Server Room Monitoring', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 48),

              // Form
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Masuk ke Sistem',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('Gunakan IP Address & Access Code perangkat',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 24),

                    // IP Address field
                    _field('IP Address', _ipCtrl, Icons.router_outlined, false,
                        hint: 'Contoh: 192.168.1.100'),
                    const SizedBox(height: 14),

                    // Access Code field
                    _field('Access Code', _codeCtrl, Icons.vpn_key_outlined, _obscure,
                        hint: 'XXXXXXXX',
                        suffix: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                              color: AppColors.textSecondary, size: 20),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        )),

                    // Error
                    if (auth.error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline, color: AppColors.danger, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(auth.error!,
                              style: const TextStyle(fontSize: 12, color: AppColors.danger))),
                        ]),
                      ),
                    ],

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton(
                        onPressed: auth.loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: auth.loading
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Masuk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Hint
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.info_outline, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text('Akun Default', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ]),
                    const SizedBox(height: 8),
                    _hintRow('Lokal', '127.0.0.1  ·  ADMIN123'),
                    _hintRow('Jaringan', '[IP laptop]  ·  SUSEMON2026'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('PBL-TRPL412 · Politeknik Negeri Batam',
                  style: TextStyle(fontSize: 11, color: AppColors.textDim)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon, bool obscure,
      {String? hint, Widget? suffix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textDim, fontSize: 13),
            prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 18),
            suffixIcon: suffix,
            filled: true,
            fillColor: AppColors.bgCardAlt,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.cardBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.cardBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primary)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _hintRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(children: [
      SizedBox(width: 40, child: Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary))),
      Text(': $value', style: const TextStyle(fontSize: 11, color: Colors.white, fontFamily: 'monospace')),
    ]),
  );
}
