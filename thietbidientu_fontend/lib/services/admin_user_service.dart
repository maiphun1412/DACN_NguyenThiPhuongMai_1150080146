// lib/services/admin_user_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/admin_user.dart';

class AdminUserService {
  static Future<List<AdminUser>> fetchUsers({String? keyword}) async {
    final base = await AppConfig.ensureBaseUrl();
    final query = (keyword != null && keyword.trim().isNotEmpty)
        ? '?q=${Uri.encodeQueryComponent(keyword.trim())}'
        : '';
    final url = Uri.parse('$base/api/admin/users$query');

    final r = await http.get(url, headers: {'Accept': 'application/json'});
    if (r.statusCode != 200) {
      throw Exception('Lỗi tải người dùng: HTTP ${r.statusCode}');
    }

    final List data = json.decode(r.body) as List;
    return data.map((e) => AdminUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<AdminUser> fetchDetail(int id) async {
    final base = await AppConfig.ensureBaseUrl();
    final url = Uri.parse('$base/api/admin/users/$id');

    final r = await http.get(url, headers: {'Accept': 'application/json'});
    if (r.statusCode != 200) {
      throw Exception('Lỗi tải chi tiết người dùng: HTTP ${r.statusCode}');
    }

    final data = json.decode(r.body) as Map<String, dynamic>;
    return AdminUser.fromJson(data);
  }

  static Future<AdminUser> updateBanStatus({
    required int userId,
    required bool isActive,
    String? reason,
  }) async {
    final base = await AppConfig.ensureBaseUrl();
    final url = Uri.parse('$base/api/admin/users/$userId/ban');

    final r = await http.put(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'isActive': isActive,
        'reason': reason,
      }),
    );

    if (r.statusCode != 200) {
      throw Exception('Lỗi cập nhật trạng thái: HTTP ${r.statusCode}');
    }

    final data = json.decode(r.body) as Map<String, dynamic>;
    return AdminUser.fromJson(data);
  }

  static Future<AdminUser> updateRole({
    required int userId,
    required String role,
  }) async {
    final base = await AppConfig.ensureBaseUrl();
    final url = Uri.parse('$base/api/admin/users/$userId/role');

    final r = await http.put(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'role': role,
      }),
    );

    if (r.statusCode != 200) {
      throw Exception('Lỗi cập nhật role: HTTP ${r.statusCode}');
    }

    final data = json.decode(r.body) as Map<String, dynamic>;
    return AdminUser.fromJson(data);
  }
}
