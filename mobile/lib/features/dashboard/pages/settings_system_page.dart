import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../providers/app_provider.dart';
import '../../../services/api_service.dart';
import 'users_page.dart';
import '../../auth/login_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// SettingsSystemPage — Pengaturan Sistem (sesuai desain mockup)
// Dibuka dari ikon settings di AppBar setiap halaman
// ══════════════════════════════════════════════════════════════════════════════

class SettingsSystemPage extends StatefulWidget {
  const SettingsSystemPage({super.key});
  @override
  State<SettingsSystemPage> createState() => _SettingsSystemPageState();
}

class _SettingsSystemPageState extends State<SettingsSystemPage> {
  int _activeTab = 0; // 0=MQTT, 1=Gateway, 2=LoRa, 3=AI, 4=Users, 5=Profile

  // MQTT form fields
  final _brokerCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _clientIdCtrl = TextEditingController();
  final _keepAliveCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _topicCtrl = TextEditingController();
  final _downlinkTopicCtrl = TextEditingController();

  // Gateway form fields
  final _gwIpCtrl = TextEditingController();
  final _gwApiKeyCtrl = TextEditingController();

  // LoRa form fields
  final _loraFreqCtrl = TextEditingController();
  String _selectedDatr = 'SF7BW125';
  String _selectedCodr = '4/5';

  // AI form fields
  final _tempWarningCtrl = TextEditingController();
  final _tempDangerCtrl = TextEditingController();
  final _humWarningCtrl = TextEditingController();
  final _humDangerCtrl = TextEditingController();

  bool _authEnabled = true;
  bool _obscurePass = true;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final api = context.read<ApiService>();
      final settings = await api.getSystemSettings();
      setState(() {
        _brokerCtrl.text = settings['mqtt_broker'] ?? 'localhost';
        _portCtrl.text = settings['mqtt_port'] ?? '1883';
        _clientIdCtrl.text = settings['mqtt_client_id'] ?? 'susemon-fastapi';
        _keepAliveCtrl.text = settings['mqtt_keep_alive'] ?? '60';
        _usernameCtrl.text = settings['mqtt_user'] ?? '';
        _passwordCtrl.text = settings['mqtt_pass'] ?? '';
        _authEnabled = (settings['mqtt_user'] ?? '').isNotEmpty;

        _topicCtrl.text = settings['mqtt_topic'] ?? 'sensor/data';
        _downlinkTopicCtrl.text = settings['mqtt_downlink_topic'] ?? 'sensor/ai_result';

        _gwIpCtrl.text = settings['gateway_ip'] ?? '10.130.1.1';
        _gwApiKeyCtrl.text = settings['gateway_api_key'] ?? '';

        _loraFreqCtrl.text = settings['lora_freq'] ?? '915000000';
        _selectedDatr = settings['lora_datr'] ?? 'SF7BW125';
        _selectedCodr = settings['lora_codr'] ?? '4/5';

        _tempWarningCtrl.text = settings['temp_warning'] ?? '35';
        _tempDangerCtrl.text = settings['temp_danger'] ?? '40';
        _humWarningCtrl.text = settings['hum_warning'] ?? '80';
        _humDangerCtrl.text = settings['hum_danger'] ?? '85';

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal memuat pengaturan: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isLoading = true;
    });
    try {
      final api = context.read<ApiService>();
      final Map<String, dynamic> payload = {
        'mqtt_broker': _brokerCtrl.text.trim(),
        'mqtt_port': _portCtrl.text.trim(),
        'mqtt_client_id': _clientIdCtrl.text.trim(),
        'mqtt_keep_alive': _keepAliveCtrl.text.trim(),
        'mqtt_user': _authEnabled ? _usernameCtrl.text.trim() : '',
        'mqtt_pass': _authEnabled ? _passwordCtrl.text : '',
        'mqtt_topic': _topicCtrl.text.trim(),
        'mqtt_downlink_topic': _downlinkTopicCtrl.text.trim(),
        'gateway_ip': _gwIpCtrl.text.trim(),
        'gateway_api_key': _gwApiKeyCtrl.text.trim(),
        'lora_freq': _loraFreqCtrl.text.trim(),
        'lora_datr': _selectedDatr,
        'lora_codr': _selectedCodr,
        'temp_warning': _tempWarningCtrl.text.trim(),
        'temp_danger': _tempDangerCtrl.text.trim(),
        'hum_warning': _humWarningCtrl.text.trim(),
        'hum_danger': _humDangerCtrl.text.trim(),
      };
      await api.updateSystemSettings(payload);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semua konfigurasi berhasil disimpan dan diterapkan!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadSettings();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _brokerCtrl.dispose();
    _portCtrl.dispose();
    _clientIdCtrl.dispose();
    _keepAliveCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _topicCtrl.dispose();
    _downlinkTopicCtrl.dispose();
    _gwIpCtrl.dispose();
    _gwApiKeyCtrl.dispose();
    _loraFreqCtrl.dispose();
    _tempWarningCtrl.dispose();
    _tempDangerCtrl.dispose();
    _humWarningCtrl.dispose();
    _humDangerCtrl.dispose();
    super.dispose();
  }

  static const _tabs = [
    _TabItem(icon: Icons.router_rounded, label: 'MQTT'),
    _TabItem(icon: Icons.hub_rounded, label: 'GATEWAY'),
    _TabItem(icon: Icons.settings_input_antenna, label: 'LORA'),
    _TabItem(icon: Icons.psychology_rounded, label: 'AI'),
    _TabItem(icon: Icons.people_rounded, label: 'USERS'),
    _TabItem(icon: Icons.person_rounded, label: 'PROFILE'),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5FA),
      body: Column(
        children: [
          // ── AppBar ──────────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0058BE),
              boxShadow: [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.maybePop(context);
                      },
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pengaturan',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          'Sistem',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Notif
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.notifications_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    // Avatar + name
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1D4ED8),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          auth.userName ?? 'Admin',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── 6-tab icon grid ──────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: _tabs.asMap().entries.map((e) {
                final selected = e.key == _activeTab;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _activeTab = e.key);
                    },
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : const Color(0xFFF0F4FA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            e.value.icon,
                            size: 20,
                            color: selected ? Colors.white : AppColors.textDim,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          e.value.label,
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textDim,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          Expanded(child: _buildTabContent()),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!, style: const TextStyle(color: AppColors.danger), textAlign: TextAlign.center),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _loadSettings,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    switch (_activeTab) {
      case 0:
        return _buildMqttTab();
      case 1:
        return _buildGatewayTab();
      case 2:
        return _buildLoraTab();
      case 3:
        return _buildAiTab();
      case 4:
        return _buildUsersTab();
      case 5:
        return _buildProfileTab();
      default:
        return _buildComingSoon(_tabs[_activeTab].label);
    }
  }

  // ── MQTT Tab ──────────────────────────────────────────────────────────────
  Widget _buildMqttTab() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
    children: [
      // Konfigurasi MQTT Broker card
      _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.router_rounded, color: AppColors.primary, size: 18),
                SizedBox(width: 8),
                Text(
                  'Konfigurasi MQTT Broker',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _FieldLabel('BROKER ADDRESS'),
            _TextField(controller: _brokerCtrl),
            const SizedBox(height: 12),
            _FieldLabel('PORT'),
            _TextField(
              controller: _portCtrl,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _FieldLabel('CLIENT ID'),
            _TextField(controller: _clientIdCtrl),
            const SizedBox(height: 12),
            _FieldLabel('KEEP ALIVE (SECS)'),
            _TextField(
              controller: _keepAliveCtrl,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _FieldLabel('MQTT UPLINK TOPIC'),
            _TextField(controller: _topicCtrl),
            const SizedBox(height: 12),
            _FieldLabel('MQTT DOWNLINK TOPIC'),
            _TextField(controller: _downlinkTopicCtrl),
            const SizedBox(height: 16),
            // Aktifkan Autentikasi toggle
            GestureDetector(
              onTap: () => setState(() => _authEnabled = !_authEnabled),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _authEnabled ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: _authEnabled
                            ? AppColors.primary
                            : const Color(0xFFD1D5DB),
                      ),
                    ),
                    child: _authEnabled
                        ? const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Aktifkan Autentikasi',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (_authEnabled) ...[
              const SizedBox(height: 12),
              _FieldLabel('USERNAME'),
              _TextField(controller: _usernameCtrl),
              const SizedBox(height: 12),
              _FieldLabel('PASSWORD'),
              _TextField(
                controller: _passwordCtrl,
                obscure: _obscurePass,
                suffix: GestureDetector(
                  onTap: () => setState(() => _obscurePass = !_obscurePass),
                  child: Icon(
                    _obscurePass
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 16,
                    color: AppColors.textDim,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            _buildSaveButtons(),
          ],
        ),
      ),
    ],
  );

  // ── Gateway Tab ────────────────────────────────────────────────────────────
  Widget _buildGatewayTab() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
    children: [
      _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.hub_rounded, color: AppColors.primary, size: 18),
                SizedBox(width: 8),
                Text(
                  'Konfigurasi Gateway LoRa',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _FieldLabel('GATEWAY IP ADDRESS'),
            _TextField(controller: _gwIpCtrl),
            const SizedBox(height: 12),
            _FieldLabel('GATEWAY API KEY / SECURITY KEY'),
            _TextField(controller: _gwApiKeyCtrl),
            const SizedBox(height: 20),
            _buildSaveButtons(),
          ],
        ),
      ),
    ],
  );

  // ── LoRa Tab ───────────────────────────────────────────────────────────────
  Widget _buildLoraTab() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
    children: [
      _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.settings_input_antenna, color: AppColors.primary, size: 18),
                SizedBox(width: 8),
                Text(
                  'Konfigurasi LoRa Radio',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _FieldLabel('FREKUENSI LORA (HZ)'),
            _TextField(
              controller: _loraFreqCtrl,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _FieldLabel('LORA DATARATE / SPREADING FACTOR'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE8EAF0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedDatr,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'SF7BW125', child: Text('SF7 BW 125kHz')),
                    DropdownMenuItem(value: 'SF8BW125', child: Text('SF8 BW 125kHz')),
                    DropdownMenuItem(value: 'SF9BW125', child: Text('SF9 BW 125kHz')),
                    DropdownMenuItem(value: 'SF10BW125', child: Text('SF10 BW 125kHz')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedDatr = v);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            _FieldLabel('LORA CODING RATE (CR)'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE8EAF0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCodr,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: '4/5', child: Text('4/5')),
                    DropdownMenuItem(value: '4/6', child: Text('4/6')),
                    DropdownMenuItem(value: '4/7', child: Text('4/7')),
                    DropdownMenuItem(value: '4/8', child: Text('4/8')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedCodr = v);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildSaveButtons(),
          ],
        ),
      ),
    ],
  );

  // ── AI Tab ─────────────────────────────────────────────────────────────────
  Widget _buildAiTab() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
    children: [
      _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.psychology_rounded, color: AppColors.primary, size: 18),
                SizedBox(width: 8),
                Text(
                  'Konfigurasi Threshold AI',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _FieldLabel('BATAS PERINGATAN SUHU (WARNING °C)'),
            _TextField(
              controller: _tempWarningCtrl,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _FieldLabel('BATAS KRITIS SUHU (DANGER °C)'),
            _TextField(
              controller: _tempDangerCtrl,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _FieldLabel('BATAS PERINGATAN KELEMBAPAN (WARNING %)'),
            _TextField(
              controller: _humWarningCtrl,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _FieldLabel('BATAS KRITIS KELEMBAPAN (DANGER %)'),
            _TextField(
              controller: _humDangerCtrl,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            _buildSaveButtons(),
          ],
        ),
      ),
    ],
  );

  Widget _buildSaveButtons() => Row(
    children: [
      Expanded(
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD1D5DB)),
            ),
            child: const Center(
              child: Text(
                'Batal',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        flex: 2,
        child: GestureDetector(
          onTap: _saveSettings,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'Simpan Perubahan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  // ── Users Tab (simple) ────────────────────────────────────────────────────
  Widget _buildUsersTab() {
    final auth = context.watch<AuthProvider>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Manajemen Pengguna',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              if (!auth.isAdmin)
                const Text(
                  'Hanya Admin yang dapat mengelola pengguna.',
                  style: TextStyle(fontSize: 12, color: AppColors.textDim),
                )
              else ...[
                Text(
                  'Login sebagai: ${auth.userName ?? 'Admin'} (${auth.role})',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UsersPage()),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text(
                        'Kelola Pengguna',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Profile Tab ───────────────────────────────────────────────────────────
  Widget _buildProfileTab() {
    final auth = context.watch<AuthProvider>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Card(
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFF1D4ED8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                auth.userName ?? 'Admin',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  auth.role.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFEEF0F8), height: 1),
              const SizedBox(height: 12),
              _infoRow('Versi', 'v2.1.0'),
              _infoRow('Build', 'PBL-TRPL412'),
              _infoRow('Platform', 'Flutter'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Logout
        GestureDetector(
          onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Keluar'),
                content: const Text('Yakin ingin keluar?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Batal'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      'Keluar',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            );
            if (ok == true && mounted) {
              context.read<SensorProvider>().stop();
              context.read<NotificationProvider>().stop();
              context.read<AiProvider>().stop();
              context.read<AuthProvider>().logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, size: 18, color: AppColors.danger),
                SizedBox(width: 8),
                Text(
                  'Keluar dari Sistem',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComingSoon(String label) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.construction_rounded,
          size: 48,
          color: AppColors.textDim.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 12),
        Text(
          'Tab $label',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Segera hadir',
          style: TextStyle(fontSize: 12, color: AppColors.textDim),
        ),
      ],
    ),
  );

  Widget _infoRow(String l, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Text(l, style: const TextStyle(fontSize: 12, color: AppColors.textDim)),
        const Spacer(),
        Text(
          v,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    ),
  );
}

// ── Helper Widgets ─────────────────────────────────────────────────────────────

class _TabItem {
  final IconData icon;
  final String label;
  const _TabItem({required this.icon, required this.label});
}

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
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        color: AppColors.textDim,
        letterSpacing: 0.5,
      ),
    ),
  );
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffix;
  const _TextField({
    required this.controller,
    this.obscure = false,
    this.keyboardType,
    this.suffix,
  });
  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F9FC),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE8EAF0)),
    ),
    child: Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        if (suffix != null) suffix!,
      ],
    ),
  );
}
