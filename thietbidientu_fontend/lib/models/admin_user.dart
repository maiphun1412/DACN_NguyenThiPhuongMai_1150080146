// lib/models/admin_user.dart
class AdminUser {
  final int userId;
  final String email;
  final String fullName;
  final String? phone;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String role;       // 'customer' | 'shipper' | 'admin'
  final String? banReason;

  AdminUser({
    required this.userId,
    required this.email,
    required this.fullName,
    this.phone,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    required this.role,
    this.banReason,
  });

  factory AdminUser.fromJson(Map<String, dynamic> j) {
    DateTime? _dt(v) => v == null ? null : DateTime.tryParse(v.toString());

    return AdminUser(
      userId: int.tryParse(j['UserID'].toString()) ?? 0,
      email: j['Email'] ?? '',
      fullName: j['FullName'] ?? '',
      phone: j['Phone'],
      isActive: (j['IsActive'] is bool)
          ? j['IsActive'] as bool
          : (j['IsActive']?.toString() == '1' ||
              j['IsActive']?.toString().toLowerCase() == 'true'),
      createdAt: _dt(j['CreatedAt']),
      updatedAt: _dt(j['UpdatedAt']),
      role: (j['Role'] ?? 'customer').toString(),
      banReason: j['BanReason'],
    );
  }
}
