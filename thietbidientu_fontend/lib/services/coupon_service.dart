// lib/services/coupon_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/coupon.dart';

class CouponService {
  /// Lấy toàn bộ danh sách coupon
  static Future<List<Coupon>> fetchAll() async {
    final base = await AppConfig.ensureBaseUrl();
    final url = Uri.parse('$base/api/coupons');

    final r = await http.get(url, headers: {'Accept': 'application/json'});
    if (r.statusCode != 200) {
      throw Exception('Lỗi tải coupon: HTTP ${r.statusCode}');
    }

    final List data = json.decode(r.body) as List;
    return data
        .map((e) => Coupon.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Tạo mới 1 coupon
  static Future<Coupon> create({
    required String code,
    String? name,
    required String discountType, // 'PERCENT' | 'FIXED'
    required double discountValue,
    double? minOrderTotal,
    double? maxDiscount,
    DateTime? startDate,
    DateTime? endDate,
    int? usageLimit,
    int? perUserLimit,
    bool isActive = true,
  }) async {
    final base = await AppConfig.ensureBaseUrl();
    final url = Uri.parse('$base/api/coupons');

    final body = json.encode({
      'Code': code,
      'Name': name,
      'DiscountType': discountType,
      'DiscountValue': discountValue,
      'MinOrderTotal': minOrderTotal,
      'MaxDiscount': maxDiscount,
      'StartDate': startDate?.toIso8601String(),
      'EndDate': endDate?.toIso8601String(),
      'UsageLimit': usageLimit,
      'PerUserLimit': perUserLimit,
      'IsActive': isActive,
    });

    final r = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (r.statusCode != 200 && r.statusCode != 201) {
      throw Exception('Lỗi tạo coupon: HTTP ${r.statusCode}');
    }

    final data = json.decode(r.body) as Map<String, dynamic>;
    return Coupon.fromJson(data);
  }

  /// Cập nhật coupon hiện có
  static Future<void> update(Coupon coupon) async {
    final base = await AppConfig.ensureBaseUrl();
    final url = Uri.parse('$base/api/coupons/${coupon.couponId}');

    final body = json.encode({
      'Code': coupon.code,
      'Name': coupon.name,
      'DiscountType': coupon.discountType,
      'DiscountValue': coupon.discountValue,
      'MinOrderTotal': coupon.minOrderTotal,
      'MaxDiscount': coupon.maxDiscount,
      'StartDate': coupon.startDate?.toIso8601String(),
      'EndDate': coupon.endDate?.toIso8601String(),
      'UsageLimit': coupon.usageLimit,
      'PerUserLimit': coupon.perUserLimit,
      'IsActive': coupon.isActive,
    });

    final r = await http.put(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (r.statusCode != 200) {
      throw Exception('Lỗi cập nhật coupon: HTTP ${r.statusCode}');
    }
  }

  /// Xóa coupon theo ID
  static Future<void> delete(int couponId) async {
    final base = await AppConfig.ensureBaseUrl();
    final url = Uri.parse('$base/api/coupons/$couponId');

    final r = await http.delete(
      url,
      headers: {'Accept': 'application/json'},
    );

    if (r.statusCode != 200 && r.statusCode != 204) {
      throw Exception('Lỗi xóa coupon: HTTP ${r.statusCode}');
    }
  }
}
