import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thietbidientu_fontend/services/api_service.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  final _api = ApiService();
  bool _loading = false;
  List<Map<String, dynamic>> _items = [];

  // ====== NEW: cache tiêu đề theo orderId (lấy từ tên sản phẩm) ======
  final Map<int, String> _titles = {};
  bool _buildingTitles = false;

  Future<Map<String, String>> _authHeaders() async {
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString('token') ??
        sp.getString('accessToken') ??
        sp.getString('jwt') ??
        '';
    return token.isEmpty ? {} : {'Authorization': 'Bearer $token'};
  }

  String _vnd(num n) {
    final s = n.toInt().toString();
    return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.') + 'đ';
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String _asStr(dynamic v) => (v ?? '').toString();

  DateTime? _asDate(dynamic v) {
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  List<Map<String, dynamic>> _normalize(dynamic res) {
    List list = const [];
    if (res is List) list = res;
    if (res is Map && res['data'] is List) list = res['data'];
    if (res is Map && res['items'] is List) list = res['items'];
    if (res is Map && res['orders'] is List) list = res['orders'];

    return list
        .whereType<Map>()
        .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
        .map((m) {
      final id = _asInt(m['OrderID'] ?? m['id']);
      final code = _asStr(m['OrderCode'] ?? m['code'] ?? '#$id');
      final status = _asStr(m['Status'] ?? m['status'] ?? '');
      final total =
          (m['TotalAmount'] ?? m['total'] ?? m['GrandTotal'] ?? 0) as num;
      final createdAt =
          _asStr(m['CreatedAt'] ?? m['createdAt'] ?? m['created_at'] ?? '');
      return {
        'OrderID': id,
        'OrderCode': code,
        'Status': status,
        'Total': total,
        'CreatedAt': createdAt,
        '_raw': m,
      };
    }).toList();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final headers = await _authHeaders();
      dynamic res;

      // ưu tiên /api/orders/my
      try {
        res = await _api.get('/api/orders/my', headers: headers);
      } catch (_) {
        // fallback: /api/orders/me
        res = await _api.get('/api/orders/me', headers: headers);
      }

      final items = _normalize(res);
      if (!mounted) return;
      setState(() => _items = items);

      // ====== NEW: sau khi có danh sách đơn -> build tiêu đề từ tên sản phẩm ======
      final ids = items.map((e) => e['OrderID'] as int).toList();
      await _buildTitlesForOrders(ids);
    } catch (e) {
      if (!mounted) return;
      _toast('Không tải được đơn hàng: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ====== lấy danh sách OrderItems của 1 đơn với nhiều fallback ======
  Future<List<Map<String, dynamic>>> _fetchOrderItems(int orderId) async {
    final headers = await _authHeaders();

    // 1) /api/orders/:id (nếu API trả kèm items)
    try {
      final res = await _api.get('/api/orders/$orderId', headers: headers);
      final list = (res is Map && res['items'] is List) ? res['items'] : [];
      if (list is List && list.isNotEmpty) {
        return list
            .whereType<Map>()
            .map((e) => e.map((k, v) => MapEntry('$k', v)))
            .map((e) => {
                  'OrderItemID': _asInt(e['OrderItemID'] ?? e['id']),
                  'ProductID': _asInt(e['ProductID'] ?? e['productId']),
                  'Name': _asStr(e['ProductName'] ??
                      e['Name'] ??
                      e['name'] ??
                      'Sản phẩm'),
                })
            .toList();
      }
    } catch (_) {
      // ignore – thử fallback
    }

    // 2) /api/orders/:id/items
    try {
      final res = await _api.get('/api/orders/$orderId/items', headers: headers);
      final list = (res is List)
          ? res
          : (res is Map && res['items'] is List ? res['items'] : []);
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => e.map((k, v) => MapEntry('$k', v)))
            .map((e) => {
                  'OrderItemID': _asInt(e['OrderItemID'] ?? e['id']),
                  'ProductID': _asInt(e['ProductID'] ?? e['productId']),
                  'Name': _asStr(e['ProductName'] ??
                      e['Name'] ??
                      e['name'] ??
                      'Sản phẩm'),
                })
            .toList();
      }
    } catch (_) {
      // ignore – thử fallback tiếp
    }

    // 3) /api/order-item/by-order/:id
    try {
      final res =
          await _api.get('/api/order-item/by-order/$orderId', headers: headers);
      final list = (res is List)
          ? res
          : (res is Map && res['items'] is List ? res['items'] : []);
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => e.map((k, v) => MapEntry('$k', v)))
            .map((e) => {
                  'OrderItemID': _asInt(e['OrderItemID'] ?? e['id']),
                  'ProductID': _asInt(e['ProductID'] ?? e['productId']),
                  'Name': _asStr(e['ProductName'] ??
                      e['Name'] ??
                      e['name'] ??
                      'Sản phẩm'),
                })
            .toList();
      }
    } catch (_) {
      rethrow;
    }

    return <Map<String, dynamic>>[];
  }

  // ====== NEW: gộp tên 1-2 SP đầu thành tiêu đề gọn ======
  String _makeTitleFromItems(List<Map<String, dynamic>> items) {
    final names = items
        .map((e) => (e['Name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList();
    if (names.isEmpty) return '';
    if (names.length == 1) return names.first;
    if (names.length == 2) return '${names[0]}, ${names[1]}';
    return '${names[0]}, ${names[1]} (+${names.length - 2})';
  }

  // ====== NEW: build tiêu đề cho loạt đơn ======
  Future<void> _buildTitlesForOrders(List<int> orderIds) async {
    if (_buildingTitles) return;
    _buildingTitles = true;
    try {
      for (final id in orderIds) {
        if (_titles.containsKey(id)) continue;
        try {
          final items = await _fetchOrderItems(id);
          final title = _makeTitleFromItems(items);
          if (title.isNotEmpty) {
            _titles[id] = title;
            if (mounted) setState(() {});
          }
        } catch (_) {
          // bỏ qua đơn bị lỗi
        }
      }
    } finally {
      _buildingTitles = false;
    }
  }

  // ====== mở bottom sheet chọn sản phẩm để đánh giá ======
  Future<void> _openReviewPicker(int orderId) async {
    try {
      final items = await _fetchOrderItems(orderId);
      if (items.isEmpty) {
        _toast('Đơn #$orderId chưa có sản phẩm/không lấy được danh sách.');
        return;
      }
      if (items.length == 1) {
        final oi = items.first;
        if (!mounted) return;
        Navigator.pushNamed(
          context,
          '/writeReview',
          arguments: {'orderItemId': oi['OrderItemID']},
        );
        return;
      }
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        builder: (_) => SafeArea(
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final it = items[i];
              return ListTile(
                title: Text(it['Name']?.toString() ?? 'Sản phẩm'),
                subtitle: Text('OrderItemID: ${it['OrderItemID']}'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    '/writeReview',
                    arguments: {'orderItemId': it['OrderItemID']},
                  );
                },
              );
            },
          ),
        ),
      );
    } catch (e) {
      _toast('Không lấy được sản phẩm của đơn #$orderId: $e');
    }
  }

  // ====== điều kiện cho phép hủy đơn ======
  // Thay thế hoàn toàn hàm _canCancel hiện tại
  bool _canCancel(String statusRaw) {
    final s = statusRaw.toString().trim().toUpperCase();

    // Map nhanh VN/EN -> EN
    String toEN(String u) {
      // EN trước
      if (u.contains('PENDING')) return 'PENDING';
      if (u.contains('PROCESS')) return 'PROCESSING';
      if (u.contains('SHIP')) return 'SHIPPED';
      if (u.contains('DELIVER') || u.contains('COMPLETE')) return 'COMPLETED';
      if (u.contains('CANCEL')) return 'CANCELLED';

      // VN có dấu (đang dùng trong DB)
      if (u.contains('CHỜ XỬ LÝ')) return 'PENDING';
      if (u.contains('ĐANG XỬ LÝ')) return 'PROCESSING';
      if (u.contains('ĐANG GIAO')) return 'SHIPPED';
      if (u.contains('ĐÃ GIAO')) return 'COMPLETED';
      if (u.contains('ĐÃ HỦY') ||
          u.contains('ĐÃ HUỶ') ||
          u.contains('HỦY') ||
          u.contains('HUỶ')) return 'CANCELLED';

      return '';
    }

    final en = toEN(s);
    // Chỉ cho hủy khi còn PENDING/PROCESSING
    return en == 'PENDING' || en == 'PROCESSING';
  }

  // ====== gọi API hủy đơn và cập nhật UI ngay ======
  Future<void> _cancelOrder(int orderId) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Xác nhận hủy đơn'),
            content: Text('Bạn có chắc muốn hủy đơn #$orderId không?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Không'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Hủy đơn'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    try {
      final headers = await _authHeaders();
      await _api.post(
        '/api/orders/$orderId/cancel',
        null, // ← quan trọng: không gửi body để tránh lỗi cast
        headers: headers,
      );

      if (!mounted) return;
      // Cập nhật tại chỗ: set trạng thái “Đã hủy” và ẩn nút
      setState(() {
        final idx = _items.indexWhere((e) => e['OrderID'] == orderId);
        if (idx != -1) {
          _items[idx] = {
            ..._items[idx],
            'Status': 'Đã hủy',
          };
        }
      });
      _toast('Đã hủy đơn #$orderId');
    } catch (e) {
      _toast('Hủy đơn thất bại: $e');
    }
  }

  // ====== màu & chip trạng thái xịn sò ======
  Color _statusColor(String s) {
    final u = s.toUpperCase();
    if (u.contains('CANCEL')) return const Color(0xFFDC2626); // red-600
    if (u.contains('PENDING')) return const Color(0xFFF59E0B); // amber-500
    if (u.contains('PROCESS')) return const Color(0xFF3B82F6); // blue-500
    if (u.contains('SHIP')) return const Color(0xFF14B8A6); // teal-500
    if (u.contains('COMPLETE') || u.contains('DELIVER')) {
      return const Color(0xFF16A34A); // green-600
    }
    return const Color(0xFF6B7280); // gray-500
  }

  Widget _statusChip(String label) {
    final c = _statusColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: c),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: c, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _orderTile(Map<String, dynamic> it) {
    final id = it['OrderID'] as int;
    final code = it['OrderCode'] as String;
    final status = it['Status'] as String;
    final total = it['Total'] as num;
    final createdAt = _asDate(it['CreatedAt']);
    final dateStr = createdAt != null
        ? '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}'
        : _asStr(it['CreatedAt']);

    final allowCancel = _canCancel(status);

    // ====== NEW: tiêu đề ưu tiên theo tên sản phẩm ======
    final displayTitle = (_titles[id] != null && _titles[id]!.isNotEmpty)
        ? _titles[id]!
        : code; // fallback: mã đơn

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hàng 1: Tiêu đề (tên sản phẩm) + chip trạng thái
            Row(
              children: [
                Expanded(
                  child: Text(
                    displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _statusChip(status),
              ],
            ),
            const SizedBox(height: 6),
            // Hàng 1.1: mã đơn nhỏ (phụ)
            Text(
              code,
              style: const TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 8),

            // Hàng 2: Ngày đặt + Tổng
            Row(
              children: [
                Row(
                  children: [
                    const Icon(Icons.event_outlined, size: 18, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text('Ngày đặt: $dateStr'),
                  ],
                ),
                const Spacer(),
                Text(
                  _vnd(total),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Hàng nút hành động
            Row(
              children: [
                // Theo dõi
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      '/order-tracking',
                      arguments: id,
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF353839),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Theo dõi'),
                ),
                const SizedBox(width: 10),

                // Hủy đơn (Outlined đỏ – viền đỏ, text đỏ, nền trong suốt)
                if (allowCancel)
                  OutlinedButton(
                    onPressed: () => _cancelOrder(id),
                    style: OutlinedButton.styleFrom(
                      side:
                          const BorderSide(color: Color(0xFFDC2626), width: 1.2),
                      foregroundColor: const Color(0xFFDC2626),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Hủy đơn'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đơn hàng của tôi')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_items.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('Chưa có đơn hàng')),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 12),
                    itemCount: _items.length,
                    itemBuilder: (_, i) => _orderTile(_items[i]),
                  )),
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
