// lib/services/auth_storage.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  // Khóa "chuẩn"
  static const String _kAccess  = 'access_token';
  static const String _kRefresh = 'refresh_token';
  static const String _kUser    = 'user_json';
  static const String _kRole    = 'role'; // 👈 thêm

  // Các alias cũ để tương thích ngược
  static const List<String> _legacyAccessKeys = [
    'token',
    'accessToken',
    'jwt',
    'auth_token',
  ];
  static const List<String> _legacyUserKeys = [
    'user',
    'current_user',
  ];

  // Alias cho role (nếu trước đây app dùng tên khác)
  static const List<String> _legacyRoleKeys = [
    'Role',
    'user_role',
    'userRole',
  ];

  /// Lưu token. Có thể truyền refreshToken (không bắt buộc).
  static Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kAccess, accessToken);
    if (refreshToken != null) {
      await sp.setString(_kRefresh, refreshToken);
    }
    // Lưu luôn alias để app đoạn khác (hoặc bản cũ) vẫn đọc được
    for (final k in _legacyAccessKeys) {
      await sp.setString(k, accessToken);
    }
  }

  /// Đọc access token. Thử theo thứ tự:
  /// access_token -> alias cũ -> null nếu không có
  static Future<String?> getAccessToken() async {
    final sp = await SharedPreferences.getInstance();
    final primary = sp.getString(_kAccess);
    if (primary != null && primary.isNotEmpty) return primary;

    for (final k in _legacyAccessKeys) {
      final v = sp.getString(k);
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  /// Đọc refresh token (nếu có)
  static Future<String?> getRefreshToken() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kRefresh);
  }

  /// Lưu thông tin user (map -> JSON)
  static Future<void> saveUserMap(Map<String, dynamic> user) async {
    final sp = await SharedPreferences.getInstance();
    final json = jsonEncode(user);
    await sp.setString(_kUser, json);
    for (final k in _legacyUserKeys) {
      await sp.setString(k, json);
    }

    // Nếu user có trường Role/role thì lưu luôn role chuẩn (không phá cấu trúc cũ)
    final role = (user['Role'] ?? user['role'])?.toString();
    if (role != null && role.isNotEmpty) {
      await saveRole(role);
    }
  }

  /// Đọc thông tin user (JSON -> map). Thử cả key alias cũ.
  static Future<Map<String, dynamic>?> getUserMap() async {
    final sp = await SharedPreferences.getInstance();
    String? s = sp.getString(_kUser);
    if (s == null) {
      for (final k in _legacyUserKeys) {
        s = sp.getString(k);
        if (s != null) break;
      }
    }
    if (s == null) return null;

    try {
      final obj = jsonDecode(s);
      if (obj is Map<String, dynamic>) return obj;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Lấy userId nếu có (hỗ trợ id/userId/UserID…)
  static Future<int?> getUserId() async {
    final u = await getUserMap();
    if (u == null) return null;
    final raw = u['userId'] ?? u['UserId'] ?? u['UserID'] ?? u['id'];
    if (raw == null) return null;
    final n = int.tryParse(raw.toString());
    return n;
  }

  /// === ROLE helpers (thêm mới) ===

  /// Lưu role (ví dụ: 'admin' | 'customer')
  static Future<void> saveRole(String role) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kRole, role);
    // ghi thêm alias cũ (nếu trước đây app đọc bằng key khác)
    for (final k in _legacyRoleKeys) {
      await sp.setString(k, role);
    }
  }

  /// Đọc role: ưu tiên key chuẩn, sau đó tới alias cũ,
  /// cuối cùng thử đọc từ user_json nếu có.
  static Future<String?> getRole() async {
    final sp = await SharedPreferences.getInstance();
    String? role = sp.getString(_kRole);
    role ??= _firstNonEmpty(sp, _legacyRoleKeys);

    if (role == null || role.isEmpty) {
      final u = await getUserMap();
      role = (u?['Role'] ?? u?['role'])?.toString();
    }
    return (role == null || role.isEmpty) ? null : role;
  }

  static String? _firstNonEmpty(SharedPreferences sp, List<String> keys) {
    for (final k in keys) {
      final v = sp.getString(k);
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  /// Đã đăng nhập hay chưa (có access token non-empty)
  static Future<bool> isLoggedIn() async {
    final t = await getAccessToken();
    return t != null && t.isNotEmpty;
  }

  /// Xoá tất cả thông tin đăng nhập đã lưu.
  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kAccess);
    await sp.remove(_kRefresh);
    await sp.remove(_kUser);
    await sp.remove(_kRole);
    for (final k in _legacyAccessKeys) {
      await sp.remove(k);
    }
    for (final k in _legacyUserKeys) {
      await sp.remove(k);
    }
    for (final k in _legacyRoleKeys) {
      await sp.remove(k);
    }
  }
}
