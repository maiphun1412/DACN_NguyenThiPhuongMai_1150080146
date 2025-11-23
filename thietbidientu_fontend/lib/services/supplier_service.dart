// lib/services/supplier_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/supplier.dart';

class SupplierService {
  static Future<List<Supplier>> fetchAll() async {
    final base = await AppConfig.ensureBaseUrl();
    final url = Uri.parse('$base/api/suppliers');

    final r = await http.get(url, headers: {'Accept': 'application/json'});
    if (r.statusCode != 200) {
      throw Exception('Lỗi tải nhà cung cấp: HTTP ${r.statusCode}');
    }

    final List data = json.decode(r.body) as List;
    return data.map((e) => Supplier.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Supplier> create({
    required String name,
    String? email,
    String? phone,
    String? address,
  }) async {
    final base = await AppConfig.ensureBaseUrl();
    final url = Uri.parse('$base/api/suppliers');

    final r = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'Name': name,
        'Email': email,
        'Phone': phone,
        'Address': address,
      }),
    );

    if (r.statusCode != 200 && r.statusCode != 201) {
      throw Exception('Lỗi tạo nhà cung cấp: HTTP ${r.statusCode}');
    }

    final data = json.decode(r.body) as Map<String, dynamic>;
    return Supplier.fromJson(data);
  }

  static Future<void> update(Supplier s) async {
    final base = await AppConfig.ensureBaseUrl();
    final url = Uri.parse('$base/api/suppliers/${s.supplierId}');

    final r = await http.put(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'Name': s.name,
        'Email': s.email,
        'Phone': s.phone,
        'Address': s.address,
      }),
    );

    if (r.statusCode != 200) {
      throw Exception('Lỗi cập nhật nhà cung cấp: HTTP ${r.statusCode}');
    }
  }

  static Future<void> delete(int id) async {
    final base = await AppConfig.ensureBaseUrl();
    final url = Uri.parse('$base/api/suppliers/$id');

    final r = await http.delete(url, headers: {'Accept': 'application/json'});

    if (r.statusCode != 200 && r.statusCode != 204) {
      throw Exception('Lỗi xóa nhà cung cấp: HTTP ${r.statusCode}');
    }
  }
}
