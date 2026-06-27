import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/app_provider.dart';
import '../../shared/widgets/interactive.dart';
import '../../shared/widgets/mesh_background.dart';
import '../dashboard/main_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _ipCtrl   = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _storage  = const FlutterSecureStorage();
  bool _obscure   = true;
  String _detectedIp = '';
  RawDatagramSocket? _udpSocket;

  @override
  void initState() {
    super.initState();
    _storage.read(key: 'server_ip').then((ip) {
      if (ip != null && ip.isNotEmpty && mounted) _ipCtrl.text = ip;
    });
    _startUdpDiscovery();
  }

  /// UDP broadcast discovery — backend kirim beacon ke port 47808 setiap 5 detik
  Future<void> _startUdpDiscovery() async {
    try {
      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4, 47808,
        reuseAddress: true,
      );
      _udpSocket!.broadcastEnabled = true;
      _udpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = _udpSocket!.receive();
          if (dg == null) return;
          try {
            final msg = jsonDecode(utf8.decode(dg.data)) as Map<String, dynamic>;
            if (msg['susemon'] == true) {
              final ip = msg['ip'] as String? ?? '';
              if (ip.isNotEmpty && ip != _detectedIp && mounted) {
                setState(() => _detectedIp = ip);
                // Auto-fill jika field kosong
                if (_ipCtrl.text.isEmpty) _ipCtrl.text = ip;
              }
            }
          } catch (_) {}
        }
      });
    } catch (_) {
      // UDP tidak tersedia di platform ini — tidak masalah
    }
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _codeCtrl.dispose();
    _udpSocket?.close();
    super.dispose();
  }

  Future<void> _login() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_ipCtrl.text.trim(), _codeCtrl.text.trim());
    if (!mounted) return;
    if (ok) {
      context.read<SensorProvider>().start();
      context.read<NotificationProvider>().start();
      context.read<AiProvider>().start();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainLayout()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: MeshBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildForm(auth),
                  const SizedBox(height: 16),
                  _buildSystemStatus(),
                  const SizedBox(height: 24),
                  Text(
                    '© 2024 SUSEMON Intelligence',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Logo circle
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.08),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: const Icon(Icons.sensors, size: 36, color: AppColors.primary),
        ),
        const SizedBox(height: 16),
        const Text(
          'SUSEMON',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Infrastructure Monitoring System',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildForm(AuthProvider auth) {
    return GlassCard(
      radius: 16,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // IP Address field
          _buildLabel('ALAMAT SERVER'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _ipCtrl,
            hint: 'Contoh: 192.168.1.100',
            icon: Icons.router_outlined,
            obscure: false,
          ),
          const SizedBox(height: 16),

          // Access Code field
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLabel('ACCESS CODE'),
              GestureDetector(
                onTap: () {},
                child: const Text(
                  'Lupa kode?',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _codeCtrl,
            hint: '••••••••',
            icon: Icons.lock_outline,
            obscure: _obscure,
            suffix: IconButton(
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.outline,
                size: 20,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),

          // Error message
          if (auth.error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      auth.error!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Login button
          TapScale(
            scale: 0.97,
            onTap: auth.loading
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    _login();
                  },
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryContainer],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: auth.loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Masuk',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.login, color: Colors.white, size: 18),
                        ],
                      ),
              ),
            ),
          ),

          const SizedBox(height: 20),
          Divider(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 12),

          // Default credentials hint
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 14,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Akun Default',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary.withValues(alpha: 0.8),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _hintRow('Lokal', '127.0.0.1  ·  ADMIN123'),
          _hintRow('Jaringan', _detectedIp.isNotEmpty ? '$_detectedIp  ·  SUSEMON2026' : 'Auto-detecting...'),
          if (_detectedIp.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TapScale(
                onTap: () {
                  setState(() => _ipCtrl.text = _detectedIp);
                  HapticFeedback.selectionClick();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.wifi_find_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text('Gunakan IP terdeteksi: $_detectedIp',
                        style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_rounded, size: 13, color: AppColors.primary),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool obscure,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(
        color: AppColors.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: AppColors.outline.withValues(alpha: 0.5),
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: AppColors.outline, size: 18),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildSystemStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF22C55E),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Sistem Aktif',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hintRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: TextStyle(fontSize: 11, color: AppColors.textDim),
          ),
        ),
        Text(
          ': $value',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.onSurface,
            fontFamily: 'monospace',
          ),
        ),
      ],
    ),
  );
}
