// lib/models/shipper_order.dart

class ShipperOrder {
  final int orderId;
  final int shipmentId; // id shipment để gọi API đổi trạng thái
  final String status; // trạng thái giao hàng (từ Shipments.Status)
  final String shippingAddress;
  final double totalAmount;
  final String customerName;
  final String customerPhone;
  final String customerEmail;

  final String paymentMethod; // COD / MOMO / CARD / ...
  final String paymentStatus; // PAID / PENDING / ...
  final double paidAmount; // số tiền đã trả (nếu có)
  final double amountToCollect; // số tiền cần thu (backend trả, nếu có)

  ShipperOrder({
    required this.orderId,
    required this.shipmentId,
    required this.status,
    required this.shippingAddress,
    required this.totalAmount,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    this.paymentMethod = '',
    this.paymentStatus = '',
    this.paidAmount = 0,
    this.amountToCollect = 0,
  });

  // ===== helper parse =====
  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  // 🔧 Lọc bớt phần trùng trong địa chỉ
  static String _normalizeAddress(String raw) {
    if (raw.trim().isEmpty) return '';

    // tách theo dấu phẩy, bỏ khoảng trắng dư
    final parts = raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '';

    // bỏ những đoạn lặp lại (so sánh không phân biệt hoa thường)
    final seen = <String>{};
    final result = <String>[];

    for (final p in parts) {
      final key = p.toLowerCase();
      if (seen.contains(key)) continue;
      seen.add(key);
      result.add(p);
    }

    return result.join(', ');
  }

  factory ShipperOrder.fromJson(Map<String, dynamic> json) {
    // cố gắng bắt đủ mọi kiểu tên cột mà backend có thể trả
    final rawOrderId =
        json['orderId'] ?? json['orderID'] ?? json['OrderID'];
    final rawShipmentId =
        json['shipmentId'] ?? json['ShipmentID'] ?? json['shipmentID'];

    final orderId = _toInt(
      rawOrderId ??
          // fallback: nếu backend không trả OrderID thì tạm dùng ShipmentID
          rawShipmentId,
    );

    final shipmentId = _toInt(
      rawShipmentId ??
          // fallback ngược lại nếu thiếu ShipmentID
          rawOrderId,
    );

    final rawAddress =
        (json['shippingAddress'] ?? json['ShippingAddress'] ?? '').toString();
    final normalizedAddress = _normalizeAddress(rawAddress);

    return ShipperOrder(
      orderId: orderId,
      shipmentId: shipmentId,
      status: (json['status'] ?? json['Status'] ?? '').toString(),
      shippingAddress: normalizedAddress,
      totalAmount:
          _toDouble(json['totalAmount'] ?? json['TotalAmount'] ?? json['Total']),
      customerName:
          (json['customerName'] ?? json['CustomerName'] ?? '').toString(),
      customerPhone:
          (json['customerPhone'] ?? json['CustomerPhone'] ?? '').toString(),
      customerEmail:
          (json['customerEmail'] ?? json['CustomerEmail'] ?? '').toString(),
      paymentMethod:
          (json['paymentMethod'] ?? json['PaymentMethod'] ?? '').toString(),
      paymentStatus:
          (json['paymentStatus'] ?? json['PaymentStatus'] ?? '').toString(),
      paidAmount: _toDouble(json['paidAmount'] ?? json['PaidAmount']),
      amountToCollect: _toDouble(
        json['amountToCollect'] ??
            json['AmountToCollect'] ??
            json['amount_to_collect'],
      ),
    );
  }
}
