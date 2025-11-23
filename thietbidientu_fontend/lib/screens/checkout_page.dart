import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thietbidientu_fontend/services/api_service.dart';

// ✅ Screen OTP đúng đường dẫn (screens)
import 'package:thietbidientu_fontend/screens/payment_otp_screen.dart';
// ✅ Service gửi/verify OTP
import 'package:thietbidientu_fontend/services/payment_service.dart';

enum PaymentMethod { cod, momo, atm, visa }
enum ShippingMethod { standard, express }

String _paymentDbValue(PaymentMethod p) {
  switch (p) {
    case PaymentMethod.cod:
      return 'COD';
    case PaymentMethod.momo:
      return 'MOMO';
    case PaymentMethod.atm:
      return 'ATM';
    case PaymentMethod.visa:
      return 'CARD';
  }
}

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({Key? key}) : super(key: key);

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  late int _subtotal;
  bool _loadedArgs = false;
  int _shippingFee = 30000;
  int _discount = 0;

  PaymentMethod _payment = PaymentMethod.cod;
  ShippingMethod _shipping = ShippingMethod.standard;

  Map<String, dynamic> _navArgs = const {};
  List<Map<String, dynamic>> _checkoutItems = [];

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _wardCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _couponCtrl = TextEditingController();

  String _vnd(int n) =>
      n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.') + 'đ';

  int _toIntSafe(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    if (v is String) {
      final m = RegExp(r'-?\d+').firstMatch(v);
      if (m != null) return int.tryParse(m.group(0)!) ?? 0;
      return int.tryParse(v) ?? 0;
    }
    return 0;
  }

  int? _toIntNullable(dynamic v) {
    final n = _toIntSafe(v);
    return n == 0 ? null : n;
  }

  void _parseNavArgs() {
    _subtotal = 0;
    _checkoutItems = [];

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _navArgs = Map<String, dynamic>.from(args);
    } else {
      _navArgs = const {};
    }

    if (_navArgs['subtotal'] is int) {
      _subtotal = _navArgs['subtotal'] as int;
    }

    if ((_navArgs['mode'] == 'buy_now') && _navArgs['item'] is Map) {
      final it = Map<String, dynamic>.from(_navArgs['item'] as Map);
      final pid = it['productId'] ?? it['id'];
      final qty = (it['qty'] ?? it['quantity'] ?? 1) as int;
      final priceNum = (it['price'] ?? 0) as num;
      final price = priceNum.toDouble();

      final color = it['color'] ?? it['Color'];
      final size = it['size'] ?? it['Size'];
      final optionId = _toIntNullable(it['optionId'] ?? it['OptionID'] ?? it['optionID']);

      if (_subtotal == 0) _subtotal = (price * qty).round();

      _checkoutItems = [
        {
          'productId': pid,
          'qty': qty,
          'price': price,
          if (optionId != null) 'optionId': optionId,
          if (color != null) 'color': color,
          if (size != null) 'size': size,
        }
      ];
    }

    if (_navArgs['items'] is List) {
      final raw = List.from(_navArgs['items'] as List);
      final normalized = <Map<String, dynamic>>[];
      int sum = 0;
      for (final e in raw) {
        if (e is Map) {
          final m = Map<String, dynamic>.from(e);
          final pid = m['productId'] ?? m['ProductID'] ?? m['id'];
          final qty = (m['qty'] ?? m['quantity'] ?? m['Qty'] ?? 1) as int;
          final price = ((m['price'] ?? 0) as num).toDouble();

          final color = m['color'] ?? m['Color'];
          final size = m['size'] ?? m['Size'];
          final optionId = _toIntNullable(m['optionId'] ?? m['OptionID'] ?? m['optionID']);

          if (pid != null && qty > 0) {
            normalized.add({
              'productId': pid,
              'qty': qty,
              'price': price,
              if (optionId != null) 'optionId': optionId,
              if (color != null) 'color': color,
              if (size != null) 'size': size,
            });
            sum += (price * qty).round();
          }
        }
      }
      if (normalized.isNotEmpty) {
        _checkoutItems = normalized;
        if (_subtotal == 0) _subtotal = sum;
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedArgs) {
      _parseNavArgs();
      _loadedArgs = true;
    }
  }

  int get _total => (_subtotal - _discount) + _shippingFee;

  void _applyCoupon() {
    final code = _couponCtrl.text.trim().toUpperCase();
    if (code == 'GIAM10') {
      setState(() => _discount = (_subtotal * 0.1).floor());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Áp dụng GIAM10 thành công (-10%)')),
      );
    } else if (code.isEmpty) {
      setState(() => _discount = 0);
    } else {
      setState(() => _discount = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mã không hợp lệ')),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _ensureVariantIds(List<Map<String, dynamic>> items) async {
    final api = ApiService();
    final out = <Map<String, dynamic>>[];

    for (final it in items) {
      final m = Map<String, dynamic>.from(it);
      final pid = m['productId'] ?? m['ProductID'] ?? m['id'];
      if (pid == null) {
        out.add(m);
        continue;
      }

      int? optionId = (m['optionId'] is int) ? m['optionId'] as int : null;
      optionId ??= int.tryParse('${m['optionId'] ?? ''}');

      if (optionId == null) {
        final color = (m['color'] ?? m['Color'])?.toString().trim();
        final size = (m['size'] ?? m['Size'])?.toString().trim();

        if ((color != null && color.isNotEmpty) || (size != null && size.isNotEmpty)) {
          try {
            final opts =
                await api.getProductOptions(pid is int ? pid : int.tryParse('$pid') ?? 0);

            for (final o in (opts as List)) {
              final d = o as dynamic;
              final oc =
                  (d.color ?? d.Color ?? d['color'] ?? d['Color'] ?? '').toString().trim();
              final os =
                  (d.size ?? d.Size ?? d['size'] ?? d['Size'] ?? '').toString().trim();
              final oidRaw = d.id ??
                  d.OptionID ??
                  d.optionId ??
                  d['id'] ??
                  d['OptionID'] ??
                  d['optionId'];

              final colorOk = (color == null || color.isEmpty) ? true : (oc == color);
              final sizeOk = (size == null || size.isNotEmpty) ? true : (os == size);

              if (colorOk && sizeOk && oidRaw != null) {
                optionId = int.tryParse('$oidRaw') ?? (oidRaw is int ? oidRaw : null);
                if (optionId != null) break;
              }
            }
          } catch (_) {}
        }
      }

      final qty = (m['qty'] ?? m['quantity'] ?? 1) as int;
      final price = ((m['price'] ?? 0) as num).toDouble();

      final normalized = <String, dynamic>{
        'productId': pid,
        'qty': qty,
        'quantity': qty,
        'price': price,
        if (m['color'] != null) 'color': m['color'],
        if (m['Color'] != null) 'color': m['Color'],
        if (m['size'] != null) 'size': m['size'],
        if (m['Size'] != null) 'size': m['Size'],
        if (optionId != null) 'optionId': optionId,
        if (optionId != null) 'OptionID': optionId,
      };

      out.add(normalized);
    }
    return out;
  }

  Future<String?> _validateVariants(List<Map<String, dynamic>> items) async {
    final api = ApiService();
    for (final it in items) {
      final hasOptId = it['optionId'] != null || it['OptionID'] != null;
      final hasColor = (it['color'] ?? '').toString().trim().isNotEmpty;
      final hasSize = (it['size'] ?? '').toString().trim().isNotEmpty;
      if (hasOptId || hasColor || hasSize) continue;

      final pid =
          int.tryParse('${it['productId'] ?? it['ProductID'] ?? it['id'] ?? 0}') ?? 0;
      if (pid <= 0) continue;

      try {
        final opts = await api.getProductOptions(pid);
        if (opts is List && opts.isNotEmpty) return '#$pid';
      } catch (_) {}
    }
    return null;
  }

  bool _isValidEmail(String e) {
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return re.hasMatch(e.trim());
  }

  Future<String?> _confirmOrAskEmail() async {
    final sp = await SharedPreferences.getInstance();
    final saved = (sp.getString('email') ?? '').trim();

    String? chosen = saved.isNotEmpty ? saved : null;
    String other = '';
    bool useSaved = saved.isNotEmpty;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Chọn email để nhận OTP'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (saved.isNotEmpty)
                    RadioListTile<bool>(
                      value: true,
                      groupValue: useSaved,
                      onChanged: (v) {
                        setState(() {
                          useSaved = true;
                          chosen = saved;
                        });
                      },
                      title: const Text('Dùng email đã đăng nhập'),
                      subtitle: Text(
                        saved,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  RadioListTile<bool>(
                    value: false,
                    groupValue: useSaved,
                    onChanged: (v) {
                      setState(() {
                        useSaved = false;
                        chosen = null;
                      });
                    },
                    title: const Text('Dùng email khác'),
                  ),
                  if (!useSaved)
                    TextField(
                      autofocus: true,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'you@example.com',
                        filled: true,
                      ),
                      onChanged: (v) {
                        other = v;
                      },
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    String? finalEmail = chosen;
                    if (!useSaved) {
                      if (!_isValidEmail(other)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Email không hợp lệ')),
                        );
                        return;
                      }
                      finalEmail = other.trim();
                    }
                    if (finalEmail == null || finalEmail.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui lòng chọn hoặc nhập email')),
                      );
                      return;
                    }
                    await sp.setString('email', finalEmail);
                    if (context.mounted) Navigator.pop(context, finalEmail);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF353839),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Xác nhận'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;

    List<Map<String, dynamic>> items = _checkoutItems;
    if (items.isEmpty) {
      _parseNavArgs();
      items = _checkoutItems;
    }
    if (items.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Giỏ hàng trống hoặc thiếu danh sách items')),
      );
      return;
    }

    final note = _noteCtrl.text.trim();
    if (_total <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tổng thanh toán không hợp lệ')),
      );
      return;
    }

    items = await _ensureVariantIds(items);
    final missing = await _validateVariants(items);
    if (missing != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sản phẩm $missing yêu cầu chọn Màu/Size. Vui lòng quay lại giỏ hàng để chọn.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Xác nhận đặt hàng'),
            content: Text('Tổng thanh toán: ${_vnd(_total)}\nBạn có chắc chắn đặt hàng?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF353839),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Tiếp tục'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    final sp = await SharedPreferences.getInstance();
    final token = sp.getString('token') ?? sp.getString('accessToken') ?? sp.getString('jwt') ?? '';
    if (token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn chưa đăng nhập')),
      );
      return;
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      final resp = await ApiService().checkoutOrder(
        items: items,
        paymentMethod: _paymentDbValue(_payment),
        note: note.isEmpty ? null : note,
        fullName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        line1: _streetCtrl.text.trim(),
        ward: _wardCtrl.text.trim(),
        district: _districtCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        province: _cityCtrl.text.trim(),
        bearerToken: token, // Giữ nguyên nếu ApiService nhận tham số này
      );

      // ---- Parse orderId linh hoạt như cũ
      int? orderId;
      orderId = _toIntSafe(resp);
      if (orderId == 0 && resp is Map) {
        orderId = _toIntSafe(resp['orderId']);
        if (orderId == 0 && resp['data'] is Map) {
          final d = (resp['data'] as Map);
          orderId = _toIntSafe(d['orderId'] ?? d['OrderID']);
        }
        if (orderId == 0 && resp['order'] is Map) {
          orderId = _toIntSafe((resp['order'] as Map)['OrderID']);
        }
        if (orderId == 0) {
          orderId = _toIntSafe(resp['id']);
        }
      }

      // 🔎 MỚI: đọc cờ requiresOtp + method/amount/guidance từ BE (có fallback an toàn)
      bool requiresOtp = false;
      String method = _paymentDbValue(_payment); // fallback = theo user chọn
      int amount = _total; // fallback = tổng FE tính
      Map<String, dynamic> guidance = const {}; // fallback rỗng

      if (resp is Map) {
        requiresOtp = resp['requiresOtp'] == true;
        final m = resp['method']?.toString();
        if (m != null && m.isNotEmpty) method = m;
        final a = resp['amount'];
        if (a is num) amount = a.toInt();
        if (resp['guidance'] is Map) {
          guidance = Map<String, dynamic>.from(resp['guidance'] as Map);
        }
      }

      if (!mounted) return;
      Navigator.pop(context); // close loading

      // ✅ Luồng MỚI: luôn đi qua OTP nếu BE bật requiresOtp (áp dụng cho mọi phương thức)
      if (requiresOtp && (orderId ?? 0) > 0) {
        final email = await _confirmOrAskEmail();
        if (email == null || email.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bạn chưa chọn email để nhận OTP')),
          );
          return;
        }

        // Gửi OTP
        try {
          await PaymentService().checkout(orderId: orderId!, email: email);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gửi OTP lỗi: $e — thử "Gửi lại mã" ở màn tiếp theo')),
          );
        }

        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          PaymentOtpScreen.route,
          arguments: PaymentOtpArgs(
            orderId: orderId!,
            email: email,
            amount: amount,
            method: method, // 'MOMO' | 'ATM' | 'CARD' | 'COD'
            guidance: guidance, // dữ liệu hướng dẫn hiển thị theo phương thức
          ),
        );
        return;
      }

      // 🧯 Fallback cũ: nếu BE không bật requiresOtp thì giữ hành vi hiện tại
      if (_payment == PaymentMethod.cod || !requiresOtp) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đặt hàng thành công!')),
        );
        Navigator.pushReplacementNamed(context, '/thank-you', arguments: orderId);
        return;
      }

      // Trường hợp còn lại (phòng xa)
      if ((orderId ?? 0) > 0) {
        final email = await _confirmOrAskEmail();
        if (email == null || email.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bạn chưa chọn email để nhận OTP')),
          );
          return;
        }
        try {
          await PaymentService().checkout(orderId: orderId!, email: email);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gửi OTP lỗi: $e — thử "Gửi lại mã" ở màn tiếp theo')),
          );
        }
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          PaymentOtpScreen.route,
          // 🔁 Truyền đủ tham số mới để khớp constructor mới
          arguments: PaymentOtpArgs(
            orderId: orderId!,
            email: email,
            amount: amount,
            method: method,
            guidance: guidance,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể tạo đơn hàng')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi đặt hàng: $e')),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _streetCtrl.dispose();
    _wardCtrl.dispose();
    _districtCtrl.dispose();
    _cityCtrl.dispose();
    _noteCtrl.dispose();
    _couponCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đặt hàng'),
        backgroundColor: const Color(0xFF353839),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionTitle('Địa chỉ giao hàng'),
              _card(
                Column(
                  children: [
                    _input(_nameCtrl, 'Họ và tên', Icons.person, validator: _required),
                    _input(_phoneCtrl, 'Số điện thoại', Icons.phone,
                        keyboard: TextInputType.phone, validator: _required),
                    _input(_streetCtrl, 'Số nhà, đường', Icons.home, validator: _required),
                    _row2(
                      _input(_wardCtrl, 'Phường/Xã', Icons.location_on,
                          dense: true, validator: _required),
                      _input(_districtCtrl, 'Quận/Huyện', Icons.map,
                          dense: true, validator: _required),
                    ),
                    _input(_cityCtrl, 'Tỉnh/Thành phố', Icons.apartment,
                        validator: _required),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _sectionTitle('Đơn hàng'),
              _card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _line('Tạm tính', _vnd(_subtotal)),
                    const SizedBox(height: 8),
                    _couponRow(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _sectionTitle('Phương thức vận chuyển'),
              _card(
                Column(
                  children: [
                    RadioListTile<ShippingMethod>(
                      value: ShippingMethod.standard,
                      groupValue: _shipping,
                      onChanged: (v) => setState(() {
                        _shipping = v!;
                        _shippingFee = 30000;
                      }),
                      title: const Text('Tiêu chuẩn (2–4 ngày)'),
                      subtitle: Text(_vnd(30000)),
                    ),
                    const Divider(height: 1),
                    RadioListTile<ShippingMethod>(
                      value: ShippingMethod.express,
                      groupValue: _shipping,
                      onChanged: (v) => setState(() {
                        _shipping = v!;
                        _shippingFee = 50000;
                      }),
                      title: const Text('Nhanh (1–2 ngày)'),
                      subtitle: Text(_vnd(50000)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _sectionTitle('Phương thức thanh toán'),
              _card(
                Column(
                  children: [
                    RadioListTile<PaymentMethod>(
                      value: PaymentMethod.cod,
                      groupValue: _payment,
                      onChanged: (v) => setState(() => _payment = v!),
                      title: const Text('Thanh toán khi nhận hàng (COD)'),
                    ),
                    const Divider(height: 1),
                    RadioListTile<PaymentMethod>(
                      value: PaymentMethod.momo,
                      groupValue: _payment,
                      onChanged: (v) => setState(() => _payment = v!),
                      title: const Text('Ví MoMo'),
                    ),
                    const Divider(height: 1),
                    RadioListTile<PaymentMethod>(
                      value: PaymentMethod.atm,
                      groupValue: _payment,
                      onChanged: (v) => setState(() => _payment = v!),
                      title: const Text('Thẻ nội địa/ATM'),
                    ),
                    const Divider(height: 1),
                    RadioListTile<PaymentMethod>(
                      value: PaymentMethod.visa,
                      groupValue: _payment,
                      onChanged: (v) => setState(() => _payment = v!),
                      title: const Text('Thẻ Visa/MasterCard'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _sectionTitle('Ghi chú cho đơn hàng'),
              _card(
                TextField(
                  controller: _noteCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Ví dụ: Giao giờ hành chính…',
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _sectionTitle('Tổng cộng'),
              _card(
                Column(
                  children: [
                    _line('Tạm tính', _vnd(_subtotal)),
                    _line('Phí vận chuyển', _vnd(_shippingFee)),
                    _line('Giảm giá', _discount == 0 ? '0đ' : '-${_vnd(_discount)}'),
                    const Divider(height: 24),
                    _line('Tổng thanh toán', _vnd(_total), isBold: true),
                  ],
                ),
              ),
              const SizedBox(height: 90),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, -3))],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tổng', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    Text(_vnd(_total),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1C1C1E))),
                  ],
                ),
              ),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _placeOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF353839),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Đặt hàng', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );

  Widget _card(Widget child) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: child,
      );

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Thông tin bắt buộc' : null;

  Widget _input(TextEditingController c, String hint, IconData icon,
          {TextInputType keyboard = TextInputType.text, bool dense = false, String? Function(String?)? validator}) =>
      Padding(
        padding: EdgeInsets.only(bottom: dense ? 8 : 12),
        child: TextFormField(
          controller: c,
          keyboardType: keyboard,
          validator: validator,
          decoration: InputDecoration(
            prefixIcon: Icon(icon),
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF3F4F6),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          ),
        ),
      );

  Widget _row2(Widget a, Widget b) => Row(children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)]);

  Widget _line(String l, String r, {bool isBold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(l,
              style: TextStyle(
                  fontSize: 14, color: Colors.grey[800], fontWeight: isBold ? FontWeight.w700 : FontWeight.w500)),
          Text(r, style: TextStyle(fontSize: isBold ? 18 : 14, fontWeight: isBold ? FontWeight.w800 : FontWeight.w600)),
        ]),
      );

  Widget _couponRow() => Row(children: [
        Expanded(
          child: TextField(
            controller: _couponCtrl,
            decoration: InputDecoration(
              hintText: 'Nhập mã (ví dụ: GIAM10)',
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _applyCoupon,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF353839),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Áp dụng'),
        ),
      ]);
}
