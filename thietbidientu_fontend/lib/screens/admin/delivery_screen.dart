import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thietbidientu_fontend/services/api_service.dart';
import 'package:thietbidientu_fontend/services/admin/shipper_service.dart';
import 'package:thietbidientu_fontend/services/shipment_service.dart'; // 👈 THÊM

class DeliveryScreen extends StatefulWidget {
  final int orderId;
  const DeliveryScreen({super.key, required this.orderId});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  final _api = ApiService();
  final _shipperSvc = ShipperService();
  final _shipmentSvc = ShipmentService(); // 👈 THÊM

  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _order;
  Map<String, dynamic>? _assignedShipper; // ⬅️ shipper hiện tại (nếu có)
  List<Map<String, dynamic>> _statusHistory = const [];
  List<Map<String, dynamic>> _trackingPoints = const [];

  /* ---------------- helpers ---------------- */
  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? ''}') ?? 0;
  }

  String _vnd(num v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final rev = s.length - i;
      buf.write(s[i]);
      if (rev > 1 && rev % 3 == 1) buf.write('.');
    }
    return '${buf}đ';
  }

  Future<Map<String, String>?> _authHeaders() async {
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString('token') ?? sp.getString('accessToken') ?? sp.getString('jwt') ?? '';
    if (token.isEmpty) return null;
    return {'Authorization': 'Bearer $token'};
  }

  /* ---------------- load ---------------- */
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final headers = await _authHeaders();

      // 1) Lấy chi tiết đơn
      final data = await _api.get('/orders/${widget.orderId}', headers: headers);
      Map<String, dynamic> ord;
      if (data is Map && data['order'] is Map) {
        ord = Map<String, dynamic>.from(data['order'] as Map);
      } else {
        ord = Map<String, dynamic>.from(data as Map);
      }
      _order = ord;

      // 2) Lấy id shipper đã gán (đa dạng khóa)
      final assignedId = _asInt(
        ord['AssignedShipperID'] ??
        ord['assignedShipperId'] ??
        ord['ShipperID'] ??
        ord['shipperId'] ??
        ord['AssignedShipperId']
      );

      // 3) Nếu có id → lấy profile shipper
      if (assignedId > 0) {
        final ship = await _shipperSvc.getById(assignedId);
        _assignedShipper = ship; // null nếu không có trong BE
      } else {
        _assignedShipper = null;
      }

      // 4) Lịch sử trạng thái
      final his = data is Map ? (data['statusHistory'] ?? data['StatusHistory']) : null;
      if (his is List) {
        _statusHistory = his
            .cast<Map>()
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        _statusHistory = const [];
      }

      // 5) Tracking điểm
      final track = data is Map ? (data['tracking'] ?? data['Tracking'] ?? data['points']) : null;
      if (track is List) {
        _trackingPoints = track
            .cast<Map>()
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        _trackingPoints = const [];
      }

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  /* ---------------- chọn/đổi shipper ---------------- */
  Future<void> _pickShipper() async {
    // Mở bottom sheet chọn shipper (danh sách từ BE)
    final list = await _shipperSvc.getAll();
    if (!mounted) return;

    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: .8,
            minChildSize: .5,
            maxChildSize: .95,
            builder: (_, controller) {
              return Column(
                children: [
                  const SizedBox(height: 8),
                  Container(width: 40, height: 5,
                    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(999)),
                  ),
                  const SizedBox(height: 10),
                  const Text('Chọn shipper', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      controller: controller,
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final s = list[i];
                        final name = (s['Name'] ?? s['name'] ?? '').toString();
                        final phone = (s['Phone'] ?? s['phone'] ?? '').toString();
                        final vehicle = (s['Vehicle'] ?? s['vehicle'] ?? '').toString();
                        final plate = (s['LicensePlate'] ?? s['licensePlate'] ?? '').toString();
                        return ListTile(
                          leading: const Icon(Icons.delivery_dining),
                          title: Text(name.isEmpty ? 'Shipper #${s['ShipperID'] ?? s['id'] ?? ''}' : name),
                          subtitle: Text([
                            if (phone.isNotEmpty) phone,
                            if (vehicle.isNotEmpty) vehicle,
                            if (plate.isNotEmpty) plate,
                          ].join(' • ')),
                          onTap: () => Navigator.pop(ctx, s),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (picked == null) return;

    // 👉 Gọi BE gán shipper bằng ShipmentService (route mới)
    try {
      final sid = _asInt(picked['ShipperID'] ?? picked['shipperId'] ?? picked['id']);
      await _shipmentSvc.assignShipper(widget.orderId, sid);

      if (!mounted) return;
      setState(() {
        _assignedShipper = picked;
        _order?['AssignedShipperID'] = sid;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã gán shipper cho đơn #${widget.orderId}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gán shipper thất bại: $e')),
      );
    }
  }

  /* ---------------- UI ---------------- */
  @override
  Widget build(BuildContext context) {
    final title = 'Đơn giao hàng — #${widget.orderId}';
    final hasShipper = _assignedShipper != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [ IconButton(onPressed: _load, icon: const Icon(Icons.refresh)) ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickShipper,
        icon: const Icon(Icons.manage_accounts),
        label: Text(hasShipper ? 'Đổi shipper khác' : 'Gán shipper'),
        backgroundColor: hasShipper ? Colors.lightBlue.shade200 : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errView()
              : _content(hasShipper),
    );
  }

  Widget _content(bool hasShipper) {
    final total = _asInt(_order?['Total'] ?? _order?['total'] ?? 0);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.black54),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Đơn hàng', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  _chipButton(
                    onPressed: _pickShipper,
                    icon: Icons.person_add_alt,
                    text: hasShipper ? 'Đổi shipper' : 'Gán shipper',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (total > 0) Text('Tổng: ${_vnd(total)}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (!hasShipper)
                const Text('Chưa có đơn giao hàng', style: TextStyle(color: Colors.black54)),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Thông tin giao hàng
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: const [
                Icon(Icons.info_outline, color: Colors.black54),
                SizedBox(width: 8),
                Text('Thông tin giao hàng', style: TextStyle(fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 12),
              if (_assignedShipper == null)
                const Text('— Chưa có thông tin shipper —', style: TextStyle(color: Colors.black45))
              else
                _shipperInfo(_assignedShipper!),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Lịch sử trạng thái
        _expTile(
          title: 'Lịch sử trạng thái',
          child: _statusHistory.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('— trống —', style: TextStyle(color: Colors.black45)),
                )
              : Column(
                  children: _statusHistory.map((e) {
                    final s = (e['Status'] ?? e['status'] ?? '').toString();
                    final t = (e['ChangedAt'] ?? e['changedAt'] ?? e['CreatedAt'] ?? e['createdAt'] ?? '').toString();
                    final note = (e['Note'] ?? e['note'] ?? '').toString();
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.flag),
                      title: Text(s),
                      subtitle: Text([t, if (note.isNotEmpty) note].join(' • ')),
                    );
                  }).toList(),
                ),
        ),

        // Tracking điểm
        const SizedBox(height: 12),
        _expTile(
          title: 'Tracking điểm',
          child: _trackingPoints.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('— trống —', style: TextStyle(color: Colors.black45)),
                )
              : Column(
                  children: _trackingPoints.map((e) {
                    final lat = e['lat'] ?? e['Lat'];
                    final lng = e['lng'] ?? e['Lng'];
                    final ts = (e['timestamp'] ?? e['Timestamp'] ?? '').toString();
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.my_location),
                      title: Text('($lat, $lng)'),
                      subtitle: Text(ts),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _errView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 36, color: Colors.red),
            const SizedBox(height: 8),
            Text('Lỗi: $_error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ]),
        ),
      );

  Widget _shipperInfo(Map<String, dynamic> s) {
    final name = (s['Name'] ?? s['name'] ?? '').toString();
    final phone = (s['Phone'] ?? s['phone'] ?? '').toString();
    final vehicle = (s['Vehicle'] ?? s['vehicle'] ?? '').toString();
    final plate = (s['LicensePlate'] ?? s['licensePlate'] ?? '').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.delivery_dining, color: Colors.teal),
          const SizedBox(width: 8),
          Expanded(child: Text(name.isEmpty ? 'Shipper' : name, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 6),
        if (phone.isNotEmpty)
          Row(children: [
            const Icon(Icons.phone, size: 16, color: Colors.black54),
            const SizedBox(width: 6),
            Text(phone),
          ]),
        if (vehicle.isNotEmpty || plate.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.two_wheeler, size: 16, color: Colors.black54),
            const SizedBox(width: 6),
            Text([vehicle, plate].where((e) => e.toString().trim().isNotEmpty).join(' • ')),
          ]),
        ],
      ],
    );
  }

  Widget _card(Widget child) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: child,
      );

  Widget _chipButton({required VoidCallback onPressed, required IconData icon, required String text}) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: Colors.grey.shade200,
        foregroundColor: Colors.black87,
        shape: StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }

  Widget _expTile({required String title, required Widget child}) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        children: [child],
      ),
    );
  }
}
