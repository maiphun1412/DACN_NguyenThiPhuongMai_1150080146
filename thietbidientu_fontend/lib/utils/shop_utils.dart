class SoldTracker {
  // Lưu tạm ở client: key = productId (string), value = đã bán thêm (local)
  static final Map<String, int> _map = {};
  static int get(String productId) => _map[productId] ?? 0;
  static void increase(String productId, [int delta = 1]) {
    _map[productId] = get(productId) + delta;
  }
}

/// Ước lượng ngày giao theo thành phố — dùng ở trang thanh toán
int estimateDaysByCity(String? city) {
  final s = (city ?? '').toLowerCase().trim();
  if (s.isEmpty) return 3;
  if (s.contains('hồ chí minh') || s.contains('ho chi minh') || s.contains('hcm')) return 1;
  if (s.contains('đà nẵng') || s.contains('da nang')) return 2;
  if (s.contains('cần thơ') || s.contains('can tho')) return 2;
  if (s.contains('hà nội') || s.contains('ha noi') || s.contains('hn')) return 3;
  return 3;
}

String etaLabel(String? city) {
  final d = estimateDaysByCity(city);
  return d == 1 ? 'Giao nhanh: nhận ngày mai' : 'Giao nhanh: nhận trong $d ngày';
}
