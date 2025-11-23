import 'package:shared_preferences/shared_preferences.dart';
import 'package:thietbidientu_fontend/services/api_service.dart';

class ShipmentService {
  final _api = ApiService();

  Future<Map<String, String>?> _authHeaders() async {
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString('token') ??
        sp.getString('accessToken') ??
        sp.getString('jwt') ?? '';
    if (token.isEmpty) return null;
    return {'Authorization': 'Bearer $token'};
  }

  // GET /shipments?status=...
  Future<List<dynamic>> list({String? status}) async {
    final res = await _api.get(
      '/shipments',
      params: {if (status != null && status.isNotEmpty) 'status': status},
      headers: await _authHeaders(),
    );
    return (res as List).toList();
  }

  // POST /orders/:orderId/assign-shipper
  Future<Map<String, dynamic>> assignShipper(int orderId, int shipperId) async {
    final res = await _api.post(
      '/orders/$orderId/assign-shipper',
      {'shipperId': shipperId},
      headers: await _authHeaders(),
    );
    return (res as Map).cast<String, dynamic>();
  }

  // PATCH /shipments/:id/status
  Future<void> updateStatus(int shipmentId, String status, {String? note, int? userId}) async {
    await _api.patch(
      '/shipments/$shipmentId/status',
      {
        'status': status,
        if (note != null) 'note': note,
        if (userId != null) 'userId': userId,
      },
      headers: await _authHeaders(),
    );
  }

  // POST /shipments/:id/track
  Future<void> addTrackPoint(int shipmentId, double lat, double lng, {String? note, String? status}) async {
    await _api.post(
      '/shipments/$shipmentId/track',
      {
        'lat': lat,
        'lng': lng,
        if (note != null) 'note': note,
        if (status != null) 'status': status,
      },
      headers: await _authHeaders(),
    );
  }

  // GET /orders/:orderId/track
  Future<Map<String, dynamic>> getOrderTrack(int orderId) async {
    final res = await _api.get(
      '/orders/$orderId/track',
      headers: await _authHeaders(),
    );
    return (res as Map).cast<String, dynamic>();
  }
}
