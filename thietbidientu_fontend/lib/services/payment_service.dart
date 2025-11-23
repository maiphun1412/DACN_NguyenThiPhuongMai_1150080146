// lib/services/payment_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thietbidientu_fontend/config.dart';

// ✅ dùng AuthStorage để lấy access token chuẩn
import 'auth_storage.dart';

class PaymentService {
  final String baseUrl = AppConfig.baseUrl;

  Future<Map<String, String>> _headers({bool jsonBody = true}) async {
    // Ưu tiên lấy từ AuthStorage (nguồn chính)
    final tokenFromStorage = await AuthStorage.getAccessToken();

    // Fallback: nếu vì lý do nào đó chưa có, thử đọc các key phổ biến trong SharedPreferences
    final sp = await SharedPreferences.getInstance();
    final tokenFallback = sp.getString('access_token') ??
        sp.getString('token') ??
        sp.getString('accessToken') ??
        sp.getString('jwt') ??
        '';

    final token = (tokenFromStorage != null && tokenFromStorage.isNotEmpty)
        ? tokenFromStorage
        : tokenFallback;

    final h = <String, String>{
      HttpHeaders.acceptHeader: 'application/json',
    };
    if (jsonBody) h[HttpHeaders.contentTypeHeader] = 'application/json';
    if (token.isNotEmpty) {
      h[HttpHeaders.authorizationHeader] = 'Bearer $token';
    }
    return h;
  }

  dynamic _safeJson(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return {'message': body};
    }
  }

  /* =========================================================
   *               CÁC HÀM THANH TOÁN (GIỮ NGUYÊN)
   * ========================================================= */

  Future<Map<String, dynamic>> checkout({
    required int orderId,
    required String email,
  }) async {
    final url = Uri.parse('$baseUrl/api/payments/checkout');
    final res = await http
        .post(
          url,
          headers: await _headers(),
          body: jsonEncode({'orderId': orderId, 'email': email}),
        )
        .timeout(const Duration(seconds: 20));

    final data = _safeJson(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (data is Map<String, dynamic>) ? data : <String, dynamic>{};
    }
    throw Exception(data['message'] ?? 'Checkout OTP failed (${res.statusCode})');
  }

  Future<void> resendOtp({required int orderId}) async {
    final url = Uri.parse('$baseUrl/api/payments/otp/resend');
    final res = await http
        .post(
          url,
          headers: await _headers(),
          body: jsonEncode({'orderId': orderId}),
        )
        .timeout(const Duration(seconds: 20));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final data = _safeJson(res.body);
      throw Exception(data['message'] ?? 'Resend OTP failed (${res.statusCode})');
    }
  }

  Future<void> verifyOtp({
    required int orderId,
    required String otp,
    String? cardNo,
    String? exp,
    String? cvv,
  }) async {
    final url = Uri.parse('$baseUrl/api/payments/otp/verify');
    final body = <String, dynamic>{
      'orderId': orderId,
      'otp': otp,
      if (cardNo != null && cardNo.isNotEmpty) 'cardNo': cardNo,
      if (exp != null && exp.isNotEmpty) 'exp': exp,
      if (cvv != null && cvv.isNotEmpty) 'cvv': cvv,
    };
    final res = await http
        .post(
          url,
          headers: await _headers(),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));

    if (res.statusCode >= 400) {
      // Trả về message BE để debug dễ
      final data = _safeJson(res.body);
      throw Exception(data['message'] ?? 'verifyOtp ${res.statusCode}');
    }
  }

  /* =========================================================
   *     NHÓM HÀM ORDER — THÊM MỚI (KHÔNG ẢNH HƯỞNG PHẦN TRÊN)
   *     Endpoint bám đúng BE: /api/orders/...
   * ========================================================= */

  /// Tạo đơn & trừ tồn kho (BE tự định giá theo Product/Option).
  /// items: [{productId, optionId?, quantity, color?, size?}]
  Future<Map<String, dynamic>> orderCheckout({
    required int addressId,
    required String paymentMethod, // 'COD' | 'MOMO' | 'ATM' | 'CARD'
    required List<Map<String, dynamic>> items,
    String? note,
  }) async {
    final url = Uri.parse('$baseUrl/api/orders/checkout');
    final body = {
      'addressId': addressId,
      'paymentMethod': paymentMethod,
      'items': items,
      if (note != null && note.isNotEmpty) 'note': note,
    };
    final res = await http
        .post(url, headers: await _headers(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 25));

    final data = _safeJson(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      // { message, orderId, requiresOtp, order:{...} }
      return (data is Map<String, dynamic>) ? data : <String, dynamic>{};
    }

    // 409 = hết hàng
    if (res.statusCode == 409) {
      throw Exception(data['message'] ?? 'Sản phẩm không đủ tồn kho');
    }
    throw Exception(data['message'] ?? 'Đặt hàng thất bại (${res.statusCode})');
  }

  /// Danh sách đơn của tôi (phân trang)
  Future<List<dynamic>> getMyOrders({int page = 1, int pageSize = 10}) async {
    final url = Uri.parse('$baseUrl/api/orders/my?page=$page&pageSize=$pageSize');
    final res = await http
        .get(url, headers: await _headers(jsonBody: false))
        .timeout(const Duration(seconds: 20));

    final data = _safeJson(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (data is Map && data['data'] is List) ? (data['data'] as List) : <dynamic>[];
    }
    throw Exception(data['message'] ?? 'Lấy đơn hàng thất bại (${res.statusCode})');
  }

  /// Tóm tắt đơn (địa chỉ, tổng tiền, trạng thái thanh toán)
  Future<Map<String, dynamic>> getOrderSummary(int orderId) async {
    final url = Uri.parse('$baseUrl/api/orders/$orderId/summary');
    final res = await http
        .get(url, headers: await _headers(jsonBody: false))
        .timeout(const Duration(seconds: 20));

    final data = _safeJson(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (data is Map<String, dynamic>) ? data : <String, dynamic>{};
    }
    throw Exception(data['message'] ?? 'Lấy tóm tắt đơn thất bại (${res.statusCode})');
  }

  /// Gửi OTP qua email cho đơn (owner hoặc admin)
  Future<void> sendOrderOtp(int orderId) async {
    final url = Uri.parse('$baseUrl/api/orders/$orderId/send-otp');
    final res = await http
        .post(url, headers: await _headers(), body: jsonEncode({}))
        .timeout(const Duration(seconds: 20));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final data = _safeJson(res.body);
      throw Exception(data['message'] ?? 'Gửi OTP thất bại (${res.statusCode})');
    }
  }

  /// Lấy các item của đơn (kèm tên SP, ảnh chính, màu/size, Reviewed…)
  Future<List<dynamic>> getOrderItems(int orderId) async {
    final url = Uri.parse('$baseUrl/api/orders/$orderId/items');
    final res = await http
        .get(url, headers: await _headers(jsonBody: false))
        .timeout(const Duration(seconds: 20));

    final data = _safeJson(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (data is Map && data['items'] is List) return data['items'] as List<dynamic>;
      return <dynamic>[];
    }
    throw Exception(data['message'] ?? 'Lấy sản phẩm trong đơn thất bại (${res.statusCode})');
  }

  /// Khách tự hủy đơn (khi còn Chờ xử lý/Đang xử lý)
  Future<void> cancelMyOrder(int orderId) async {
    final url = Uri.parse('$baseUrl/api/orders/$orderId/cancel');
    final res = await http
        .post(url, headers: await _headers(), body: jsonEncode({}))
        .timeout(const Duration(seconds: 20));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final data = _safeJson(res.body);
      throw Exception(data['message'] ?? 'Hủy đơn thất bại (${res.statusCode})');
    }
  }
}
