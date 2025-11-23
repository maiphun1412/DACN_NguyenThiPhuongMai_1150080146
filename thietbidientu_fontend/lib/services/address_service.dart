import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/address.dart';

class AddressService {
  final String baseUrl;
  final String token;

  AddressService({required this.baseUrl, required this.token});

  // Lấy danh sách địa chỉ của user
  Future<List<Address>> listMine() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/addresses/mine'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', // ✅ token thật ở đây
      },
    );

    if (res.statusCode != 200) {
      throw Exception('Lỗi API: ${res.statusCode} ${res.body}');
    }

    final data = jsonDecode(res.body) as List;
    return data.map((e) => Address.fromJson(e)).toList();
  }

  // Thêm địa chỉ mới
  Future<void> create({
    required String fullName,
    required String phone,
    required String line1,
    String? ward,
    String? district,
    String? province,
    bool isDefault = false,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/addresses'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'FullName': fullName,
        'Phone': phone,
        'Line1': line1,
        'Ward': ward,
        'District': district,
        'Province': province,
        'IsDefault': isDefault,
      }),
    );

    if (res.statusCode != 201) {
      throw Exception('Không thêm được: ${res.statusCode} ${res.body}');
    }
  }

  // Đặt mặc định
  Future<void> setDefault(int addressId) async {
    final res = await http.put(
      Uri.parse('$baseUrl/api/addresses/$addressId/default'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    if (res.statusCode != 200) {
      throw Exception('Không set default được: ${res.statusCode} ${res.body}');
    }
  }

  // Xóa địa chỉ
  Future<void> remove(int addressId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/addresses/$addressId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    if (res.statusCode != 200) {
      throw Exception('Không xóa được: ${res.statusCode} ${res.body}');
    }
  }
}
