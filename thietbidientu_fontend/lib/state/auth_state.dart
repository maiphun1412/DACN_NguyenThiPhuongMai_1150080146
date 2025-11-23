// lib/state/auth_state.dart

import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../services/auth_storage.dart';

/// AuthState dùng để lưu user + token + role.
/// - Giữ nguyên Singleton & ValueNotifier như dự án hiện có.
/// - Hỗ trợ đọc role từ JWT (claim 'role') để phân luồng ADMIN/MANAGER/CUSTOMER/SHIPPER.
class AuthState {
  // ===== Singleton (giữ nguyên) =====
  static final AuthState I = AuthState._();
  AuthState._();

  /// user: null hoặc map { id, name?, email?, avatar?, token?, role? }
  final ValueNotifier<Map<String, dynamic>?> user = ValueNotifier(null);

  // ====== Getters tiện dụng ======
  String? get token => user.value?['token'] as String?;
  String? get role => (user.value?['role'] as String?)?.toLowerCase();
  bool get isLoggedIn => token != null;

  bool get isAdmin => role == 'admin';
  bool get isManager => role == 'manager';
  bool get isCustomer => role == 'customer';
  bool get isShipper => role == 'shipper';

  /// Kiểm tra user có thuộc 1 trong các role cho trước không (không phân biệt hoa/thường)
  bool hasAnyRole(Iterable<String> roles) {
    final r = role;
    if (r == null) return false;
    for (final x in roles) {
      if (r == x.toLowerCase()) return true;
    }
    return false;
  }

  // ====== Load/Save từ storage (giữ nguyên API cũ) ======
  Future<void> loadFromStorage() async {
    final u = await AuthStorage.getUserMap();
    if (u == null) {
      user.value = null;
      return;
    }

    // Bản sao để tránh thay đổi tham chiếu từ ngoài
    final m = Map<String, dynamic>.from(u);

    // Nếu chưa có role mà có token -> giải mã từ JWT để điền role/email/id
    _ensureClaimsFromTokenIntoMap(m);

    user.value = m;
  }

  /// setUser: GIỮ API cũ.
  /// - Nếu map mới không có token/role mà hiện tại đang có, sẽ giữ lại để tránh mất trạng thái.
  Future<void> setUser(Map<String, dynamic>? u) async {
    if (u == null) {
      user.value = null;
      await AuthStorage.clear();
      return;
    }

    final current = user.value;
    final m = Map<String, dynamic>.from(u);

    // Bảo toàn token/role/id nếu map mới không cung cấp
    if (m['token'] == null && current != null && current['token'] != null) {
      m['token'] = current['token'];
    }
    if (m['role'] == null && current != null && current['role'] != null) {
      m['role'] = current['role'];
    }
    if (m['id'] == null && current != null && current['id'] != null) {
      m['id'] = current['id'];
    }

    // Nếu có token thì đảm bảo role/id/email khớp với token
    _ensureClaimsFromTokenIntoMap(m);

    user.value = m;
    await AuthStorage.saveUserMap(m);
  }

  /// Xoá hoàn toàn trạng thái đăng nhập
  Future<void> clear() async {
    user.value = null;
    await AuthStorage.clear();
  }

  // ====== Tiện ích mới (không phá API cũ) ======

  /// Gán token (ví dụ sau khi gọi /auth/login) và tự động điền role/id/email từ JWT.
  Future<void> setToken(String token) async {
    final m = Map<String, dynamic>.from(user.value ?? {});
    m['token'] = token;

    _ensureClaimsFromTokenIntoMap(m);

    user.value = m;
    await AuthStorage.saveUserMap(m);
  }

  /// Áp dụng trực tiếp response đăng nhập từ backend:
  /// data dạng: { "token": "...", "user": { "id": 1, "email": "...", "role": "admin", ... } }
  Future<void> applyLoginResponse(Map<String, dynamic> data) async {
    final m = <String, dynamic>{};

    final t = data['token'];
    if (t is String && t.isNotEmpty) {
      m['token'] = t;
    }

    final u = data['user'];
    if (u is Map) {
      // copy các field trả về từ BE
      m.addAll(u.map((k, v) => MapEntry(k.toString(), v)));
    }

    // Ưu tiên role từ user (nếu BE đã gửi), nếu chưa có sẽ đọc từ token
    _ensureClaimsFromTokenIntoMap(m);

    user.value = m;
    await AuthStorage.saveUserMap(m);
  }

  // ====== Helpers ======

  /// Đảm bảo nếu có 'token' thì sẽ trích role/id/email từ JWT và đổ vào map nếu đang thiếu.
  void _ensureClaimsFromTokenIntoMap(Map<String, dynamic> m) {
    final t = m['token'];
    if (t is! String || t.isEmpty) return;

    try {
      final payload = JwtDecoder.decode(t);

      // role
      final claimRole = (payload['role'] as String?)?.toLowerCase();
      if ((m['role'] == null || (m['role'] as String).isEmpty) && claimRole != null) {
        m['role'] = claimRole;
      }

      // id (ưu tiên claims: sub | userId | UserID | id)
      final rawId =
          payload['sub'] ?? payload['userId'] ?? payload['UserID'] ?? payload['id'];
      if (m['id'] == null && rawId != null) {
        m['id'] = rawId;
      }

      // email
      if (m['email'] == null && payload['email'] != null) {
        m['email'] = payload['email'];
      }
    } catch (_) {
      // token không hợp lệ → bỏ qua, không crash UI
    }
  }
}
