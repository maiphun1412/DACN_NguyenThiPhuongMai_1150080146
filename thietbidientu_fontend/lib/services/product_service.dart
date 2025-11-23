import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/category.dart'; // CategoryModel
import '../models/product.dart';
import 'auth_storage.dart';

class ProductService {
  // Đường dẫn API
  static const String categoriesPath = '/api/categories';
  static const String productsPath   = '/api/products';

  // ---------- Helpers chung ----------
  static Future<Map<String, String>> _headers() async {
    final h = <String, String>{
      'Accept': 'application/json',
    };
    final token = await AuthStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  // Build URI an toàn, tránh // trùng
  static Uri _buildUri(String base, String path, [Map<String, String>? qp]) {
    final p = path.startsWith('/') ? path : '/$path';
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return Uri.parse('$b$p').replace(queryParameters: qp);
  }

  // Chuẩn hoá URL ảnh: nếu backend trả '/uploads/xxx' thì ghép baseUrl
  static String? _absUrl(String? url) {
    if (url == null || url.isEmpty) return null;

    // Nếu đã absolute mà lại trỏ về localhost/127.0.0.1 → thay host bằng host của baseUrl
    if (url.startsWith('http://') || url.startsWith('https://')) {
      final base = AppConfig.baseUrl.endsWith('/')
          ? AppConfig.baseUrl.substring(0, AppConfig.baseUrl.length - 1)
          : AppConfig.baseUrl;

      // lấy origin của base (vd http://10.0.2.2:3000)
      final baseUri = Uri.parse(base);
      final uri = Uri.parse(url);

      final isLocalHost = (uri.host == 'localhost' || uri.host == '127.0.0.1');
      if (isLocalHost && baseUri.hasAuthority) {
        return uri.replace(host: baseUri.host, port: baseUri.port).toString();
      }
      return url; // absolute ok
    }

    // relative → ghép base
    final base = AppConfig.baseUrl.endsWith('/')
        ? AppConfig.baseUrl.substring(0, AppConfig.baseUrl.length - 1)
        : AppConfig.baseUrl;
    return url.startsWith('/') ? '$base$url' : '$base/$url';
  }

  static Future<dynamic> _getJson(Uri url) async {
    try {
      final res = await http
          .get(url, headers: await _headers())
          .timeout(const Duration(seconds: 15));
      // debug
      // ignore: avoid_print
      print('GET $url -> ${res.statusCode}');
      if (res.statusCode ~/ 100 != 2) {
        // ignore: avoid_print
        print(res.body);
        return null;
      }
      return jsonDecode(res.body);
    } on TimeoutException {
      // ignore: avoid_print
      print('GET $url -> TIMEOUT');
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('GET $url -> ERROR: $e');
      return null;
    }
  }

  static List _extractList(dynamic body) {
    if (body is List) return body;
    if (body is Map) {
      if (body['data'] is List) return body['data'];
      if (body['items'] is List) return body['items'];
      if (body['recordset'] is List) return body['recordset'];
      if (body['result'] is List) return body['result'];
      if (body['results'] is List) return body['results'];
      if (body['rows'] is List) return body['rows'];
      if (body['data'] is Map && body['data']['items'] is List) {
        return body['data']['items'];
      }
    }
    return const [];
  }

  // ---------- Public APIs ----------

  /// Danh mục sản phẩm
  static Future<List<CategoryModel>> fetchCategories() async {
    final url = _buildUri(AppConfig.baseUrl, categoriesPath);
    final body = await _getJson(url);
    if (body == null) return [];

    final list = _extractList(body);
    return list.map<CategoryModel>((e) {
      final m = Map<String, dynamic>.from(e as Map);

      // ép id/parentId an toàn
      final rawId = m['id'];
      final id = (rawId is int) ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0;

      final rawParent = m['parentId'];
      final parentId = (rawParent is int) ? rawParent : int.tryParse(rawParent?.toString() ?? '');

      // Chuẩn hoá ảnh (phòng trường hợp backend trả relative)
      final img = _absUrl((m['image'] as String?) ?? (m['imageUrl'] as String?));

      return CategoryModel(
        id: id,
        name: (m['name'] ?? '').toString(),
        parentId: parentId,
        image: img,
      );
    }).toList();
  }

  /// Sản phẩm (lọc theo category, tìm kiếm q)
  /// Backend dùng limit/offset; page dùng cho UI → offset = (page-1)*limit
  static Future<List<Product>> fetchProducts({
    String? categoryId,
    int page = 1,
    int limit = 20,
    String q = '',
  }) async {
    final safePage = page <= 0 ? 1 : page;
    final offset = (safePage - 1) * limit;

    final qp = <String, String>{
      if (categoryId != null && categoryId.isNotEmpty) ...{
        'categoryId': categoryId, // camelCase
        'CategoryID': categoryId, // PascalCase
        'category':  categoryId,  // fallback phổ biến
      },
      'limit': '$limit',
      'offset': '$offset',
      if (q.isNotEmpty) 'q': q,
      // Giữ page nếu backend có dùng (không ảnh hưởng nếu bỏ qua)
      'page': '$safePage',
    };

    final url = _buildUri(AppConfig.baseUrl, productsPath, qp);
    final body = await _getJson(url);
    if (body == null) return [];

    final list = _extractList(body);
    return list.map<Product>((e) {
      final m = Map<String, dynamic>.from(e as Map);
      // Chuẩn hoá 1–2 field ảnh thường gặp
      m['image']  = _absUrl(m['image'] as String? ?? m['imageUrl'] as String?);
      m['thumb']  = _absUrl(m['thumb'] as String? ?? m['thumbnail'] as String?);
      m['images'] = (m['images'] is List)
          ? (m['images'] as List).map((x) => _absUrl(x?.toString())).toList()
          : m['images'];
      return Product.fromJson(m);
    }).toList();
  }

  /// Tiện ích: lấy sản phẩm theo Category nhanh
  static Future<List<Product>> fetchProductsByCategory(
    String categoryId, {
    int page = 1,
    int limit = 20,
    String q = '',
  }) {
    return fetchProducts(
      categoryId: categoryId,
      page: page,
      limit: limit,
      q: q,
    );
  }
}
