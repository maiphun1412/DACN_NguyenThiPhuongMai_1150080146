import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thietbidientu_fontend/services/api_service.dart';

class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({super.key});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final _api = ApiService();

  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  // giữ orderId hiện tại + cache order items
  int _orderId = 0;
  List<Map<String, dynamic>> _orderItems = [];

  // NEW: tiêu đề hiển thị từ tên sản phẩm
  String? _titleFromItems;

  // hỏi viết đánh giá chỉ 1 lần
  bool _reviewPrompted = false;

  // ---------- helpers ----------
  int _asInt(dynamic v, [int fallback = 0]) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  Map<String, dynamic> _asStrKeyMap(dynamic o) {
    if (o is Map<String, dynamic>) return o;
    if (o is Map) return o.map((k, v) => MapEntry(k.toString(), v));
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asListOfMap(dynamic o) {
    if (o is List) return o.map((e) => _asStrKeyMap(e)).toList();
    return const <Map<String, dynamic>>[];
  }

  int _extractFirstOrderItemId(Map<String, dynamic> root) {
    final order = _asStrKeyMap(root['order']);
    List<Map<String, dynamic>> items = [];
    if (order.isNotEmpty) items = _asListOfMap(order['Items'] ?? order['items']);
    if (items.isEmpty) items = _asListOfMap(root['items']);
    if (items.isEmpty) items = _asListOfMap(root['orderItems']);
    if (items.isEmpty) return 0;

    final first = items.first;
    return _asInt(first['OrderItemID'] ?? first['orderItemId'] ?? first['id'], 0);
  }

  bool _isDeliveredVNorEN(String? s) {
    if (s == null) return false;
    final u = s.trim();
    final upper = u.toUpperCase();
    if (upper.contains('COMPLETED') || upper.contains('DELIVERED')) return true;
    return u == 'Đã giao' || u == 'Da giao';
  }

  bool get _isDeliveredNow {
    final order = _asStrKeyMap(_data?['order']);
    final shipment = _asStrKeyMap(_data?['shipment']);
    final orderStatus = (order['Status'] ?? '').toString();
    final shipStatus = (shipment['Status'] ?? '').toString();
    return _isDeliveredVNorEN(orderStatus) || _isDeliveredVNorEN(shipStatus);
  }

  Future<Map<String, String>> _authHeaders() async {
    final sp = await SharedPreferences.getInstance();
    final token =
        sp.getString('token') ?? sp.getString('accessToken') ?? sp.getString('jwt') ?? '';
    return token.isEmpty ? {} : {'Authorization': 'Bearer $token'};
  }

  Future<int> _pickFirstOrderItemId(int orderId) async {
    final headers = await _authHeaders();
    final res = await _api.get('/api/orders/$orderId/items', headers: headers);
    final list = (res is Map && res['items'] is List) ? (res['items'] as List) : const [];
    if (list.isEmpty) return 0;
    final m = Map<String, dynamic>.from(list.first as Map);
    final id = m['OrderItemID'] ?? m['orderItemId'] ?? m['id'];
    return (id is int) ? id : int.tryParse('$id') ?? 0;
  }

  // lấy danh sách items của đơn (có headers)
  Future<void> _ensureOrderItems() async {
    if (_orderId <= 0) return;
    if (_orderItems.isNotEmpty) return;

    final headers = await _authHeaders();

    // 1) /api/orders/:id (nếu trả kèm Items)
    try {
      final r1 = await _api.get('/api/orders/$_orderId', headers: headers);
      if (r1 is Map) {
        final items1 = _asListOfMap(r1['Items'] ?? r1['items']);
        if (items1.isNotEmpty) {
          _orderItems = items1;
          _data ??= {};
          final order = _asStrKeyMap(_data!['order']);
          _data!['order'] = {...order, 'Items': items1};

          // ===== NEW: set tiêu đề theo tên sản phẩm
          final names = _orderItems
              .map((e) => (e['ProductName'] ?? e['Name'] ?? '').toString())
              .where((s) => s.isNotEmpty)
              .toList();
          if (names.isNotEmpty) {
            _titleFromItems = names.length == 1
                ? names.first
                : '${names[0]} (+${names.length - 1})';
            if (mounted) setState(() {});
          }
          return;
        }
      }
    } catch (_) {/* ignore */}

    // 2) /api/orders/:id/items
    try {
      final r2 = await _api.get('/api/orders/$_orderId/items', headers: headers);
      if (r2 is Map && r2['items'] is List) {
        _orderItems = _asListOfMap(r2['items']);
        _data ??= {};
        final order = _asStrKeyMap(_data!['order']);
        _data!['order'] = {...order, 'Items': _orderItems};
      } else if (r2 is List) {
        _orderItems = _asListOfMap(r2);
        _data ??= {};
        final order = _asStrKeyMap(_data!['order']);
        _data!['order'] = {...order, 'Items': _orderItems};
      }

      if (_orderItems.isNotEmpty) {
        // ===== NEW: set tiêu đề
        final names = _orderItems
            .map((e) => (e['ProductName'] ?? e['Name'] ?? '').toString())
            .where((s) => s.isNotEmpty)
            .toList();
        if (names.isNotEmpty) {
          _titleFromItems =
              names.length == 1 ? names.first : '${names[0]} (+${names.length - 1})';
          if (mounted) setState(() {});
        }
      }
    } catch (_) {/* ignore */}
  }

  Future<void> _goWriteReviewWithPicker() async {
    await _ensureOrderItems();
    if (!mounted) return;

    if (_orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy sản phẩm của đơn này.')),
      );
      return;
    }

    if (_orderItems.length == 1) {
      final oi = _orderItems.first;
      final orderItemId = _asInt(oi['OrderItemID'] ?? oi['orderItemId'] ?? oi['id'], 0);
      if (orderItemId > 0) {
        Navigator.of(context)
            .pushNamed('/writeReview', arguments: {'orderItemId': orderItemId});
      }
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: ListView.separated(
          itemCount: _orderItems.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final it = _orderItems[i];
            final name = (it['ProductName'] ?? it['Name'] ?? 'Sản phẩm').toString();
            final oid = _asInt(it['OrderItemID'] ?? it['orderItemId'] ?? it['id'], 0);
            return ListTile(
              leading: const Icon(Icons.shopping_bag_outlined),
              title: Text(name),
              subtitle: Text('OrderItemID: $oid'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context)
                    .pushNamed('/writeReview', arguments: {'orderItemId': oid});
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _maybePromptReview() async {
    if (_reviewPrompted) return;

    if (_isDeliveredNow) {
      _reviewPrompted = true;
      await _ensureOrderItems();
      if (!mounted) return;

      final itemId = _extractFirstOrderItemId(_data ?? {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Đơn đã giao. Bạn muốn viết đánh giá sản phẩm?'),
          action: SnackBarAction(
            label: 'Đánh giá',
            onPressed: () {
              if (itemId > 0) {
                Navigator.of(context)
                    .pushNamed('/writeReview', arguments: {'orderItemId': itemId});
              } else {
                _goWriteReviewWithPicker();
              }
            },
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  // ---------- load ----------
  Future<void> _load(int orderId) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final headers = await _authHeaders();
      final res = await _api.get('/api/orders/$orderId/track', headers: headers);

      if (res is Map) {
        _data = _asStrKeyMap(res['data'] is Map ? res['data'] : res);
      } else {
        _error = 'Dữ liệu không đúng định dạng';
      }

      await _ensureOrderItems();
    } catch (e) {
      _error = '$e';
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
      await _maybePromptReview();
    }
  }

  // ---------- lifecycle ----------
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;

    int orderId = _asInt(args, 0);
    if (orderId == 0 && args is Map) {
      final m = _asStrKeyMap(args);
      orderId = _asInt(m['orderId'] ?? m['OrderID'] ?? m['id'], 0);
    }

    _orderId = orderId;
    if (orderId > 0) {
      _load(orderId);
    } else {
      _error = 'Thiếu orderId';
      _loading = false;
    }
  }

  // ---------- UI helpers ----------
  Color _statusColor(String s) {
    final u = s.toUpperCase();
    if (u.contains('PENDING')) return Colors.orange;
    if (u.contains('PROCESS') || u.contains('IN_TRANSIT')) return Colors.blue;
    if (u.contains('SHIPPED')) return Colors.teal;
    if (u.contains('CANCEL')) return Colors.red;
    if (_isDeliveredVNorEN(s)) return Colors.green;
    return Colors.grey;
  }

  Widget _statusChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _statusColor(label).withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _statusColor(label).withOpacity(.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: _statusColor(label)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: _statusColor(label), fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    int titleId = _asInt(args, 0);
    if (titleId == 0 && args is Map) {
      final m = _asStrKeyMap(args);
      titleId = _asInt(m['orderId'] ?? m['OrderID'] ?? m['id'], 0);
    }

    final canReview = _isDeliveredNow;

    return Scaffold(
      appBar: AppBar(
        title: Text('Theo dõi đơn ${titleId > 0 ? '#$titleId' : ''}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/orders');
            }
          },
          tooltip: 'Quay lại',
        ),
        actions: [
          if (canReview)
            IconButton(
              tooltip: 'Viết đánh giá',
              icon: const Icon(Icons.rate_review_outlined),
              onPressed: _goWriteReviewWithPicker,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
              ? Center(child: Text('Lỗi: $_error'))
              : _buildBody(canReview),
    );
  }

  // ---------- UI ----------
  Widget _buildBody(bool canReview) {
    final order = _asStrKeyMap(_data?['order']);
    final shipment = _asStrKeyMap(_data?['shipment']);
    final history = _asListOfMap(_data?['history']);
    final tracking = _asListOfMap(_data?['tracking']);

    final orderStatus = (order['Status'] ?? shipment['Status'] ?? 'Pending').toString();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Thông tin đơn + chip trạng thái
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Đơn hàng',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    _statusChip(orderStatus),
                  ],
                ),
                const SizedBox(height: 8),

                // ===== NEW: ưu tiên hiển thị tên sản phẩm thay cho chỉ mã đơn
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.tag_outlined, size: 18, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        (_titleFromItems != null && _titleFromItems!.isNotEmpty)
                            ? _titleFromItems!
                            : 'Mã đơn: ${order['OrderID'] ?? order['orderId'] ?? '-'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),

                if (canReview) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _goWriteReviewWithPicker,
                      icon: const Icon(Icons.rate_review_outlined),
                      label: const Text('Viết đánh giá'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Thông tin giao hàng
        if (shipment.isNotEmpty)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_shipping_outlined, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Giao hàng',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _lineItem('Trạng thái', shipment['Status'] ?? '-'),
                  _lineItem('Shipper', shipment['ShipperName'] ?? shipment['Shipper'] ?? '-'),
                ],
              ),
            ),
          ),

        const SizedBox(height: 8),

        // Lịch sử trạng thái
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timeline_outlined, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Lịch sử trạng thái',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (history.isEmpty)
                  const Text('Chưa có lịch sử')
                else
                  ...history.map((h) => _timelineTile(
                        title: '${h['OldStatus'] ?? h['From']} → ${h['NewStatus'] ?? h['To']}',
                        subtitle: '${h['ChangedAt'] ?? h['CreatedAt'] ?? ''}  ${h['Note'] ?? ''}',
                      )),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Tracking
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.map_outlined, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Hành trình (tracking)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (tracking.isEmpty)
                  const Text('Chưa có tracking')
                else
                  ...tracking.map((t) => _timelineTile(
                        icon: Icons.location_on_outlined,
                        title: '${t['Status'] ?? 'IN_TRANSIT'} — ${t['Note'] ?? ''}',
                        subtitle:
                            'Vị trí: ${t['Latitude'] ?? t['lat'] ?? '-'}, ${t['Longitude'] ?? t['lng'] ?? '-'} — ${t['CreatedAt'] ?? t['createdAt'] ?? ''}',
                      )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _lineItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _timelineTile({
    IconData icon = Icons.check_circle_outline,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.grey[700]),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
    );
  }
}
