import 'package:thietbidientu_fontend/models/product.dart';

class CartItem {
  final int cartItemId;      // ID của item trong giỏ
  final int? optionId;       // OptionID (nullable)
  final Product product;     // Sản phẩm (đã gán price = unitPrice)
  final int quantity;        // Số lượng
  final double unitPrice;    // Đơn giá (BE trả riêng)
  final Variant variant;     // Màu/size
  final String? color;       // NEW - giữ màu (nếu có)
  final String? size;        // NEW - giữ size (nếu có)

  CartItem({
    required this.cartItemId,
    required this.product,
    required this.quantity,
    required this.unitPrice,
    required this.variant,
    this.optionId,
    this.color,
    this.size,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    // Json sản phẩm (nếu BE trả lồng)
    final Map<String, dynamic> p =
        (json['product'] as Map<String, dynamic>?) ?? const {};

    // Lấy unitPrice ưu tiên từ root, fallback product.price hoặc 0
    final double uPrice =
        _toDouble(json['unitPrice'] ?? p['price'] ?? json['price'], dft: 0);

    // Dựng Product thủ công để đảm bảo price = unitPrice
    final product = Product(
      id: (p['id'] ?? p['productId'] ?? json['productId'] ?? '').toString(),
      name: (p['name'] ?? json['name'] ?? '').toString(),
      imageUrl:
          (p['image'] ?? p['imageUrl'] ?? json['image'] ?? json['imageUrl'] ?? '')
              .toString(),
      price: uPrice, // ✅ quan trọng: để UI cũ không bị 0 đ
    );

    // color/size có thể nằm ở root hoặc trong "variant"
    final vMap = (json['variant'] as Map?) ?? const {};
    final color = (json['color'] ?? vMap['color'])?.toString();
    final size  = (json['size']  ?? vMap['size']) ?.toString();

    return CartItem(
      cartItemId: _toInt(json['cartItemId']),
      optionId: json['optionId'] == null ? null : _toInt(json['optionId']),
      product: product,
      quantity: _toInt(json['quantity'], dft: 1),
      unitPrice: uPrice,
      variant: Variant(
        color: color,
        size: size,
      ),
      color: color,
      size: size,
    );
  }

  Map<String, dynamic> toJson() => {
        'cartItemId': cartItemId,
        'productId': product.id,  // giữ nguyên kiểu như hiện tại của app
        'quantity': quantity,
        if (optionId != null) 'optionId': optionId,
        if ((color ?? '').isNotEmpty) 'color': color,
        if ((size  ?? '').isNotEmpty) 'size' : size,
      };

  double get totalPrice => unitPrice * quantity;

  // ===== Helpers =====
  static int _toInt(dynamic v, {int dft = 0}) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? dft;
  }

  static double _toDouble(dynamic v, {double dft = 0}) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? dft;
  }
}

/// Màu / Size (có thể null)
class Variant {
  final String? color;
  final String? size;
  const Variant({this.color, this.size});
}
