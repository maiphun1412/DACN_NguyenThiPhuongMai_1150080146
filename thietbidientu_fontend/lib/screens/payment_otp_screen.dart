import 'package:flutter/material.dart';
import 'package:thietbidientu_fontend/services/payment_service.dart';
import 'package:thietbidientu_fontend/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentOtpArgs {
  final int orderId;
  final String email;
  // ✅ thêm 3 tham số (tùy chọn để không phá luồng cũ)
  final int? amount;
  final String? method; // 'MOMO' | 'ATM' | 'CARD' | 'COD'
  final Map<String, dynamic>? guidance;

  const PaymentOtpArgs({
    required this.orderId,
    required this.email,
    this.amount,
    this.method,
    this.guidance,
  });
}

class PaymentOtpScreen extends StatefulWidget {
  static const route = '/payment-otp';
  const PaymentOtpScreen({super.key});

  @override
  State<PaymentOtpScreen> createState() => _PaymentOtpScreenState();
}

class _PaymentOtpScreenState extends State<PaymentOtpScreen> {
  late final int orderId;
  late final String email;
  bool _inited = false;

  final _code = TextEditingController();
  final _cardNo = TextEditingController();
  final _exp = TextEditingController(); // MM/YY
  final _cvv = TextEditingController();

  bool _busy = false;

  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _intent;

  String _token = '';

  // ✅ giữ các giá trị FE truyền qua để fallback
  int? _amountFromArgs;
  String? _methodFromArgs;
  Map<String, dynamic>? _guidanceFromArgs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_inited) return;
    _inited = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is PaymentOtpArgs) {
      orderId = args.orderId;
      email = args.email;
      _amountFromArgs = args.amount;
      _methodFromArgs = args.method;
      _guidanceFromArgs = args.guidance;
    } else if (args is Map) {
      orderId = int.tryParse('${args['orderId'] ?? args['id']}') ?? 0;
      email = (args['email'] ?? '').toString();
      _amountFromArgs = (args['amount'] is num) ? (args['amount'] as num).toInt() : null;
      _methodFromArgs = args['method']?.toString();
      _guidanceFromArgs = (args['guidance'] is Map)
          ? Map<String, dynamic>.from(args['guidance'] as Map)
          : null;
    } else {
      orderId = 0;
      email = '';
    }
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final sp = await SharedPreferences.getInstance();
      _token = sp.getString('token') ??
          sp.getString('accessToken') ??
          sp.getString('jwt') ??
          '';

      final api = ApiService();
      final s = await api.getOrderSummary(orderId, bearerToken: _token);
      final pi = await api.getPaymentIntent(orderId, bearerToken: _token);

      if (!mounted) return;
      setState(() {
        _summary = s;
        _intent = pi;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tải được thông tin thanh toán: $e')),
      );
    }
  }

  String _vnd(num n) {
    final s = n.round().toString();
    return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.') + 'đ';
  }

  @override
  void dispose() {
    _code.dispose();
    _cardNo.dispose();
    _exp.dispose();
    _cvv.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final c = _code.text.trim();
    if (c.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đủ 6 số OTP')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final method = (_intent?['method'] ??
              _methodFromArgs ??
              '')
          .toString()
          .toUpperCase();

      await PaymentService().verifyOtp(
        orderId: orderId,
        otp: c,
        cardNo: method == 'CARD' ? _cardNo.text.trim() : null,
        exp: method == 'CARD' ? _exp.text.trim() : null,
        cvv: method == 'CARD' ? _cvv.text.trim() : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanh toán xác nhận thành công')),
      );
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/thank-you',
        (r) => false,
        arguments: orderId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xác nhận thất bại: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDeeplink() async {
    final link = (_intent?['deeplink'] ?? '').toString();
    if (link.isEmpty) return;
    final uri = Uri.parse(link);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không mở được ứng dụng thanh toán')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !_busy && _code.text.trim().length == 6;

    // ✅ ưu tiên intent từ BE, fallback FE
    final method = ((_intent?['method'] ?? _methodFromArgs) ?? '').toString();
    final amount =
        (_intent?['amount'] as num?) ?? (_summary?['total'] as num?) ?? (_amountFromArgs ?? 0);
    final qrData = (_intent?['qrData'] ?? '').toString();
    final transId = (_intent?['transactionId'] ??
            _intent?['momoTransId'] ??
            _intent?['bankRef'] ??
            _intent?['refId'] ??
            '')
        .toString();

    // ✅ guidance hợp nhất (BE ưu tiên)
    final Map<String, dynamic> guidance = {
      ...(_guidanceFromArgs ?? const {}),
      if (_intent?['guidance'] is Map) ...Map<String, dynamic>.from(_intent!['guidance']),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác nhận thanh toán'),
        backgroundColor: const Color(0xFF353839),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/order-tracking', arguments: orderId),
            icon: const Icon(Icons.local_shipping_outlined),
            tooltip: 'Theo dõi đơn',
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Đơn hàng #$orderId',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Mã OTP đã gửi tới: $email',
                  style: const TextStyle(color: Colors.black54)),
              if (transId.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Mã giao dịch: $transId',
                    style: const TextStyle(color: Colors.black54)),
              ],
              const SizedBox(height: 16),

              if (_summary != null) _OrderSummaryCard(summary: _summary!, vnd: _vnd),
              const SizedBox(height: 16),

              if (method.isNotEmpty && method.toUpperCase() != 'CASH') ...[
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Thanh toán qua ${method.toUpperCase()}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text('Số tiền: ${_vnd(amount)}'),
                        const SizedBox(height: 12),

                        if (qrData.isNotEmpty)
                          Center(child: QrImageView(data: qrData, size: 180)),

                        if ((_intent?['deeplink'] ?? '').toString().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _openDeeplink,
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Mở ứng dụng để thanh toán'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF353839),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],

                        if (guidance.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          // ✅ chống overflow: bọc trong ConstrainedBox + SelectableText mềm
                          ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 0),
                            child: SelectableText(
                              (guidance['note'] ??
                                      guidance['message'] ??
                                      guidance['instruction'] ??
                                      guidance.toString())
                                  .toString(),
                              textAlign: TextAlign.left,
                              style: const TextStyle(color: Colors.black54, height: 1.35),
                            ),
                          ),
                        ],

                        const SizedBox(height: 8),
                        const Text(
                          'Sau khi thanh toán, nhập mã OTP để xác nhận.',
                          style: TextStyle(color: Colors.black54),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (method.toUpperCase() == 'CARD') ...[
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Thanh toán thẻ',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text('Số tiền: ${_vnd(amount)}'),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _cardNo,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Số thẻ',
                            filled: true,
                            fillColor: Color(0xFFF3F4F6),
                            border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.all(Radius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: TextField(
                              controller: _exp,
                              decoration: const InputDecoration(
                                labelText: 'MM/YY',
                                filled: true,
                                fillColor: Color(0xFFF3F4F6),
                                border: OutlineInputBorder(
                                  borderSide: BorderSide.none,
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _cvv,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'CVV',
                                filled: true,
                                fillColor: Color(0xFFF3F4F6),
                                border: OutlineInputBorder(
                                  borderSide: BorderSide.none,
                                  borderRadius: BorderRadius.all(Radius.circular(10)),
                                ),
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        const Text(
                          'Sau khi nhập thông tin thẻ và hoàn tất, nhập OTP để xác nhận.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Nhập mã OTP',
                  counterText: '',
                  filled: true,
                  fillColor: Color(0xFFF3F4F6),
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                ),
                onChanged: (_) => setState(() {
                  if (_code.text.trim().length == 6 && !_busy) _verify();
                }),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: canSubmit ? _verify : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF353839),
                    foregroundColor: Colors.white,
                    shape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _busy
                      ? const CircularProgressIndicator.adaptive()
                      : const Text('Xác nhận thanh toán'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          await PaymentService().resendOtp(orderId: orderId);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Đã gửi lại OTP đến $email')),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gửi lại OTP lỗi: $e')),
                          );
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                child: const Text('Gửi lại mã'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  final Map<String, dynamic> summary;
  final String Function(num) vnd;
  const _OrderSummaryCard({required this.summary, required this.vnd});

  @override
  Widget build(BuildContext context) {
    final items = (summary['items'] as List? ?? []);
    final address = (summary['address'] ?? {}) as Map;
    final total = (summary['total'] ?? 0) as num;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Tóm tắt đơn hàng',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (address.isNotEmpty)
              Text(
                '${address['fullName'] ?? ''}\n'
                '${address['phone'] ?? ''}\n'
                '${address['line1'] ?? ''}, ${address['ward'] ?? ''}, '
                '${address['district'] ?? ''}, ${address['city'] ?? ''}',
              ),
            const Divider(height: 24),
            ...items.map((e) {
              final name = '${e['name'] ?? e['ProductName'] ?? 'Sản phẩm'}';
              final qty = e['qty'] ?? e['quantity'] ?? 1;
              final price = (e['price'] ?? 0) as num;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('$name x$qty')),
                    Text(vnd(price * (qty is num ? qty : 1))),
                  ],
                ),
              );
            }),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tổng cộng',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                Text(vnd(total),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
