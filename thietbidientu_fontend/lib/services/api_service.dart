// lib/services/api_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; // ⬅️ thêm
import 'package:thietbidientu_fontend/config.dart';
import 'package:thietbidientu_fontend/models/product.dart';
// ✅ alias model để tránh đụng tên với widget
import 'package:thietbidientu_fontend/models/product_option.dart' as m;

class ApiService {
  // ❗ KHÔNG chụp baseUrl sớm. Luôn lấy động tại thời điểm gọi.
  String get _base => AppConfig.baseUrl;

  Map<String, String> get _jsonHeaders => const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

  Uri _buildUri(String path, [Map<String, dynamic>? params]) {
    if (path.startsWith('http')) {
      return Uri.parse(path).replace(
        queryParameters:
            params?.map((k, v) => MapEntry(k, v?.toString() ?? '')),
      );
    }

    final normBase =
        _base.endsWith('/') ? _base.substring(0, _base.length - 1) : _base;
    final normPath = path.startsWith('/') ? path : '/$path';

    final String url = (normPath.startsWith('/api/'))
        ? '$normBase$normPath'
        : '$normBase/api$normPath';

    return Uri.parse(url).replace(
      queryParameters:
          params?.map((k, v) => MapEntry(k, v?.toString() ?? '')),
    );
  }

  // ================== helpers thêm để tránh lỗi gọi ==================
  // Lấy Authorization từ SharedPreferences & merge với headers bổ sung (nếu có)
  Future<Map<String, String>> _authHeaders(
      [Map<String, String>? extra]) async {
    final sp = await SharedPreferences.getInstance();
    final token =
        sp.getString('token') ?? sp.getString('accessToken') ?? sp.getString('jwt') ?? '';
    final h = <String, String>{};
    if (token.isNotEmpty) h['Authorization'] = 'Bearer $token';
    if (extra != null) h.addAll(extra);
    return h;
  }

  // Wrapper để tái sử dụng ở chỗ đã gọi await _buildUrl(...)
  Future<String> _buildUrl(String path,
      [Map<String, dynamic>? params]) async {
    return _buildUri(path, params).toString();
  }
  // ================================================================

  Future<Map<String, dynamic>> checkoutOrder({
    required List<Map<String, dynamic>> items,
    int? addressId,
    String? paymentMethod,
    String? note,
    String? fullName,
    String? phone,
    String? line1,
    String? ward,
    String? district,
    String? city,
    String? province,
    String? bearerToken,
  }) async {
    // headers
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if ((bearerToken ?? '').isNotEmpty)
        'Authorization': 'Bearer $bearerToken',
    };

    // ❗ map item: đẩy productId/quantity/price + optionId + color/size nếu có
    final payloadItems = items.map((e) {
      final m = Map<String, dynamic>.from(e);
      final pid = m['productId'] ?? m['ProductID'] ?? m['id'];
      final qty = m['qty'] ?? m['quantity'] ?? m['Qty'] ?? 1;
      final price = (m['price'] ?? 0);

      final optId = m['optionId'] ?? m['OptionID'] ?? m['optionID'];
      final color = m['color'] ?? m['Color'];
      final size = m['size'] ?? m['Size'];

      return <String, dynamic>{
        'productId': pid,
        'quantity': qty,
        'price': price,
        if (optId != null) 'optionId': optId, // BE nào nhận OptionID thì thêm dòng dưới
        if (optId != null) 'OptionID': optId,
        if (color != null && '$color'.isNotEmpty) 'color': color,
        if (size != null && '$size'.isNotEmpty) 'size': size,
      };
    }).toList();

    final body = <String, dynamic>{
      'items': payloadItems,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
      if (note != null && note.isNotEmpty) 'note': note,
      if (addressId != null)
        'addressId': addressId
      else
        'address': {
          'fullName': fullName?.trim(),
          'phone': phone?.trim(),
          'line1': line1?.trim(),
          if ((ward ?? '').isNotEmpty) 'ward': ward,
          if ((district ?? '').isNotEmpty) 'district': district,
          if ((city ?? '').isNotEmpty) 'city': city,
          if ((province ?? '').isNotEmpty) 'province': province,
        },
    };

    // ❗ dùng _buildUri để tự thêm /api
    final uri = _buildUri('/orders/checkout');
    final res = await http
        .post(uri, headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Không thể tạo đơn hàng: ${res.statusCode} ${res.body}');
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? params,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, params ?? query);
    final res = await http
        .get(uri, headers: {..._jsonHeaders, if (headers != null) ...headers})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('GET $path thất bại (${res.statusCode}): ${res.body}');
    }
    if (res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }

  Future<dynamic> post(
    String path,
    Object? body, // ← cho phép null hoặc Map bất kỳ
    { Map<String, dynamic>? params, Map<String, String>? headers }
  ) async {
    final uri = _buildUri(path, params);
    final res = await http.post(
      uri,
      headers: {..._jsonHeaders, if (headers != null) ...headers},
      body: body == null ? null : jsonEncode(body), // ← chỉ encode khi có body
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('POST $path thất bại (${res.statusCode}): ${res.body}');
    }
    return res.body.isEmpty ? null : jsonDecode(res.body);
  }

  Future<dynamic> put(
    String path,
    Map<String, dynamic> body, {
    Map<String, dynamic>? params,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, params);
    final res = await http
        .put(
          uri,
          headers: {..._jsonHeaders, if (headers != null) ...headers},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('PUT $path thất bại (${res.statusCode}): ${res.body}');
    }
    return res.body.isEmpty ? null : jsonDecode(res.body);
  }

  Future<dynamic> patch(
    String path,
    Map<String, dynamic> body, {
    Map<String, dynamic>? params,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, params);
    final res = await http
        .patch(
          uri,
          headers: {..._jsonHeaders, if (headers != null) ...headers},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('PATCH $path thất bại (${res.statusCode}): ${res.body}');
    }
    return res.body.isEmpty ? null : jsonDecode(res.body);
  }

  Future<dynamic> delete(
    String path, {
    Map<String, dynamic>? params,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, params);
    final res = await http
        .delete(uri,
            headers: {..._jsonHeaders, if (headers != null) ...headers})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('DELETE $path thất bại (${res.statusCode}): ${res.body}');
    }
    return res.body.isEmpty ? null : jsonDecode(res.body);
  }

  Future<List<dynamic>> getList(
    String path, {
    Map<String, dynamic>? params,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
  }) async {
    final data =
        await get(path, params: params, query: query, headers: headers);

    if (data is List) return data;

    if (data is Map) {
      for (final k in [
        'items',
        'data',
        'products',
        'rows',
        'records',
        'list'
      ]) {
        final v = data[k];
        if (v is List) return v;
      }
      final inner = data['data'];
      if (inner is Map) {
        for (final k
            in ['items', 'products', 'rows', 'records', 'list']) {
          final v = inner[k];
          if (v is List) return v;
        }
      }
    }
    return <dynamic>[];
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final uri = _buildUri('/auth/login');
    final res = await http
        .post(
          uri,
          headers: _jsonHeaders,
          body: jsonEncode({
            'email': email.trim().toLowerCase(),
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception('Đăng nhập thất bại: ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ===== AUTH =====
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final uri = _buildUri('/auth/register'); // tự thêm /api
    print('→ REGISTER POST $uri'); // LOG BẮT BUỘC: xem đúng host chưa

    final res = await http
        .post(
          uri,
          headers: _jsonHeaders,
          body: jsonEncode({
            'email': email.trim().toLowerCase(),
            'password': password,
            'fullName': fullName.trim(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    print('← REGISTER ${res.statusCode} ${res.body}'); // log response

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Đăng ký thất bại: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProductDetails(int productId) async {
    final uri = _buildUri('/products/$productId');
    final res =
        await http.get(uri, headers: _jsonHeaders).timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception('Không thể tải chi tiết sản phẩm');
    }

    final responseJson = jsonDecode(res.body) as Map<String, dynamic>;
    return (responseJson['product'] ?? responseJson) as Map<String, dynamic>;
  }

  Future<List<Product>> getProducts({String? search}) async {
    final raw = await getList(
      '/products',
      params: (search?.isNotEmpty ?? false) ? {'q': search} : null,
    );

    return raw
        .whereType<Map<String, dynamic>>()
        .map<Product>((e) => Product.fromJson(e))
        .toList();
  }

  // ✅ Trả về list model m.ProductOption
  Future<List<m.ProductOption>> getProductOptions(int productId) async {
    final uri = _buildUri('/products/$productId/options');
    final res =
        await http.get(uri, headers: _jsonHeaders).timeout(const Duration(seconds: 15));
    if (res.statusCode == 404) return [];
    if (res.statusCode != 200) {
      throw Exception('Không thể tải tùy chọn sản phẩm');
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => m.ProductOption.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<String>> getProductImages(int productId) async {
    final data = await get('/products/$productId/images');

    List raw;
    if (data is List) {
      raw = data;
    } else if (data is Map && data['data'] is List) {
      raw = data['data'];
    } else if (data is Map && data['images'] is List) {
      raw = data['images'];
    } else {
      raw = const [];
    }

    String _fullUrl(dynamic u) {
      if (u == null) return '';
      final s = u.toString().trim();
      if (s.isEmpty) return '';
      if (s.startsWith('http')) return s;
      final base = AppConfig.baseUrl;
      if (base.endsWith('/') && s.startsWith('/')) return base + s.substring(1);
      if (!base.endsWith('/') && !s.startsWith('/')) return '$base/$s';
      return '$base$s';
    }

    final urls = <String>[];
    for (final e in raw) {
      dynamic u;
      if (e is String) {
        u = e;
      } else if (e is Map) {
        u = e['url'] ??
            e['Url'] ??
            e['imageUrl'] ??
            e['ImageUrl'] ??
            e['path'] ??
            e['Path'];
      }
      final f = _fullUrl(u);
      if (f.isNotEmpty) urls.add(f);
    }
    return urls;
  }

  Future<Map<String, dynamic>> getAdminDashboard({
    int days = 7,
    String granularity = 'day',
    int months = 6,
    int lowThreshold = 10,
    bool includeInactive = false,
  }) async {
    final params = <String, dynamic>{};

    if (granularity == 'month') {
      params['granularity'] = 'month';
      params['months'] = months;
    } else {
      params['days'] = days;
    }

    params['lowThreshold'] = lowThreshold;
    params['includeInactive'] = includeInactive ? 1 : 0;

    final data = await get('/admin/dashboard', params: params);
    return data as Map<String, dynamic>;
  }

  // ✅ bỏ _base chụp sớm, dùng _buildUri
  Future<Map<String, dynamic>> getOrderSummary(int orderId,
      {String? bearerToken}) async {
    final uri = _buildUri('/orders/$orderId/summary');
    final res = await http.get(uri, headers: {
      'Accept': 'application/json',
      if (bearerToken != null && bearerToken.isNotEmpty)
        'Authorization': 'Bearer $bearerToken',
    }).timeout(const Duration(seconds: 15));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return json.decode(res.body) as Map<String, dynamic>;
    }
    throw Exception('getOrderSummary ${res.statusCode}: ${res.body}');
  }

  // ✅ bỏ _base chụp sớm, dùng _buildUri
  Future<Map<String, dynamic>> getPaymentIntent(int orderId,
      {String? bearerToken}) async {
    final uri = _buildUri('/payments/intent/$orderId');
    final res = await http.get(uri, headers: {
      'Accept': 'application/json',
      if (bearerToken != null && bearerToken.isNotEmpty)
        'Authorization': 'Bearer $bearerToken',
    }).timeout(const Duration(seconds: 15));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return json.decode(res.body) as Map<String, dynamic>;
    }
    throw Exception('getPaymentIntent ${res.statusCode}: ${res.body}');
  }

  // ===== Bytes download (PDF/ảnh/...) =====
  Future<Uint8List> getBytes(String path,
      {Map<String, String>? headers}) async {
    final url = await _buildUrl(path); // giữ lại cách gọi cũ
    final h = await _authHeaders(headers);
    final resp = await http.get(Uri.parse(url), headers: h);
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
    return resp.bodyBytes;
  }
 Future<List<Map<String, dynamic>>> getLowOptions({
  int threshold = 10,
  int? categoryId,
}) async {
  final params = <String, dynamic>{
    'threshold': '$threshold',
    if (categoryId != null) 'categoryId': '$categoryId',
  };

  final uri = _buildUri('/inventory/low-options', params);
  final r = await http.get(uri, headers: {'Accept': 'application/json'})
      .timeout(const Duration(seconds: 15));

  if (r.statusCode != 200) {
    throw Exception('HTTP ${r.statusCode}: ${r.body}');
  }

  final data = jsonDecode(r.body);
  if (data is! List) return const [];
  return data.cast<Map<String, dynamic>>();
}
Future<List<Map<String, dynamic>>> getProductSummary({int threshold = 10, int red = 3}) async {
  final r = await get('/api/inventory/product-summary?threshold=$threshold&red=$red');
  if (r is List) return r.cast<Map<String, dynamic>>();
  return const <Map<String, dynamic>>[];
}




  Future<Set<int>> getLowVariantProductIds({
    required int threshold,
    required bool includeInactive,
  }) async {
    final data = await get('/admin/low-variant-product-ids', params: {
      'lowThreshold': '$threshold',
      'includeInactive': includeInactive ? '1' : '0',
    });
    final list = (data?['productIds'] as List?)?.cast<int>() ?? const [];
    return list.toSet();
  }
}
