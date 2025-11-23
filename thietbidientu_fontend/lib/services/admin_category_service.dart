import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:thietbidientu_fontend/config.dart';
import 'package:thietbidientu_fontend/services/auth_storage.dart';

class AdminCategoryService {
  static Future<String> _token() async => (await AuthStorage.getAccessToken()) ?? '';
  static Future<Map<String, String>> _headers({bool json = false}) async {
    final t = await _token();
    return {
      if (t.isNotEmpty) 'Authorization': 'Bearer $t',
      if (json) 'Content-Type': 'application/json',
    };
  }

  // Thử rất nhiều base-path có thể có trong dự án
  static const _LIST_BASES = <String>[
    // admin chuẩn
    '/api/admin/categories',
    '/api/admin/category',
    '/api/admin/categorys',

    // public chuẩn
    '/api/categories',
    '/api/category',
    '/api/categorys',
    '/categories',
    '/category',
    '/categorys',

    // dạng /list
    '/api/admin/categories/list',
    '/api/admin/category/list',
    '/api/categories/list',
    '/api/category/list',
    '/categories/list',
    '/category/list',

    // dạng tổng hợp theo products
    '/api/admin/products/categories',
    '/api/products/categories',
    '/api/product/categories',
    '/products/categories',
    '/product/categories',
  ];

  static List _extractList(dynamic body) {
    if (body is List) return body;
    if (body is Map) {
      return (body['items'] ??
              body['data'] ??
              body['results'] ??
              body['categories'] ??
              body['list'] ??
              body['rows'] ??
              [])
          as List;
    }
    return const [];
  }

  // ===== LIST =====
  static Future<Map<String, dynamic>> list({int page = 1, String q = ''}) async {
    final h = await _headers();
    Exception? lastErr;
    for (final base in _LIST_BASES) {
      try {
        final uri = Uri.parse('${AppConfig.baseUrl}$base')
            .replace(queryParameters: {'page': '$page', 'q': q});
        final res = await http.get(uri, headers: h);
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final body = jsonDecode(res.body);
          final items = _extractList(body);
          final total = body is Map ? (body['total'] ?? body['Total'] ?? items.length) : items.length;
          return {'items': items, 'total': total};
        }
        lastErr = Exception('GET $base -> ${res.statusCode} ${res.body}');
      } catch (e) {
        lastErr = Exception('GET $base error: $e');
      }
    }
    throw lastErr ?? Exception('No category endpoint matched.');
  }

  // ===== DETAIL =====
  static Future<Map<String, dynamic>> detail(int id) async {
    final h = await _headers();
    Exception? lastErr;
    for (final base in _LIST_BASES) {
      final path = '$base/$id';
      try {
        final uri = Uri.parse('${AppConfig.baseUrl}$path');
        final res = await http.get(uri, headers: h);
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final body = jsonDecode(res.body);
          if (body is Map) {
            final m = body['data'] ?? body['item'] ?? body['category'] ?? body;
            return Map<String, dynamic>.from(m as Map);
          }
          if (body is List && body.isNotEmpty) {
            return Map<String, dynamic>.from(body.first as Map);
          }
          return <String, dynamic>{};
        }
        lastErr = Exception('GET $path -> ${res.statusCode} ${res.body}');
      } catch (e) {
        lastErr = Exception('GET $path error: $e');
      }
    }
    throw lastErr ?? Exception('No category detail endpoint matched.');
  }

  // ===== CRUD (ưu tiên admin; fallback public nếu BE cho phép) =====
  static const _CRUD_BASES = <String>[
    '/api/admin/categories',
    '/api/admin/category',
    '/api/admin/categorys',
    '/api/categories',
    '/api/category',
    '/api/categorys',
    '/categories',
    '/category',
    '/categorys',
  ];

  static Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final h = await _headers(json: true);
    Exception? lastErr;
    for (final base in _CRUD_BASES) {
      try {
        final uri = Uri.parse('${AppConfig.baseUrl}$base');
        final res = await http.post(uri, headers: h, body: jsonEncode(body));
        if (res.statusCode == 201 || res.statusCode == 200) {
          return jsonDecode(res.body) as Map<String, dynamic>;
        }
        lastErr = Exception('POST $base -> ${res.statusCode} ${res.body}');
      } catch (e) {
        lastErr = Exception('POST $base error: $e');
      }
    }
    throw lastErr ?? Exception('No category create endpoint matched.');
  }

  static Future<Map<String, dynamic>> update(int id, Map<String, dynamic> body) async {
    final h = await _headers(json: true);
    Exception? lastErr;
    for (final base in _CRUD_BASES) {
      final path = '$base/$id';
      try {
        final uri = Uri.parse('${AppConfig.baseUrl}$path');
        final res = await http.put(uri, headers: h, body: jsonEncode(body));
        if (res.statusCode == 200) {
          return jsonDecode(res.body) as Map<String, dynamic>;
        }
        lastErr = Exception('PUT $path -> ${res.statusCode} ${res.body}');
      } catch (e) {
        lastErr = Exception('PUT $path error: $e');
      }
    }
    throw lastErr ?? Exception('No category update endpoint matched.');
  }

  static Future<void> deleteSoft(int id) async {
    final h = await _headers();
    Exception? lastErr;
    for (final base in _CRUD_BASES) {
      final path = '$base/$id';
      try {
        final uri = Uri.parse('${AppConfig.baseUrl}$path');
        final res = await http.delete(uri, headers: h);
        if (res.statusCode == 200) return;
        lastErr = Exception('DELETE $path -> ${res.statusCode} ${res.body}');
      } catch (e) {
        lastErr = Exception('DELETE $path error: $e');
      }
    }
    throw lastErr ?? Exception('No category delete endpoint matched.');
  }
}
