import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import 'auth_storage.dart';
import '../state/auth_state.dart';

class AuthService {
  /// Trích role từ JWT (nếu BE không trả kèm user)
  static String? _roleFromJwt(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final obj = jsonDecode(payload);
      final r = (obj['role'] ?? obj['Role'])?.toString();
      return r?.toLowerCase();
    } catch (_) {
      return null;
    }
  }

  /// Chuẩn hoá user từ nhiều kiểu key khác nhau của BE về {id, name, email, avatar, role}
  static Map<String, dynamic> _normalizeUser(Map input, {String? fallbackRole}) {
    final u = Map<String, dynamic>.from(input);
    final roleRaw = (u['role'] ?? u['Role'] ?? fallbackRole)?.toString();
    return {
      'id': (u['id'] ?? u['UserID'] ?? u['userId'] ?? u['Id'] ?? '').toString(),
      'name': u['name'] ?? u['fullName'] ?? u['FullName'] ?? u['username'] ?? '',
      'email': u['email'] ?? u['Email'] ?? '',
      'avatar': u['avatar'] ?? u['Avatar'],
      'role': roleRaw?.toLowerCase(),
    };
  }

  /// 🔹 helper: lưu email đăng nhập vào SharedPreferences (để Checkout dùng gợi ý OTP)
  static Future<void> _cacheEmail(String? email) async {
    final e = (email ?? '').trim();
    if (e.isEmpty) return;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('email', e); // 👈 chìa khoá cho flow OTP
  }

  /// Đăng ký: gọi API tạo tài khoản -> không lưu token, chỉ trả message để UI hiển thị rồi quay về Login
  static Future<String?> register({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/auth/register');
    try {
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': fullName.trim(),
          'email': email.trim(),
          'password': password,
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        }),
      );

      debugPrint('REGISTER STATUS: ${res.statusCode}');
      debugPrint('REGISTER BODY  : ${res.body}');

      final body = res.body.isNotEmpty ? jsonDecode(res.body) : null;

      if (res.statusCode == 201) {
        return (body is Map && body['message'] is String)
            ? body['message'] as String
            : 'Đăng ký thành công';
      }

      if (body is Map && body['message'] is String) {
        return body['message'] as String;
      }
      return 'Đăng ký thất bại';
    } catch (e) {
      debugPrint('REGISTER ERROR: $e');
      return 'Không thể đăng ký: $e';
    }
  }

  /// Đăng nhập: lưu token + user (chuẩn hoá) + trả Map { ok, user, role, accessToken }
  /// - Nếu thất bại, trả false để không phá vỡ chỗ gọi cũ (tương thích ngược).
  static Future<dynamic> login(String identifier, String password) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/auth/login');
    try {
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"email": identifier, "password": password}),
      );

      debugPrint('LOGIN STATUS: ${res.statusCode}');
      debugPrint('LOGIN BODY  : ${res.body}');

      if (res.statusCode != 200) return false;

      final dynamic dataDyn = jsonDecode(res.body);
      final Map<String, dynamic> data =
          (dataDyn is Map) ? Map<String, dynamic>.from(dataDyn) : {};

      // Nới lỏng key token: hỗ trợ accessToken | token | jwt
      final String accessToken =
          (data['accessToken'] ?? data['token'] ?? data['jwt'])?.toString() ?? '';
      if (accessToken.isEmpty) return false;

      // Lưu token
      await AuthStorage.saveTokens(accessToken: accessToken);
      await AuthState.I.setToken(accessToken);

      // Lấy/chuẩn hoá user
      Map<String, dynamic> userNormalized;
      if (data['user'] is Map) {
        final roleFromJwt = _roleFromJwt(accessToken);
        userNormalized = _normalizeUser(
          Map<String, dynamic>.from(data['user']),
          fallbackRole: roleFromJwt,
        );
      } else {
        // Không có user kèm theo -> tạo tạm và cố gắng fetch /me
        final roleFromJwt = _roleFromJwt(accessToken);
        userNormalized = {
          'id': '',
          'name': identifier.contains('@') ? identifier.split('@').first : identifier,
          'email': identifier,
          'role': roleFromJwt,
        };
        final me = await _refreshMeWithToken(accessToken);
        if (me != null) {
          userNormalized = _normalizeUser(me, fallbackRole: roleFromJwt);
        }
      }

      // Cập nhật state để UI điều hướng
      await AuthState.I.setUser(userNormalized);

      // 🔧 NEW: lưu email đăng nhập để CheckoutPage dùng gửi OTP mặc định
      await _cacheEmail((userNormalized['email'] ?? '').toString());

      // Lưu thêm role ra SharedPreferences (để RootGate/guard nào đó dùng nếu có)
      final sp = await SharedPreferences.getInstance();
      await sp.setString('role', (userNormalized['role'] ?? '').toString());

      // Trả map cho màn login điều hướng theo role
      return {
        'ok': true,
        'user': userNormalized,
        'role': userNormalized['role'] ?? '',
        'accessToken': accessToken,
      };
    } catch (e) {
      debugPrint('LOGIN ERROR: $e');
      return false;
    }
  }

  /// Gọi /me bằng token, nếu 200 thì chuẩn hoá và trả user
  static Future<Map<String, dynamic>?> _refreshMeWithToken(String token) async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/users/me'), // Đổi endpoint nếu BE khác
        headers: {'Authorization': 'Bearer $token'},
      );
      debugPrint('ME STATUS: ${res.statusCode}');
      debugPrint('ME BODY  : ${res.body}');
      if (res.statusCode == 200) {
        final obj = jsonDecode(res.body);
        if (obj is Map && obj['user'] is Map) {
          return Map<String, dynamic>.from(obj['user']);
        } else if (obj is Map) {
          return Map<String, dynamic>.from(obj);
        }
      }
    } catch (e) {
      debugPrint('ME ERROR: $e');
    }
    return null;
  }

  /// Đảm bảo user đã nạp: ưu tiên state → cache → gọi /me
  static Future<Map<String, dynamic>?> ensureUserLoaded() async {
    // 1) có sẵn trong state
    if (AuthState.I.user.value != null) {
      // 🔧 NEW: đồng bộ email vào SharedPreferences
      await _cacheEmail((AuthState.I.user.value!['email'] ?? '').toString());
      return AuthState.I.user.value;
    }

    // 2) có trong cache
    final cached = await AuthStorage.getUserMap();
    final token = await AuthStorage.getAccessToken();

    if (cached != null) {
      // nếu cache thiếu role, thử trích từ JWT
      Map<String, dynamic> normalized = _normalizeUser(
        cached,
        fallbackRole: (token != null) ? _roleFromJwt(token) : null,
      );

      // đảm bảo RoleRouter có token trong state
      if (token != null && token.isNotEmpty) {
        await AuthState.I.setToken(token);
      }
      await AuthState.I.setUser(normalized);

      // 🔧 NEW: đồng bộ email vào SharedPreferences
      await _cacheEmail((normalized['email'] ?? '').toString());
      return AuthState.I.user.value;
    }

    // 3) thử gọi /me với token có sẵn
    if (token == null || token.isEmpty) return null;
    final me = await _refreshMeWithToken(token);
    if (me != null) {
      final normalized = _normalizeUser(me, fallbackRole: _roleFromJwt(token));
      await AuthState.I.setToken(token);
      await AuthState.I.setUser(normalized);

      // 🔧 NEW: đồng bộ email vào SharedPreferences
      await _cacheEmail((normalized['email'] ?? '').toString());
      return normalized;
    }
    return null;
  }

  /// Đăng xuất: xoá state + cache
  static Future<void> logout() async {
    await AuthState.I.clear();
  }

  // ====== OTP thực (map đúng API backend) ======
  /// Gửi OTP (email/phone) – gọi /api/auth/request-reset
  static Future<bool> sendOtp(String identifier) async {
    try {
      final res = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/auth/request-reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'identifier': identifier.trim()}),
      );
      debugPrint('REQUEST RESET STATUS: ${res.statusCode}');
      debugPrint('REQUEST RESET BODY  : ${res.body}');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('REQUEST RESET ERROR: $e');
      return false;
    }
  }

  /// Xác minh OTP – gọi /api/auth/verify-reset
  static Future<bool> verifyOtp(String identifier, String otp) async {
    try {
      final res = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/auth/verify-reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'identifier': identifier.trim(), 'code': otp.trim()}),
      );
      debugPrint('VERIFY RESET STATUS: ${res.statusCode}');
      debugPrint('VERIFY RESET BODY  : ${res.body}');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('VERIFY RESET ERROR: $e');
      return false;
    }
  }

  /// Đặt lại mật khẩu bằng OTP – gọi /api/auth/confirm-reset
  static Future<bool> resetPassword(String identifier, String newPwd, {required String otp}) async {
    try {
      final res = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/auth/confirm-reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': identifier.trim(),
          'code': otp.trim(),
          'newPassword': newPwd,
        }),
      );
      debugPrint('CONFIRM RESET STATUS: ${res.statusCode}');
      debugPrint('CONFIRM RESET BODY  : ${res.body}');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('CONFIRM RESET ERROR: $e');
      return false;
    }
  }

  /// 🔐 Đổi mật khẩu (cần đang đăng nhập)
  static Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = await AuthStorage.getAccessToken();
    if (token == null || token.isEmpty) return 'Bạn chưa đăng nhập';

    final url = Uri.parse('${AppConfig.baseUrl}/api/auth/change-password');
    try {
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      final body = res.body.isNotEmpty ? jsonDecode(res.body) : null;
      final msg = (body is Map && body['message'] is String)
          ? body['message'] as String
          : (res.statusCode == 200
              ? 'Đổi mật khẩu thành công'
              : 'Đổi mật khẩu thất bại');

      return msg;
    } catch (e) {
      return 'Lỗi kết nối: $e';
    }
  }
}
