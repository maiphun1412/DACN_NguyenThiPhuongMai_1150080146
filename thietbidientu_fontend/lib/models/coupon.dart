// lib/models/coupon.dart
class Coupon {
  final int couponId;
  final String code;
  final String? name;
  final String discountType; // 'PERCENT' | 'FIXED'
  final double discountValue;
  final double? minOrderTotal;
  final double? maxDiscount;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? usageLimit;
  final int? perUserLimit;
  final bool isActive;

  Coupon({
    required this.couponId,
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.isActive,
    this.name,
    this.minOrderTotal,
    this.maxDiscount,
    this.startDate,
    this.endDate,
    this.usageLimit,
    this.perUserLimit,
  });

  factory Coupon.fromJson(Map<String, dynamic> j) {
    DateTime? _dt(v) => (v == null) ? null : DateTime.tryParse(v.toString());
    double? _d(v) => (v == null) ? null : double.tryParse(v.toString());

    return Coupon(
      couponId: int.tryParse(j['CouponID'].toString()) ?? 0,
      code: j['Code'] ?? '',
      name: j['Name'],
      discountType: (j['DiscountType'] ?? '').toString().toUpperCase(),
      discountValue: double.tryParse(j['DiscountValue'].toString()) ?? 0,
      minOrderTotal: _d(j['MinOrderTotal']),
      maxDiscount: _d(j['MaxDiscount']),
      startDate: _dt(j['StartDate']),
      endDate: _dt(j['EndDate']),
      usageLimit: (j['UsageLimit'] == null)
          ? null
          : int.tryParse(j['UsageLimit'].toString()),
      perUserLimit: (j['PerUserLimit'] == null)
          ? null
          : int.tryParse(j['PerUserLimit'].toString()),
      isActive: (j['IsActive'] is bool)
          ? j['IsActive'] as bool
          : (j['IsActive']?.toString() == '1' ||
              j['IsActive']?.toString().toLowerCase() == 'true'),
    );
  }
}
