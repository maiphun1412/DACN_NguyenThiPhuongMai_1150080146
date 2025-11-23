import 'package:thietbidientu_fontend/config.dart';

class Product {
  final String id;
  final String name;
  final double price;           // luôn là double
  final String? thumb;
  final num? discount;
  final String? description;
  final String? imageUrl;

  // mô tả ngắn để dùng ở UI (fallback từ description nếu API không có)
  final String? shortDescription;

  // phục vụ tồn kho
  final int stock;
  final bool isActive;

  // số lượng đã bán (backend update khi đơn COMPLETED)
  final int sold;

  // danh sách ảnh (URL tuyệt đối)
  final List<String> images;

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.thumb,
    this.discount,
    this.description,
    this.imageUrl,
    this.shortDescription,
    this.stock = 0,
    this.isActive = true,
    this.sold = 0,
    this.images = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'thumb': thumb,
      'discount': discount,
      'description': description,
      'imageUrl': imageUrl,
      'shortDescription': shortDescription,
      'stock': stock,
      'isActive': isActive,
      'sold': sold,
      'images': images,
    };
  }

  factory Product.fromJson(Map<String, dynamic> j) {
    final imgs = _parseImages(
      j['images'] ?? j['gallery'] ?? j['productImages'] ?? j['ProductImages'],
    );

    final resolvedThumb =
        _resolve(j['thumb'] ?? j['image'] ?? j['ImageUrl'] ?? j['Url']) ??
            (imgs.isNotEmpty ? imgs.first : null);

    final resolvedImageUrl =
        _resolve(j['imageUrl'] ?? j['Image'] ?? j['Url']) ??
            (imgs.isNotEmpty ? imgs.first : null);

    // shortDescription với nhiều key phổ biến, fallback về description
    final sd = (j['shortDescription'] ??
            j['short_desc'] ??
            j['ShortDescription'] ??
            j['ShortDesc'] ??
            j['summary'] ??
            j['subtitle'])
        ?.toString();

    final desc = (j['description'] ?? j['Description'])?.toString();

    // đọc số đã bán từ nhiều key, ưu tiên 'sold'
    final soldVal = _toInt(
      j['sold'] ??
          j['Sold'] ??
          j['soldCount'] ??
          j['totalSold'] ??
          j['sales'] ??
          j['Sales'] ??
          j['orders'] ??
          0,
    );

    return Product(
      id: (j['id'] ?? j['productId'] ?? j['ProductID'] ?? '').toString(),
      name: j['name'] ?? j['title'] ?? j['ProductName'] ?? j['Name'] ?? '',
      price: _toDouble(j['price'] ?? j['unitPrice'] ?? j['Price'] ?? 0),
      thumb: resolvedThumb,
      description: desc,
      imageUrl: resolvedImageUrl,
      shortDescription: sd ?? desc,
      discount: _toNumOrNull(j['discount'] ?? j['saleOff'] ?? j['Discount']),
      stock: _toInt(j['stock'] ?? j['Stock'] ?? 0),
      isActive: _toBool(j['isActive'] ?? j['IsActive'] ?? true),
      sold: soldVal,
      images: imgs,
    );
  }

  // ---------------- Helpers ----------------
  static String? _resolve(dynamic url) {
    if (url == null) return null;
    final s = url.toString().trim();
    if (s.isEmpty) return null;
    if (s.startsWith('http')) return s;
    final base = AppConfig.baseUrl;
    if (base.endsWith('/') && s.startsWith('/')) return base + s.substring(1);
    if (!base.endsWith('/') && !s.startsWith('/')) return '$base/$s';
    return '$base$s';
  }

  static List<String> _parseImages(dynamic v) {
    if (v is List) {
      final out = <String>[];
      for (final e in v) {
        String? u;
        if (e is String) {
          u = e;
        } else if (e is Map) {
          u = (e['url'] ??
                  e['Url'] ??
                  e['imageUrl'] ??
                  e['ImageUrl'] ??
                  e['path'] ??
                  e['Path'])
              ?.toString();
        }
        final r = _resolve(u);
        if (r != null && r.isNotEmpty) out.add(r);
      }
      return out;
    } else if (v is Map && v['data'] is List) {
      return _parseImages(v['data']);
    }
    return const [];
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) {
      final cleaned = v.replaceAll(',', '').trim();
      final parsed = num.tryParse(cleaned);
      return parsed?.toDouble() ?? 0.0;
    }
    return 0.0;
  }

  static num? _toNumOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    if (v is String) {
      final parsed = num.tryParse(v.replaceAll(',', '').trim());
      return parsed;
    }
    return null;
  }

  // chấp nhận '20', '20.0', '20.00', '1,234.50'...
  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) {
      final cleaned = v.replaceAll(',', '').trim();
      final n = num.tryParse(cleaned);
      return n?.round() ?? 0;
    }
    return 0;
  }

  static bool _toBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v == 1;
    if (v is String) {
      final s = v.toLowerCase().trim();
      return s == '1' || s == 'true' || s == 'yes';
    }
    return true;
  }
}
