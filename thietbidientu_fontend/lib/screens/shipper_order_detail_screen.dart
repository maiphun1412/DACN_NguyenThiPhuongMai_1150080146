import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:thietbidientu_fontend/services/admin/shipper_service.dart';
import '../../models/shipper_order.dart';

class ShipperOrderDetailScreen extends StatefulWidget {
  final ShipperOrder order;

  const ShipperOrderDetailScreen({Key? key, required this.order})
      : super(key: key);

  @override
  State<ShipperOrderDetailScreen> createState() =>
      _ShipperOrderDetailScreenState();
}

class _ShipperOrderDetailScreenState extends State<ShipperOrderDetailScreen> {
  final _shipperService = ShipperService();
  bool _saving = false;

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

  Future<void> _changeStatus(String status, {String? note}) async {
    // Tạm dùng orderId làm shipmentId như anh em đang giả định
    final shipmentId = widget.order.orderId;

    setState(() => _saving = true);
    try {
      await _shipperService.updateShipmentStatus(
        shipmentId,
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

  /// Hỏi shipper nhập ghi chú rồi mới đổi trạng thái
  Future<void> _askNoteAndChangeStatus(
    String status, {
    required String title,
    String? description,
    String? hint,
  }) async {
    final noteCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (description != null && description.isNotEmpty) ...[
                  Text(
                    description,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Ghi chú (hiện cho admin & khách hàng)',
                    hintText: hint ??
                        'Ví dụ: Khách hẹn giao lại 19h ngày mai, hoặc lý do không nhận…',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Huỷ'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Xác nhận'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    final note = noteCtrl.text.trim();
    await _changeStatus(status, note: note.isEmpty ? null : note);
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;

    debugPrint('== SHIPPER ORDER DETAIL ==');
    debugPrint('orderId=${o.orderId}');
    debugPrint('paymentMethod=${o.paymentMethod}');
    debugPrint('paymentStatus=${o.paymentStatus}');
    debugPrint('paidAmount=${o.paidAmount}');
    debugPrint('totalAmount=${o.totalAmount}');
    debugPrint('amountToCollect=${o.amountToCollect}');

    // ================= THANH TOÁN: ĐÃ TRẢ / CẦN THU =================
    final String paymentMethod = o.paymentMethod.trim();
    final upperPm = paymentMethod.toUpperCase();

    // Các phương thức coi như trả trước (MOMO, thẻ, chuyển khoản...)
    final bool isPrepaidMethod = upperPm == 'MOMO' ||
        upperPm == 'VNPAY' ||
        upperPm == 'BANK' ||
        upperPm == 'CREDIT_CARD' ||
        upperPm == 'CARD' ||
        upperPm == 'ATM' ||
        upperPm == 'TRANSFER';

    // Nếu backend có trả AmountToCollect thì ưu tiên dùng,
    // nếu không thì tự tính: trả trước => 0, còn lại => tổng tiền
    num codAmount = o.amountToCollect > 0
        ? o.amountToCollect
        : (isPrepaidMethod ? 0 : o.totalAmount);
    if (codAmount < 0) codAmount = 0;

    String paymentText;
    if (isPrepaidMethod) {
      // Đã thanh toán trước
      paymentText = paymentMethod.isEmpty
          ? 'Đã thanh toán'
          : 'Đã thanh toán ($paymentMethod)';
    } else {
      // Thanh toán khi nhận hàng (COD / phương thức khác)
      if (upperPm.isEmpty ||
          upperPm == 'COD' ||
          upperPm == 'CASH_ON_DELIVERY') {
        paymentText = 'Thanh toán khi nhận hàng (COD)';
      } else {
        paymentText = 'Thanh toán khi nhận hàng ($paymentMethod)';
      }
    }
    // ================================================================

    return Scaffold(
      appBar: AppBar(
        title: Text('Đơn #${o.orderId}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // -------- TÓM TẮT ĐƠN --------
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
                          'Mã đơn: #${o.orderId}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          o.status.isEmpty ? 'Chưa rõ' : o.status,
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
                    'Tổng tiền: ${_vnd(o.totalAmount)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    paymentText,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Shipper cần thu: ${_vnd(codAmount)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // -------- KHÁCH HÀNG --------
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Khách hàng',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          o.customerName.isEmpty ? '—' : o.customerName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (o.customerPhone.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(o.customerPhone)),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => _callCustomer(o.customerPhone),
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
                  if (o.customerEmail.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.email_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(o.customerEmail)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // -------- ĐỊA CHỈ GIAO --------
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Địa chỉ giao',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.place_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          o.shippingAddress.isEmpty
                              ? '—'
                              : o.shippingAddress,
                          style: const TextStyle(height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // -------- NÚT HÀNH ĐỘNG --------
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
                    onPressed: () => _askNoteAndChangeStatus(
                      'contact_failed',
                      title: 'Liên hệ khách không thành công',
                      description:
                          'Vui lòng ghi lý do để admin và khách hàng cùng xem.',
                      hint:
                          'VD: Gọi 3 lần trong 10 phút nhưng không nghe máy, sẽ thử lại ngày mai.',
                    ),
                    child: const Text('Liên hệ khách không thành công'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _askNoteAndChangeStatus(
                      'reschedule',
                      title: 'Khách hẹn giao lại',
                      description:
                          'Ghi rõ thời gian khách muốn giao lại để bộ phận CSKH nắm thông tin.',
                      hint:
                          'VD: Khách hẹn giao lại 19h ngày 15/11, hoặc “cuối tuần rảnh, xin gọi lại trước khi giao”.',
                    ),
                    child: const Text('Khách hẹn giao lại'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () => _askNoteAndChangeStatus(
                      'customer_refused',
                      title: 'Khách không nhận đơn',
                      description:
                          'Ghi lại lý do khách từ chối để xử lý hoàn tiền / hoàn kho.',
                      hint:
                          'VD: Khách bảo đặt nhầm model, không còn nhu cầu, sản phẩm giao chậm, v.v.',
                    ),
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
