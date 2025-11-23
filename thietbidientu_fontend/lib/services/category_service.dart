// lib/services/category_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:thietbidientu_fontend/config.dart';
import 'package:thietbidientu_fontend/models/category.dart';
import 'package:thietbidientu_fontend/services/auth_storage.dart';

/// Dùng cho dropdown/filter ở Admin
class CategoryItem {
  final int id;
  final String name;
  final String? imageUrl;

  CategoryItem({required this.id, required this.name, this.imageUrl});

  factory CategoryItem.fromMap(Map<String, dynamic> m) {
    final rawId = m['id'] ?? m['Id'] ?? m['CategoryID'] ?? m['categoryId'];
    final int id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0;
    final String name = (m['name'] ?? m['Name'] ?? '').toString();

    String? url = (m['image'] ?? m['Image'] ?? m['imageUrl'] ?? m['Url'] ?? m['url'])?.toString();
    if (url != null && url.isNotEmpty && !url.startsWith('http')) {
      final base = AppConfig.baseUrl.endsWith('/')
          ? AppConfig.baseUrl.substring(0, AppConfig.baseUrl.length - 1)
          : AppConfig.baseUrl;
      url = url.startsWith('/') ? '$base$url' : '$base/$url';
    }
    return CategoryItem(id: id, name: name, imageUrl: url);
  }
}

class CategoryService {
  // ------- Config -------
  static const String _categoriesPath = '/api/categories';

  // ------- Public APIs (static) -------
  /// Danh sách category đầy đủ cho UI
  static Future<List<CategoryModel>> list() async {
    final uri = _buildUri(AppConfig.baseUrl, _categoriesPath);
    final body = await _getJson(uri);
    if (body == null) return [];

    // Lấy danh sách thô từ BE
    final list = _extractList(body);

    // Sắp xếp theo SortOrder (nếu BE đã trả), sau đó theo id
    int _toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    list.sort((a, b) {
      final sa = _toInt((a as Map)['sortOrder'] ?? a['SortOrder'] ?? 999);
      final sb = _toInt((b as Map)['sortOrder'] ?? b['SortOrder'] ?? 999);
      if (sa != sb) return sa.compareTo(sb);

      final ida = _toInt(a['id'] ?? a['Id'] ?? a['CategoryID'] ?? a['categoryId']);
      final idb = _toInt(b['id'] ?? b['Id'] ?? b['CategoryID'] ?? b['categoryId']);
      return ida.compareTo(idb);
    });

    // Map sang CategoryModel (giữ nguyên logic cũ, chỉ bổ sung chuẩn hoá ảnh)
    return list.map<CategoryModel>((e) {
      final m = Map<String, dynamic>.from(e as Map);

      // Chuẩn hoá key
      m['id']       = m['id'] ?? m['Id'] ?? m['CategoryID'] ?? m['categoryId'];
      m['name']     = m['name'] ?? m['Name'];
      m['parentId'] = m['parentId'] ?? m['ParentID'];

      // Ảnh → absolute
      final rawImg = (m['image'] ?? m['Image'] ?? m['imageUrl'] ?? m['Url'] ?? m['url'])?.toString();
      m['image'] = _absUrl(rawImg);

      try {
        return CategoryModel.fromJson(m);
      } catch (_) {
        // fallback nếu model không có fromJson
        return CategoryModel(
          id: m['id'] is int ? m['id'] : int.tryParse('${m['id']}') ?? 0,
          name: (m['name'] ?? '').toString(),
          parentId: m['parentId'] as int?,
          image: m['image'] as String?,
        );
      }
    }).toList();
  }

  /// Bản rút gọn cho Admin (id + name + imageUrl)
  static Future<List<CategoryItem>> listSimple() async {
    final full = await list();
    return full.map((c) => CategoryItem(id: c.id, name: c.name, imageUrl: c.image)).toList();
  }

  // ------- Helpers -------
  static Future<Map<String, String>> _headers() async {
    final h = <String, String>{'Accept': 'application/json'};
    final t = await AuthStorage.getAccessToken();
    if (t != null && t.isNotEmpty) h['Authorization'] = 'Bearer $t';
    return h;
  }

  static Uri _buildUri(String base, String path, [Map<String, String>? qp]) {
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$b$p').replace(queryParameters: qp);
  }

  static String? _absUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final b = AppConfig.baseUrl.endsWith('/')
        ? AppConfig.baseUrl.substring(0, AppConfig.baseUrl.length - 1)
        : AppConfig.baseUrl;
    return url.startsWith('/') ? '$b$url' : '$b/$url';
  }

  static Future<dynamic> _getJson(Uri url) async {
    try {
      final res = await http.get(url, headers: await _headers()).timeout(const Duration(seconds: 12));
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
      final v = body['items'] ??
          body['data'] ??
          body['results'] ??
          body['rows'] ??
          body['list'] ??
          body['recordset'] ??
          body['categories'];
      if (v is List) return v;
    }
    return const [];
  }
}
