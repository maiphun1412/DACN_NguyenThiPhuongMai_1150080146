import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:thietbidientu_fontend/config.dart';
import 'package:thietbidientu_fontend/services/auth_storage.dart';


class AdminProductService {
  static Future<String> _token() async =>
      (await AuthStorage.getAccessToken()) ?? '';

  // ===== List & Detail =====
  static Future<Map<String, dynamic>> list({int page = 1, String q = ''}) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/api/admin/products?page=$page&q=$q');
    final res = await http.get(uri, headers: {'Authorization': 'Bearer ${await _token()}'});
    if (res.statusCode != 200) throw Exception(res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> detail(int id) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/api/admin/products/$id');
    final res = await http.get(uri, headers: {'Authorization': 'Bearer ${await _token()}'});
    if (res.statusCode != 200) throw Exception(res.body);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ===== Create / Update (JSON) =====
  static Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/api/admin/products');
    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${await _token()}',
        'Content-Type': 'application/json'
      },
      body: jsonEncode(body),
    );
    if (res.statusCode != 201) throw Exception(res.body);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> update(int id, Map<String, dynamic> body) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/api/admin/products/$id');
    final res = await http.put(
      uri,
      headers: {
        'Authorization': 'Bearer ${await _token()}',
        'Content-Type': 'application/json'
      },
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) throw Exception(res.body);
    return jsonDecode(res.body);
  }

  static Future<void> deleteSoft(int id) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/api/admin/products/$id');
    final res = await http.delete(uri, headers: {'Authorization': 'Bearer ${await _token()}'});
    if (res.statusCode != 200) throw Exception(res.body);
  }

  // ===== Create/Update kèm ảnh (multipart) =====
  static Future<Map<String, dynamic>> createWithImages({
    required Map<String, String> fields,
    List<File> files = const [],
    int? mainIndex,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/api/admin/products');
    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer ${await _token()}'
      ..fields.addAll(fields);
    if (mainIndex != null) req.fields['mainIndex'] = mainIndex.toString();
    for (final f in files) {
      req.files.add(await http.MultipartFile.fromPath('files', f.path));
    }
    final res = await http.Response.fromStream(await req.send());
    if (res.statusCode != 201) throw Exception(res.body);
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updateWithImages({
    required int id,
    Map<String, String> fields = const {},
    List<File> files = const [],
    int? mainIndex,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/api/admin/products/$id');
    final req = http.MultipartRequest('PUT', uri)
      ..headers['Authorization'] = 'Bearer ${await _token()}'
      ..fields.addAll(fields);
    if (mainIndex != null) req.fields['mainIndex'] = mainIndex.toString();
    for (final f in files) {
      req.files.add(await http.MultipartFile.fromPath('files', f.path));
    }
    final res = await http.Response.fromStream(await req.send());
    if (res.statusCode != 200) throw Exception(res.body);
    return jsonDecode(res.body);
  }

  // ===== Ảnh =====
  static Future<void> setMainImage(int productId, int imageId) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/api/admin/products/$productId/images/$imageId/main');
    final res = await http.put(uri, headers: {'Authorization': 'Bearer ${await _token()}'});
    if (res.statusCode != 200) throw Exception(res.body);
  }

  static Future<void> deleteImage(int imageId) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/api/admin/products/images/$imageId');
    final res = await http.delete(uri, headers: {'Authorization': 'Bearer ${await _token()}'});
    if (res.statusCode != 200) throw Exception(res.body);
  }

  // ===== Biến thể (options) =====
  static Future<Map<String, dynamic>> addOption(int productId,
      {String? size, String? color, int stock = 0}) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/api/admin/products/$productId/options');
    final res = await http.post(uri,
        headers: {
          'Authorization': 'Bearer ${await _token()}',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({'Size': size, 'Color': color, 'Stock': stock}));
    if (res.statusCode != 201) throw Exception(res.body);
    return jsonDecode(res.body);
  }

  static Future<void> updateOption(int optionId,
      {String? size, String? color, int? stock}) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/api/admin/products/options/$optionId');
    final res = await http.put(uri,
        headers: {
          'Authorization': 'Bearer ${await _token()}',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({'Size': size, 'Color': color, 'Stock': stock}));
    if (res.statusCode != 200) throw Exception(res.body);
  }

  static Future<void> deleteOption(int optionId) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/api/admin/products/options/$optionId');
    final res = await http.delete(uri, headers: {'Authorization': 'Bearer ${await _token()}'});
    if (res.statusCode != 200) throw Exception(res.body);
  }
}
