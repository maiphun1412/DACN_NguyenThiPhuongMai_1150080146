// lib/screens/otp_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';

const kBrand = Color(0xFF353839);

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _otpCtrl = TextEditingController();

  bool _loading = false;
  bool _resending = false;

  // Animations (đồng bộ các màn khác)
  late final AnimationController _enterCtrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slideUp;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _enterCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _fade = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic);
    _slideUp = Tween<Offset>(begin: const Offset(0, .12), end: Offset.zero).animate(
      CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic),
    );
    _enterCtrl.forward();

    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
          ..repeat(reverse: true);
    _pulse = Tween<double>(begin: .96, end: 1.04)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _pulseCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final identifier = (ModalRoute.of(context)?.settings.arguments as String?) ?? '';
    final ok = await AuthService.verifyOtp(identifier, _otpCtrl.text.trim());

    setState(() => _loading = false);
    if (!mounted) return;

    if (ok) {
      _showSnack('Xác minh OTP thành công!');
      Navigator.pushNamed(context, '/reset', arguments: identifier);
    } else {
      _showSnack('OTP không hợp lệ.');
    }
  }

  Future<void> _resend() async {
    final identifier = (ModalRoute.of(context)?.settings.arguments as String?)?.trim() ?? '';
    if (identifier.isEmpty) {
      _showSnack('Thiếu email/số điện thoại. Quay lại màn trước để nhập.');
      return;
    }
    setState(() => _resending = true);
    final ok = await AuthService.sendOtp(identifier);
    setState(() => _resending = false);
    _showSnack(ok ? 'Đã gửi lại OTP.' : 'Gửi lại OTP thất bại.');
  }

  // InputDecoration thống nhất (viền rõ, focus dày)
  InputDecoration _deco({
    required String label,
    IconData? icon,
    Widget? suffix,
  }) {
    const borderGrey = Color(0xFF9AA4B2);
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: kBrand) : null,
      suffixIcon: suffix,
      hintStyle: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
      labelStyle: const TextStyle(color: Color(0xFF2C2F33), fontWeight: FontWeight.w600),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderGrey, width: 1.8),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderGrey, width: 1.8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kBrand, width: 2.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2.2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final identifier = (ModalRoute.of(context)?.settings.arguments as String?)?.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: kBrand,
        title: const Text('Nhập mã OTP', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Nền sáng + vòng tròn mờ nhẹ
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(0, -1),
                end: Alignment(0, .9),
                colors: [Color(0xFFF8FAFD), Color(0xFFF1F4F9)],
              ),
            ),
          ),
          Positioned(
            top: -70,
            right: -30,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kBrand.withOpacity(.06),
              ),
            ),
          ),
          Positioned(
            top: 90,
            left: -50,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kBrand.withOpacity(.05),
              ),
            ),
          ),

          FadeTransition(
            opacity: _fade,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  // Icon tròn (pulse) để đồng bộ nhận diện
                  ScaleTransition(scale: _pulse, child: const _TopLogo(size: 70)),
                  const SizedBox(height: 10),
                  const Text(
                    'MaiTech Shop',
                    style: TextStyle(
                      color: kBrand,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (identifier != null && identifier.isNotEmpty) ...[
                    Text(
                      'Mã OTP đã gửi tới: $identifier',
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Card form
                  SlideTransition(
                    position: _slideUp,
                    child: Material(
                      elevation: 16,
                      color: Colors.white,
                      shadowColor: Colors.black12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: Color(0xFFC7CFDA), width: 1.6),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Nhập mã OTP gồm 6 chữ số đã gửi tới bạn.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 14),

                              TextFormField(
                                controller: _otpCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                maxLength: 6,
                                decoration: _deco(
                                  label: 'Mã OTP (6 số)',
                                  icon: Icons.pin_outlined,
                                ).copyWith(counterText: ''),
                                validator: (v) =>
                                    (v == null || v.trim().length != 6) ? 'OTP 6 chữ số' : null,
                                onFieldSubmitted: (_) => _verify(),
                              ),
                              const SizedBox(height: 10),

                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _resending ? null : _resend,
                                  child: _resending
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Text('Gửi lại OTP'),
                                ),
                              ),
                              const SizedBox(height: 8),

                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _verify,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kBrand,
                                    foregroundColor: Colors.white,
                                    elevation: 2,
                                    shadowColor: kBrand.withOpacity(.25),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 220),
                                    child: _loading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Xác minh',
                                            key: ValueKey('verify'),
                                            style: TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Icon tròn dùng chung (tone thương hiệu)
class _TopLogo extends StatelessWidget {
  final double size;
  const _TopLogo({required this.size});
  

  @override
  Widget build(BuildContext context) {
    final double iconSize = (size - 10) * 0.48;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.6),
        boxShadow: const [
          BoxShadow(blurRadius: 16, color: Colors.black12, offset: Offset(0, 8))
        ],
      ),
      alignment: Alignment.center,
      child: Icon(Icons.verified_outlined, color: kBrand, size: iconSize),
    );
  }
}
