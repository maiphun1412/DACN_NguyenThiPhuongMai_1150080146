// lib/screens/shipper_home_screen.dart
import 'package:flutter/material.dart';
import '../services/admin/shipper_service.dart';
import '../services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ShipperHomeScreen extends StatefulWidget {
  const ShipperHomeScreen({Key? key}) : super(key: key);

  @override
  State<ShipperHomeScreen> createState() => _ShipperHomeScreenState();
}

class _ShipperHomeScreenState extends State<ShipperHomeScreen> {
  final _shipperService = ShipperService();
  bool _loading = false;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

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

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _shipperService.myShipments();
      setState(() {
        _orders = list
            .map<Map<String, dynamic>>(
              (e) => Map<String, dynamic>.from(e as Map),
            )
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openDetail(Map<String, dynamic> order) async {
    final reloaded = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ShipperOrderDetailScreen(order: order),
      ),
    );

    if (reloaded == true) {
      _load();
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đơn cần giao'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _orders.isEmpty
                ? const Center(
                    child: Text('Hiện chưa có đơn nào được gán cho bạn.'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final o = _orders[i];

                      final orderId = _asInt(
                        o['orderId'] ?? o['orderID'] ?? o['OrderID'],
                      );

                      final status =
                          (o['status'] ?? o['Status'] ?? '').toString();

                      final customerName = (o['customerName'] ??
                              o['CustomerName'] ??
                              o['FullName'] ??
                              '')
                          .toString();

                      final phone = (o['customerPhone'] ??
                              o['CustomerPhone'] ??
                              o['Phone'] ??
                              '')
                          .toString();

                      // ✅ Dùng luôn ShippingAddress backend trả về, không tự ráp lại nữa
                      final address = (o['shippingAddress'] ??
                              o['ShippingAddress'] ??
                              '')
                          .toString();

                      final totalAmount = (o['totalAmount'] ??
                              o['TotalAmount'] ??
                              o['Total'] ??
                              0) as num;

                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _openDetail(o),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(right: 12),
                                child: Icon(
                                  Icons.local_shipping_outlined,
                                  size: 28,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '#$orderId  •  $customerName',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.blueGrey.shade50,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            status.isEmpty ? 'Mới' : status,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    if (phone.isNotEmpty)
                                      Row(
                                        children: [
                                          const Icon(Icons.phone,
                                              size: 14,
                                              color: Colors.black54),
                                          const SizedBox(width: 4),
                                          Text(
                                            phone,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (address.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.place_outlined,
                                            size: 14,
                                            color: Colors.black54,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              address,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Text(
                                      'Tổng: ${_vnd(totalAmount)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

// =================== DETAIL ===================
// (phần detail em đang dùng file riêng theo model ShipperOrder, không động vào ở đây)


class ShipperOrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const ShipperOrderDetailScreen({Key? key, required this.order})
      : super(key: key);

  @override
  State<ShipperOrderDetailScreen> createState() =>
      _ShipperOrderDetailScreenState();
}

class _ShipperOrderDetailScreenState extends State<ShipperOrderDetailScreen> {
  final _shipperService = ShipperService();
  bool _saving = false;

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? ''}') ?? 0;
  }

  int get _shipmentId {
    return _asInt(
      widget.order['shipmentID'] ??
          widget.order['ShipmentID'] ??
          widget.order['orderID'] ??
          widget.order['OrderID'],
    );
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

  Future<void> _changeStatus(String status, {String? note}) async {
    setState(() => _saving = true);
    try {
      await _shipperService.updateShipmentStatus(
        _shipmentId,
        status,
        note: note ?? '',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật trạng thái thành công')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _callCustomer(String phone) async {
    final raw = phone.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có số điện thoại khách hàng')),
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: raw);
    if (!await canLaunchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể mở ứng dụng gọi cho số $raw')),
      );
      return;
    }
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;

    // ID + trạng thái
    final orderId = _asInt(o['orderId'] ?? o['orderID'] ?? o['OrderID']);
    final status = (o['status'] ?? o['Status'] ?? '').toString();

    // Khách hàng
    final customerName =
        (o['customerName'] ?? o['CustomerName'] ?? o['FullName'] ?? '')
            .toString();
    final customerPhone =
        (o['customerPhone'] ?? o['CustomerPhone'] ?? o['Phone'] ?? '')
            .toString();
    final customerEmail =
        (o['customerEmail'] ?? o['CustomerEmail'] ?? '').toString();

    // ❗ Dùng đúng chuỗi ShippingAddress backend trả, KHÔNG ráp thêm ward/district nữa
    final shippingAddress =
        (o['shippingAddress'] ?? o['ShippingAddress'] ?? '').toString();

    // Tổng tiền
    final total =
        (o['totalAmount'] ?? o['TotalAmount'] ?? o['Total'] ?? 0) as num;

    // ==== Thanh toán ====
    final paymentMethod =
        (o['PaymentMethod'] ?? o['paymentMethod'] ?? '').toString();
    final paymentStatus =
        (o['PaymentStatus'] ?? o['paymentStatus'] ?? '').toString();
    final paidAmount = o['PaidAmount'] ?? o['paidAmount'] ?? 0;

    final amountToCollectRaw = o['AmountToCollect'] ??
        o['amountToCollect'] ??
        o['amount_to_collect'];

    num backendAmountToCollect = 0;
    if (amountToCollectRaw is num) {
      backendAmountToCollect = amountToCollectRaw;
    } else if (amountToCollectRaw is String) {
      backendAmountToCollect = num.tryParse(amountToCollectRaw) ?? 0;
    }

    final upperPm = paymentMethod.toUpperCase();
    final upperPs = paymentStatus.toUpperCase();

    final bool isPaidStatus = upperPs == 'PAID' ||
        upperPs == 'PAID_OK' ||
        upperPs == 'SUCCESS' ||
        upperPs == 'ĐÃ THANH TOÁN';

    final bool isPrepaidMethod = upperPm == 'MOMO' ||
        upperPm == 'CARD' ||
        upperPm == 'ATM' ||
        upperPm == 'VNPAY' ||
        upperPm == 'BANK' ||
        upperPm == 'TRANSFER';

    final bool treatAsPrepaid =
        isPaidStatus || (isPrepaidMethod && (paidAmount as num) > 0);

    num codAmount;
    if (backendAmountToCollect > 0) {
      codAmount = backendAmountToCollect;
    } else {
      codAmount = treatAsPrepaid ? 0 : total;
    }
    if (codAmount < 0) codAmount = 0;

    String paymentText;
    if (treatAsPrepaid) {
      paymentText = paymentMethod.isEmpty
          ? 'Đã thanh toán'
          : 'Đã thanh toán ($paymentMethod)';
    } else {
      if (upperPm.isEmpty ||
          upperPm == 'COD' ||
          upperPm == 'CASH_ON_DELIVERY') {
        paymentText = 'Thanh toán khi nhận hàng (COD)';
      } else {
        paymentText = 'Thanh toán khi nhận hàng ($paymentMethod)';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Đơn #$orderId'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // TÓM TẮT ĐƠN
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thông tin đơn hàng',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Mã đơn: #$orderId',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          status.isEmpty ? 'Chưa rõ' : status,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tổng tiền: ${_vnd(total)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$paymentText\nCần thu: ${_vnd(codAmount)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // KHÁCH HÀNG
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Khách hàng',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          customerName.isEmpty ? '—' : customerName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (customerPhone.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(customerPhone)),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => _callCustomer(customerPhone),
                          icon: const Icon(Icons.call, size: 18),
                          label: const Text('Gọi ngay'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (customerEmail.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.email_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(customerEmail)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ĐỊA CHỈ GIAO
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Địa chỉ giao',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.place_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          shippingAddress.isEmpty ? '—' : shippingAddress,
                          style: const TextStyle(height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_saving)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: () => _changeStatus('shipped'),
                    child: const Text('Đang giao'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _changeStatus('completed'),
                    child: const Text('Giao thành công'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _changeStatus('contact_failed'),
                    child: const Text('Liên hệ khách không thành công'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _changeStatus('reschedule'),
                    child: const Text('Khách hẹn giao lại'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () => _changeStatus('customer_refused'),
                    child: const Text('Khách không nhận đơn'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
