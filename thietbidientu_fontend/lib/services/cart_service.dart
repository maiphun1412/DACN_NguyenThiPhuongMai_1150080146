import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:thietbidientu_fontend/config.dart';
import 'package:thietbidientu_fontend/models/cart_item.dart';

class CartService {
  final String baseUrl = AppConfig.baseUrl;

  Map<String, String> _headers(String? token, {bool jsonBody = true}) {
    final h = <String, String>{
      HttpHeaders.acceptHeader: 'application/json',
    };
    if (jsonBody) h[HttpHeaders.contentTypeHeader] = 'application/json';
    if (token != null && token.isNotEmpty) {
      h[HttpHeaders.authorizationHeader] = 'Bearer $token';
    }
    return h;
  }

  int _toInt(dynamic v) {
    if (v is int) return v;
    final n = int.tryParse(v.toString());
    if (n == null) throw Exception('productId không hợp lệ: $v');
    return n;
  }

  int? _toNullableInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  /// Lấy giỏ hàng theo token
  Future<List<CartItem>> getCart({required String token}) async {
    final uri = Uri.parse('$baseUrl/api/cart/my');
    print('[HTTP] GET $uri  token=${token.isEmpty ? "<EMPTY>" : token.substring(0, 12) + "..."}');

    final res = await http.get(uri, headers: _headers(token, jsonBody: false));
    print('[HTTP] <- ${res.statusCode} ${res.body}');

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      final List raw = body is List
          ? body
          : (body is Map<String, dynamic> ? (body['items'] as List? ?? []) : []);
      return raw.map((e) => CartItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    if (res.statusCode == 401) {
      throw Exception('Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.');
    }
    if (res.statusCode == 404) return <CartItem>[];
    throw Exception('Không thể lấy giỏ hàng: ${res.statusCode} ${res.body}');
  }

  /// Thêm sản phẩm vào giỏ
  /// BE: POST /api/cart/add  { productId:int, quantity:int, optionId?, color?, size? }
  Future<void> addToCart({
    required String token,
    required dynamic productId,
    int quantity = 1,
    int? optionId,                 // gửi khi có id biến thể
    String? color,                 // fallback nếu BE cần color/size
    String? size,                  // fallback nếu BE cần color/size
  }) async {
    final pid = _toInt(productId);
    final uri  = Uri.parse('$baseUrl/api/cart/add'); // dùng 1 endpoint duy nhất

    final payload = <String, dynamic>{
      'productId': pid,
      'quantity': quantity,
      if (optionId != null) 'optionId': optionId,
      if ((color ?? '').isNotEmpty) 'color': color,
      if ((size ?? '').isNotEmpty) 'size': size,
    };

    final res = await http.post(uri, headers: _headers(token), body: jsonEncode(payload));
    print('[HTTP] POST $uri -> ${res.statusCode} ${res.body}');

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Không thể thêm sản phẩm vào giỏ: ${res.statusCode} ${res.body}');
    }
  }

  /// Cập nhật số lượng
  /// BE: PATCH /api/cart/quantity  { productId:int, optionId?:int, quantity:int }
  Future<void> updateQuantity({
    required String token,
    required dynamic productId,
    int? optionId,
    required int quantity,
  }) async {
    final uri = Uri.parse('$baseUrl/api/cart/quantity');
    final pid = _toInt(productId);
    final body = jsonEncode({
      'productId': pid,
      'optionId': _toNullableInt(optionId),
      'quantity': quantity,
    });

    final res = await http.patch(uri, headers: _headers(token), body: body);
    print('[HTTP] PATCH $uri -> ${res.statusCode} ${res.body}');

    if (res.statusCode != 200) {
      throw Exception('Không thể cập nhật số lượng: ${res.statusCode} ${res.body}');
    }
  }

  /// Xoá 1 sản phẩm khỏi giỏ
  /// BE: DELETE /api/cart/item/:productId/:optionId?
  Future<void> removeFromCart({
    required String token,
    required dynamic productId,
    int? optionId,
  }) async {
    final pid = _toInt(productId);
    final path = optionId == null
        ? '$baseUrl/api/cart/item/$pid'
        : '$baseUrl/api/cart/item/$pid/${_toNullableInt(optionId)}';
    final uri = Uri.parse(path);

    final res = await http.delete(uri, headers: _headers(token, jsonBody: false));
    print('[HTTP] DELETE $uri -> ${res.statusCode} ${res.body}');

    if (res.statusCode != 200) {
      throw Exception('Không thể xoá sản phẩm: ${res.statusCode} ${res.body}');
    }
  }

  /// Xoá sạch giỏ
  /// BE: DELETE /api/cart/clear
  Future<void> clearCart({required String token}) async {
    final uri = Uri.parse('$baseUrl/api/cart/clear');
    final res = await http.delete(uri, headers: _headers(token, jsonBody: false));
    print('[HTTP] DELETE $uri -> ${res.statusCode} ${res.body}');

    if (res.statusCode != 200) {
      throw Exception('Không thể xoá giỏ hàng: ${res.statusCode} ${res.body}');
    }
  }

  // Gọi POST thô khi cần
  Future<http.Response> postRaw(
    Uri uri, {
    required String token,
    required Map<String, dynamic> data,
  }) async {
    return await http.post(
      uri,
      headers: _headers(token),
      body: jsonEncode(data),
    );
  }

  /// Tạo đơn hàng từ giỏ hiện tại
  /// BE: POST /api/orders/checkout
  Future<void> placeOrder({
    required String token,
    required int totalAmount,
    required String shippingAddress,
    required String paymentMethod, // 'cod' | 'momo' | 'atm' | 'visa'
    List<Map<String, dynamic>>? items,
    String? note,
    String? shippingMethod,          // 'standard' | 'express'
    String? couponCode,
  }) async {
    final uri = Uri.parse('$baseUrl/api/orders/checkout');
    final payload = <String, dynamic>{
      'totalAmount': totalAmount,
      'shippingAddress': shippingAddress,
      'paymentMethod': paymentMethod,
      if (items != null && items.isNotEmpty) 'items': items,
      if (note != null && note.isNotEmpty) 'note': note,
      if (shippingMethod != null && shippingMethod.isNotEmpty) 'shippingMethod': shippingMethod,
      if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
    };

    final res = await http.post(uri, headers: _headers(token), body: jsonEncode(payload));
    print('[HTTP] POST $uri -> ${res.statusCode} ${res.body}');

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Không thể tạo đơn hàng: ${res.statusCode} ${res.body}');
    }
  }
}
