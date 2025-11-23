// lib/services/warehouse_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/warehouse.dart';

class WarehouseService {
  static Future<List<Warehouse>> fetchAll() async {
    final base = await AppConfig.ensureBaseUrl();
    final url = Uri.parse('$base/api/warehouses');

    final r = await http.get(url, headers: {'Accept': 'application/json'});
    if (r.statusCode != 200) {
      throw Exception('Lỗi tải kho: HTTP ${r.statusCode}');
    }

    final List data = json.decode(r.body) as List;
    return data
        .map((e) => Warehouse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Warehouse> create({
    required String name,
    String? address,
    String? description,
  }) async {
    final base = await AppConfig.ensureBaseUrl();
    final url = Uri.parse('$base/api/warehouses');

    final r = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'Name': name,
        'Address': address,
        'Description': description,
      }),
    );

    if (r.statusCode != 200 && r.statusCode != 201) {
      throw Exception('Lỗi tạo kho: HTTP ${r.statusCode}');
    }

    final data = json.decode(r.body) as Map<String, dynamic>;
    return Warehouse.fromJson(data);
  }

  static Future<void> update(Warehouse w) async {
    final base = await AppConfig.ensureBaseUrl();
    final url = Uri.parse('$base/api/warehouses/${w.warehouseId}');

    final r = await http.put(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'Name': w.name,
        'Address': w.address,
        'Description': w.description,
      }),
    );

    if (r.statusCode != 200) {
      throw Exception('Lỗi cập nhật kho: HTTP ${r.statusCode}');
    }
  }

  static Future<void> delete(int id) async {
    final base = await AppConfig.ensureBaseUrl();
    final url = Uri.parse('$base/api/warehouses/$id');

    final r = await http.delete(
      url,
      headers: {'Accept': 'application/json'},
    );

    if (r.statusCode != 200 && r.statusCode != 204) {
      throw Exception('Lỗi xóa kho: HTTP ${r.statusCode}');
    }
  }
}
