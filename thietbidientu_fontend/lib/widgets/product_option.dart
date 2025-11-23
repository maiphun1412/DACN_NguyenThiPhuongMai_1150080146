class ProductOption {
  final String size;
  final String color;
  final int stock;

  ProductOption({
    required this.size,
    required this.color,
    required this.stock,
  });

  factory ProductOption.fromJson(Map<String, dynamic> json) {
    return ProductOption(
      size: (json['Size'] ?? json['size'] ?? '').toString(),
      color: (json['Color'] ?? json['color'] ?? '').toString(),
      stock: _toInt(json['Stock'] ?? json['stock'] ?? 0),
    );
  }

  Map<String, dynamic> toJson() => {
        'size': size,
        'color': color,
        'stock': stock,
      };

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) {
      final n = num.tryParse(v.replaceAll(',', '').trim());
      return n?.round() ?? 0;
    }
    return 0;
  }

  ProductOption copyWith({String? size, String? color, int? stock}) {
    return ProductOption(
      size: size ?? this.size,
      color: color ?? this.color,
      stock: stock ?? this.stock,
    );
  }
}
