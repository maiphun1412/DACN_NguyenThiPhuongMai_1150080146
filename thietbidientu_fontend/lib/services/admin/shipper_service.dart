// lib/services/admin/shipper_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thietbidientu_fontend/services/api_service.dart';

class ShipperService {
  final _api = ApiService();

  // Trả map header (rỗng nếu không có token) để đỡ null
  Future<Map<String, String>> _authHeaders() async {
    final sp = await SharedPreferences.getInstance();
    final token =
        sp.getString('token') ??
        sp.getString('accessToken') ??
        sp.getString('jwt');
    if (token == null || token.isEmpty) return {};
    return {'Authorization': 'Bearer $token'};
  }

  // ================= SHIPPERS =================

  /// GET /shippers?q=&page=&size=&isActive=
  /// Trả về Map { items, total, page, size }
  Future<Map<String, dynamic>> list({
    String q = '',
    int page = 1,
    int size = 20,
    bool? isActive,
  }) async {
    final res = await _api.get(
      '/shippers',
      params: <String, dynamic>{
        'page': page,
        'size': size,
        if (q.trim().isNotEmpty) 'q': q.trim(),
        if (isActive != null) 'isActive': isActive.toString(),
      },
      headers: await _authHeaders(),
    );
    return (res as Map).cast<String, dynamic>();
  }

  /// Tìm nhanh: ưu tiên helpers, fallback về list Active
  /// GET /shippers/helpers/search/all?q=
  Future<List<dynamic>> searchAll([String q = '']) async {
    try {
      final res = await _api.get(
        '/shippers/helpers/search/all',
        params: {'q': q},
        headers: await _authHeaders(),
      );
      return (res as List).toList();
    } catch (_) {
      // Fallback: gọi list Active, ép kiểu Map để lấy items
      final Map<String, dynamic> m =
          await list(q: q, page: 1, size: 50, isActive: true);
      final List<dynamic> items = (m['items'] as List?) ?? <dynamic>[];
      return List<dynamic>.from(items);
    }
  }

  /// ⬇️ BỔ SUNG: trả tất cả shipper (dùng cho UI chọn/đổi shipper)
  Future<List<Map<String, dynamic>>> getAll({bool? isActive}) async {
    // ưu tiên helpers; nếu BE không có helpers thì fallback sang list()
    try {
      final arr = await searchAll('');
      return arr
          .cast<Map>()
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      final m = await list(q: '', page: 1, size: 200, isActive: isActive);
      final items = (m['items'] as List?) ?? const [];
      return items
          .cast<Map>()
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
  }

  /// ⬇️ BỔ SUNG: lấy chi tiết 1 shipper theo id (dùng để hiển thị thông tin đã gán)
  Future<Map<String, dynamic>?> getById(int id) async {
    try {
      final res = await detail(id);
      if (res is Map) {
        if (res['shipper'] is Map) {
          return Map<String, dynamic>.from(res['shipper'] as Map);
        }
        return Map<String, dynamic>.from(res);
      }
      return null;
    } catch (_) {
      // fallback: tải all rồi lọc
      final all = await getAll();
      for (final s in all) {
        final sid = _asInt(s['ShipperID'] ?? s['shipperId'] ?? s['id']);
        if (sid == id) return s;
      }
      return null;
    }
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? ''}') ?? 0;
  }

  // CRUD (nếu backend có)
  Future<dynamic> detail(int id) async =>
      _api.get('/shippers/$id', headers: await _authHeaders());

  Future<dynamic> create(Map<String, dynamic> body) async =>
      _api.post('/shippers', body, headers: await _authHeaders());

  Future<dynamic> update(int id, Map<String, dynamic> body) async =>
      _api.put('/shippers/$id', body, headers: await _authHeaders());

  Future<dynamic> remove(int id) async =>
      _api.delete('/shippers/$id', headers: await _authHeaders());

  /// Bật/tắt hoạt động – giữ /:id/toggle (đã khai báo tương thích ở backend)
  Future<dynamic> toggle(int id) async =>
      _api.patch('/shippers/$id/toggle', {}, headers: await _authHeaders());

  // ================= ORDERS / SHIPMENTS =================

  /// POST /orders/:orderId/assign-shipper
  Future<dynamic> assignOrder(int orderId, int shipperId) async {
    return _api.post(
      '/orders/$orderId/assign-shipper',
      {'shipperId': shipperId},
      headers: await _authHeaders(),
    );
  }

  /// (Nếu có route unassign thì dùng; không có thì bỏ qua)
  Future<dynamic> unassignOrder(int orderId) async {
    return _api.post(
      '/orders/$orderId/unassign-shipper',
      {},
      headers: await _authHeaders(),
    );
  }

  /// PATCH /shipments/:shipmentId/status
  Future<dynamic> updateShipmentStatus(
    int shipmentId,
    String status, {
    String note = '',
    int? userId,
  }) async {
    return _api.patch(
      '/shipments/$shipmentId/status',
      {
        'status': status,
        if (note.isNotEmpty) 'note': note,
        if (userId != null) 'userId': userId,
      },
      headers: await _authHeaders(),
    );
  }

  /// POST /shipments/:shipmentId/track
  Future<dynamic> trackShipment(
    int shipmentId, {
    required double lat,
    required double lng,
    String note = '',
    String? status,
  }) async {
    return _api.post(
      '/shipments/$shipmentId/track',
      {
        'lat': lat,
        'lng': lng,
        if (note.isNotEmpty) 'note': note,
        if (status != null && status.isNotEmpty) 'status': status,
      },
      headers: await _authHeaders(),
    );
  }

  // ================= SHIPPER (ROLE SHIPPER – ĐƠN CỦA TÔI) =================

  /// GET /shipper/my-shipments
  /// Trả về List các đơn đã gán cho shipper đang đăng nhập
  Future<List<dynamic>> myShipments() async {
    final res = await _api.get(
      '/shipper/my-shipments',
      headers: await _authHeaders(),
    );

    if (res is List) {
      return List<dynamic>.from(res);
    }
    if (res is Map && res['items'] is List) {
      return List<dynamic>.from(res['items'] as List);
    }
    if (res is Map && res['data'] is List) {
      return List<dynamic>.from(res['data'] as List);
    }
    return <dynamic>[];
  }
}
