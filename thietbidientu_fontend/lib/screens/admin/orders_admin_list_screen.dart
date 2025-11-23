// lib/screens/admin/order_admin_screen.dart
import 'dart:async';
import 'dart:io'; // <- thêm
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thietbidientu_fontend/services/api_service.dart';

// mở file PDF tạm
import 'package:path_provider/path_provider.dart'; // <- thêm
import 'package:open_filex/open_filex.dart';        // <- thêm

/// Điều hướng sang màn giao hàng
import 'delivery_screen.dart'; // <- để push DeliveryScreen(orderId: ...)

class OrderAdminScreen extends StatefulWidget {
  const OrderAdminScreen({super.key});
  @override
  State<OrderAdminScreen> createState() => _OrderAdminScreenState();
}

class _OrderAdminScreenState extends State<OrderAdminScreen> {
  final _api = ApiService();

  bool _loading = true;
  String? _error;

  // danh sách đơn
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _view = [];

  // filter
  String? _statusFilter; // null = tất cả
  final List<_StatusTab> _tabs = const [
    _StatusTab(null,        'Tất cả'),
    _StatusTab('PENDING',   'Chờ xử lý'),
    _StatusTab('PROCESSING','Đang xử lý'),
    _StatusTab('SHIPPED',   'Đang giao'), // trạng thái đơn (không phải shipment)
    _StatusTab('COMPLETED', 'Đã giao'),
    _StatusTab('CANCELLED', 'Đã hủy'),
  ];

  // tìm kiếm
  final _searchCtrl = TextEditingController();
  Timer? _deb;

  // expand & cache items theo từng đơn
  final Set<int> _expanded = {};
  final Map<int, List<Map<String, dynamic>>> _itemsCache = {};
  final Map<int, bool> _loadingItems = {};
  final Map<int, String?> _errorItems = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _deb?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /* ---------------- helpers parse/format ---------------- */

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  num _toNum(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? 0;
    return 0;
  }

  DateTime? _parseDt(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    try { return DateTime.parse(v.toString()); } catch (_) { return null; }
  }

  String _fmtDateTime(DateTime? dt) {
    if (dt == null) return '';
    final hh = dt.hour.toString().padLeft(2,'0');
    final mm = dt.minute.toString().padLeft(2,'0');
    final d  = dt.day.toString().padLeft(2,'0');
    final m  = dt.month.toString().padLeft(2,'0');
    return '$hh:$mm  $d/$m/${dt.year}';
  }

  String _vnd(num v) {
    final s = v.toStringAsFixed(0);
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final rev = s.length - i;
      b.write(s[i]);
      if (rev > 1 && rev % 3 == 1) b.write('.');
    }
    return '${b.toString()}đ';
  }

  Color _statusBg(String s) {
    switch (s) {
      case 'COMPLETED':  return Colors.green.withOpacity(.15);
      case 'SHIPPED':
      case 'PROCESSING': return Colors.blue.withOpacity(.12);
      case 'PENDING':    return Colors.orange.withOpacity(.12);
      case 'CANCELLED':  return Colors.red.withOpacity(.12);
      default:           return Colors.grey.withOpacity(.15);
    }
  }

  Color _statusFg(String s) {
    switch (s) {
      case 'COMPLETED':  return Colors.green.shade700;
      case 'SHIPPED':
      case 'PROCESSING': return Colors.blue.shade700;
      case 'PENDING':    return Colors.orange.shade800;
      case 'CANCELLED':  return Colors.red.shade700;
      default:           return Colors.grey.shade700;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'PENDING':    return 'Chờ xử lý';
      case 'PROCESSING': return 'Đang xử lý';
      case 'SHIPPED':    return 'Đang giao';
      case 'COMPLETED':  return 'Đã giao';
      case 'CANCELLED':  return 'Đã hủy';
      default:           return s;
    }
  }

  /* ---------------- api helpers ---------------- */

  Future<Map<String, String>?> _authHeaders() async {
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString('token') ?? sp.getString('accessToken') ?? sp.getString('jwt') ?? '';
    if (token.isEmpty) return null;
    return {'Authorization': 'Bearer $token'};
  }

  /* ---------------- load list ---------------- */

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });

    try {
      final headers = await _authHeaders();
      final data = await _api.get('/api/orders', headers: headers);

      List raw;
      if (data is List) {
        raw = data;
      } else if (data is Map && data['data'] is List) {
        raw = data['data'];
      } else {
        raw = const [];
      }

      _all = raw
          .cast<Map>()
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      _applyFilters();

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _applyFilters() {
    Iterable<Map<String, dynamic>> list = _all;

    // search
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((o) {
        final id = (o['OrderID'] ?? o['orderId'] ?? '').toString();
        final customer = (o['CustomerName'] ?? o['customerName'] ?? '').toString().toLowerCase();
        final address = (o['ShippingAddress'] ?? o['shippingAddress'] ?? '').toString().toLowerCase();
        return id.contains(q) || customer.contains(q) || address.contains(q);
      });
    }

    // status
    if (_statusFilter != null) {
      final code = _statusFilter!;
      list = list.where((o) => ((o['Status'] ?? o['status'] ?? '') as String).toUpperCase() == code);
    }

    _view = list.toList();
  }

  /* ---------------- load items per order (lazy) ---------------- */

  Future<void> _fetchItemsIfNeeded(int orderId) async {
    if (_itemsCache.containsKey(orderId) || _loadingItems[orderId] == true) return;

    _loadingItems[orderId] = true;
    _errorItems[orderId] = null;
    setState(() {});

    try {
      final headers = await _authHeaders();
      final data = await _api.get('/api/orders/$orderId', headers: headers);

      List items;
      if (data is Map && data['Items'] is List) {
        items = data['Items'] as List;
      } else if (data is Map && data['items'] is List) {
        items = data['items'] as List;
      } else {
        items = const [];
      }

      final parsed = items
          .cast<Map>()
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      _itemsCache[orderId] = parsed;
    } catch (e) {
      _errorItems[orderId] = e.toString();
    } finally {
      _loadingItems[orderId] = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _refresh() => _load();

  /* ---------------- update status (đơn hàng) ---------------- */

  Future<void> _updateStatus(int orderId, String newStatus) async {
    try {
      final headers = await _authHeaders();
      await _api.post('/api/orders/$orderId/status', {'status': newStatus}, headers: headers);

      // cập nhật local
      final idx = _all.indexWhere((e) => _toInt(e['OrderID'] ?? e['orderId']) == orderId);
      if (idx != -1) {
        _all[idx]['Status'] = newStatus;
        _applyFilters();
        setState(() {});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã đổi trạng thái đơn sang ${_statusLabel(newStatus)}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đổi trạng thái thất bại: $e')),
      );
    }
  }

  /* ---------------- export invoice (PDF) ---------------- */

  Future<void> _exportInvoice(int orderId) async {
    try {
      final bytes = await _api.getBytes('/api/orders/$orderId/invoice',
          headers: await _authHeaders());
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/invoice_$orderId.pdf');
      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã tải hóa đơn PDF')),
      );
      await OpenFilex.open(file.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xuất hóa đơn thất bại: $e')),
      );
    }
  }

  // ------- PREVIEW BOTTOM SHEET: xem trước hóa đơn rồi mới xuất -------
  Future<void> _openInvoicePreview(Map<String, dynamic> order) async {
    final orderId = _toInt(order['OrderID'] ?? order['orderId']);
    if (!_itemsCache.containsKey(orderId)) {
      await _fetchItemsIfNeeded(orderId);
    }
    final items = _itemsCache[orderId] ?? const [];

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final total = _toNum(order['Total'] ?? order['total']);
        final name  = (order['CustomerName'] ?? order['customerName'] ?? '').toString();
        final addr  = (order['ShippingAddress'] ?? order['shippingAddress'] ?? '').toString();
        final pay   = (order['PaymentMethod'] ?? order['paymentMethod'] ?? '').toString();
        final created = _fmtDateTime(_parseDt(order['CreatedAt'] ?? order['createdAt']));

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * .80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 40, height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Center(
                    child: Text('Xem trước hóa đơn',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Đơn hàng #$orderId',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        if (name.isNotEmpty)
                          Row(children: [
                            const Icon(Icons.person, size: 16, color: Colors.black54),
                            const SizedBox(width: 6),
                            Expanded(child: Text(name)),
                          ]),
                        if (addr.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Icon(Icons.place, size: 16, color: Colors.black54),
                            const SizedBox(width: 6),
                            Expanded(child: Text(addr)),
                          ]),
                        ],
                        if (created.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(children: [
                            const Icon(Icons.schedule, size: 16, color: Colors.black54),
                            const SizedBox(width: 6),
                            Text(created),
                          ]),
                        ],
                        if (pay.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(children: [
                            const Icon(Icons.payment, size: 16, color: Colors.black54),
                            const SizedBox(width: 6),
                            Text('Thanh toán: ${pay.toUpperCase()}'),
                          ]),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  Expanded(
                    child: items.isEmpty
                        ? const Center(child: Text('Không có sản phẩm để hiển thị'))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const Divider(height: 16),
                            itemBuilder: (_, i) {
                              final it = items[i];
                              final pname = (it['ProductName'] ?? it['name'] ?? '').toString();
                              final qty   = _toInt(it['Quantity'] ?? it['qty'] ?? it['quantity']);
                              final price = _toNum(it['UnitPrice'] ?? it['price'] ?? 0);
                              return Row(
                                children: [
                                  Expanded(
                                    child: Text(pname,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('x$qty'),
                                  const SizedBox(width: 12),
                                  Text(_vnd(price), style: const TextStyle(color: Colors.black54)),
                                ],
                              );
                            },
                          ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tổng thanh toán',
                                style: TextStyle(fontSize: 12, color: Colors.black54)),
                            Text(_vnd(total),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 18)),
                          ],
                        ),
                        const Spacer(),
                        OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Đóng'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            await _exportInvoice(orderId);
                          },
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Xuất PDF'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /* ---------------- UI ---------------- */

  // Nút action “vừa tay”: cao tối thiểu 44, padding vừa, label ellipsis khi hẹp.
  Widget _actionButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label, overflow: TextOverflow.ellipsis),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          tapTargetSize: MaterialTapTargetSize.padded,
          visualDensity: VisualDensity.standard,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đơn hàng'),
        actions: [ IconButton(onPressed: _load, icon: const Icon(Icons.refresh)) ],
      ),
      body: Column(
        children: [
          // ô tìm kiếm
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Tìm mã đơn / tên khách / địa chỉ…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) {
                _deb?.cancel();
                _deb = Timer(const Duration(milliseconds: 300), () {
                  setState(_applyFilters);
                });
              },
              onSubmitted: (_) => setState(_applyFilters),
            ),
          ),

          // dải filter theo trạng thái
          SizedBox(
            height: 56,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              scrollDirection: Axis.horizontal,
              itemCount: _tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final t = _tabs[i];
                final selected = _statusFilter == t.code;
                return ChoiceChip(
                  label: Text(t.label),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _statusFilter = t.code;
                      _applyFilters();
                    });
                  },
                );
              },
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _errorView()
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: _view.isEmpty
                            ? ListView(children: const [
                                SizedBox(height: 120),
                                Center(child: Text('Không có đơn hàng')),
                              ])
                            : ListView.builder(
                                itemCount: _view.length,
                                itemBuilder: (_, i) => _orderCard(_view[i]),
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 36, color: Colors.red),
              const SizedBox(height: 8),
              Text('Lỗi tải đơn hàng:\n$_error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );

  Widget _orderCard(Map<String, dynamic> o) {
    final id = _toInt(o['OrderID'] ?? o['orderId']);
    final name = (o['CustomerName'] ?? o['customerName'] ?? 'Khách #${o['CustomerID'] ?? o['customerId'] ?? ''}').toString();
    final status = (o['Status'] ?? o['status'] ?? '').toString().toUpperCase();
    final payMethod = (o['PaymentMethod'] ?? o['paymentMethod'] ?? '').toString();
    final total = _toNum(o['Total'] ?? o['total']);
    final dt = _parseDt(o['CreatedAt'] ?? o['createdAt']);
    final createdStr = _fmtDateTime(dt);

    final assignedId = _toInt(o['AssignedShipperID'] ?? o['assignedShipperId']);
    final assignedAt = _parseDt(o['AssignedAt'] ?? o['assignedAt']);
    final assignedStr = _fmtDateTime(assignedAt);

    final address = (o['ShippingAddress'] ?? o['shippingAddress'] ?? '').toString();
    final note = (o['Note'] ?? o['note'] ?? '').toString();

    final isExpanded = _expanded.contains(id);
    final loadingItems = _loadingItems[id] == true;
    final errItems = _errorItems[id];
    final items = _itemsCache[id] ?? const [];

    final itemCount = _toInt(o['ItemCount'] ?? o['itemCount'] ?? (items.isNotEmpty ? items.length : 0));
    final bool isCancelled = status == 'CANCELLED';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ExpansionTile(
        initiallyExpanded: isExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 12, top: 6),
        onExpansionChanged: (open) {
          setState(() { if (open) { _expanded.add(id); } else { _expanded.remove(id); } });
          if (open) _fetchItemsIfNeeded(id);
        },
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Đơn hàng #$id',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Tổng', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    Text(_vnd(total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),

            Row(
              children: [
                Expanded(
                  child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _statusBg(status), borderRadius: BorderRadius.circular(999)),
                  child: Text(_statusLabel(status), style: TextStyle(color: _statusFg(status))),
                ),
                if (payMethod.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.grey.withOpacity(.15), borderRadius: BorderRadius.circular(999)),
                    child: Text(payMethod.toUpperCase(), style: const TextStyle(color: Colors.black87)),
                  ),
                ],
              ],
            ),

            if (createdStr.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 14, color: Colors.black54),
                  const SizedBox(width: 6),
                  Text('Đặt lúc $createdStr', style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ],

            if (address.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.place, size: 14, color: Colors.black54),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(address, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black87)),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 6),
            if (!isCancelled) Row(
              children: [
                const Icon(Icons.delivery_dining, size: 14, color: Colors.black54),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    assignedId > 0
                        ? 'Shipper #$assignedId${assignedStr.isNotEmpty ? ' • $assignedStr' : ''}'
                        : 'Chưa gán shipper',
                    style: TextStyle(
                      color: assignedId > 0 ? Colors.teal.shade700 : Colors.black45,
                      fontWeight: assignedId > 0 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),

            if (!isCancelled && assignedId > 0) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.teal.withOpacity(.35)),
                      ),
                      child: const Text(
                        'GIAO HÀNG: xem chi tiết & cập nhật ở màn “Giao hàng”',
                        style: TextStyle(fontSize: 11, color: Colors.teal),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        softWrap: true,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            if (note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes, size: 14, color: Colors.black54),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(note, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 14, color: Colors.black54),
                const SizedBox(width: 6),
                Text(itemCount > 0 ? '$itemCount sản phẩm' : 'Chưa tải chi tiết'),
              ],
            ),
          ],
        ),

        children: [
          if (loadingItems)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (errItems != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(child: Text('Lỗi tải chi tiết: $errItems', style: TextStyle(color: Colors.red))),
            )
          else if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: Text('Không có sản phẩm')),
            )
          else
            Column(children: [for (final it in items) _itemRow(it)]),

          const Divider(height: 20),

          // ==== HÀNG NÚT HÀNH ĐỘNG: 3 thành phần luôn cùng 1 hàng ====
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  onPressed: isCancelled
                      ? null
                      : () async {
                          // ✅ sửa: chờ kết quả từ màn Giao hàng; nếu true thì reload
                          final changed = await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => DeliveryScreen(orderId: id)),
                          );
                          if (changed == true && mounted) {
                            _load();
                          }
                        },
                  icon: Icons.local_shipping,
                  label: 'Xem giao hàng',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  onPressed: () => _openInvoicePreview(o),
                  icon: Icons.picture_as_pdf,
                  label: 'Xuất hóa đơn',
                ),
              ),
              const SizedBox(width: 8),
              SizedBox( // chỗ cho menu 3 chấm cố định, ép nằm cùng hàng
                width: 40,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _statusMenu(id, status),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Menu đổi trạng thái đơn hàng
  Widget _statusMenu(int orderId, String current) {
    const items = [
      ['PENDING', 'Chờ xử lý'],
      ['PROCESSING', 'Đang xử lý'],
      ['SHIPPED', 'Đang giao'],
      ['COMPLETED', 'Đã giao'],
      ['CANCELLED', 'Đã hủy'],
    ];
    return PopupMenuButton<String>(
      tooltip: 'Đổi trạng thái',
      icon: const Icon(Icons.more_vert),
      onSelected: (v) => _updateStatus(orderId, v),
      itemBuilder: (_) => items.map((e) {
        final sel = current == e[0];
        return PopupMenuItem<String>(
          value: e[0],
          child: Row(
            children: [
              if (sel) const Icon(Icons.check, size: 16) else const SizedBox(width: 16),
              const SizedBox(width: 6),
              Text(e[1]),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _itemRow(Map<String, dynamic> it) {
    final name = (it['ProductName'] ?? it['name'] ?? 'Sản phẩm').toString();
    final qty = _toInt(it['Quantity'] ?? it['qty'] ?? it['quantity']);
    final price = _toNum(it['UnitPrice'] ?? it['price'] ?? 0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Text('x$qty', style: const TextStyle(color: Colors.black87)),
          const SizedBox(width: 12),
          Text(_vnd(price), style: const TextStyle(fontSize: 13, color: Colors.black54)),
        ],
      ),
    );
  }
}

class _StatusTab {
  final String? code;
  final String label;
  const _StatusTab(this.code, this.label);
}
