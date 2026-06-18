class AppUser {
  final int id;
  final String ipAddress;
  final String name;
  final String role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final String? lastIp;

  const AppUser({
    required this.id,
    required this.ipAddress,
    required this.name,
    required this.role,
    required this.isActive,
    required this.createdAt,
    this.lastLogin,
    this.lastIp,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] ?? 0,
        ipAddress: j['ip_address'] ?? '',
        name: j['name'] ?? '',
        role: j['role'] ?? 'pic',
        isActive: j['is_active'] == 1 || j['is_active'] == true,
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
        lastLogin: j['last_login'] != null
            ? DateTime.tryParse(j['last_login'].toString())
            : null,
        lastIp: j['last_ip'],
      );

  bool get isAdmin => role == 'admin';
}
