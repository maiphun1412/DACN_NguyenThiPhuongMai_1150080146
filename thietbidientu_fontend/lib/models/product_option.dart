class ProductOption {
  final int id;          // OptionID
  final int productId;   // ProductID
  final String size;
  final String color;
  final int stock;

  ProductOption({
    required this.id,
    required this.productId,
    required this.size,
    required this.color,
    required this.stock,
  });

  factory ProductOption.fromJson(Map<String, dynamic> j) {
    int _toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.round();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return ProductOption(
      id: _toInt(j['OptionID'] ?? j['id'] ?? j['optionId']),
      productId: _toInt(j['ProductID'] ?? j['productId']),
      size: (j['Size'] ?? j['size'] ?? '').toString(),
      color: (j['Color'] ?? j['color'] ?? '').toString(),
      stock: _toInt(j['Stock'] ?? j['stock'] ?? 0),
    );
  }
}
