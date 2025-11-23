// lib/screens/reset_password_screen.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

const kBrand = Color(0xFF353839);

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _otp = TextEditingController();
  final _pwd = TextEditingController();
  final _pwd2 = TextEditingController();

  final _pwdFocus = FocusNode();
  final _pwd2Focus = FocusNode();

  bool _loading = false, _ob1 = true, _ob2 = true;
  bool _resending = false;

  // Animations (đồng bộ Login/Register)
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
    _otp.dispose();
    _pwd.dispose();
    _pwd2.dispose();
    _pwdFocus.dispose();
    _pwd2Focus.dispose();
    super.dispose();
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  /// Gửi lại OTP tới identifier (email/SĐT) đã truyền vào màn hình
  Future<void> _resendOtp() async {
    final identifier =
        (ModalRoute.of(context)?.settings.arguments as String?)?.trim() ?? '';
    if (identifier.isEmpty) {
      _showSnack('Thiếu email/số điện thoại. Quay lại màn trước để nhập.');
      return;
    }
    setState(() => _resending = true);
    final ok = await AuthService.sendOtp(identifier);
    setState(() => _resending = false);
    _showSnack(ok ? 'Đã gửi lại OTP. Vui lòng kiểm tra hộp thư.' : 'Gửi lại OTP thất bại.');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final identifier =
        (ModalRoute.of(context)?.settings.arguments as String?)?.trim() ?? '';

    if (identifier.isEmpty) {
      _showSnack('Thiếu email/số điện thoại (identifier). Quay lại màn trước.');
      return;
    }

    setState(() => _loading = true);
    final ok = await AuthService.resetPassword(
      identifier,
      _pwd.text.trim(),
      otp: _otp.text.trim(),
    );
    setState(() => _loading = false);
    if (!mounted) return;

    if (ok) {
      _showSnack('Đổi mật khẩu thành công. Hãy đăng nhập.');
      Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
    } else {
      _showSnack('OTP không hợp lệ hoặc lỗi kết nối. Thử lại.');
    }
  }

  // InputDecoration: viền rõ & dày (đồng bộ các màn)
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
    final identifier =
        (ModalRoute.of(context)?.settings.arguments as String?)?.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: kBrand,
        title: const Text('Đặt lại mật khẩu', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Nền gradient + vòng tròn mờ (tone sáng)
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
                  // Icon tròn + pulse
                  ScaleTransition(scale: _pulse, child: const _TopLogo(size: 70)),
                  const SizedBox(height: 10),

                  // Card form: border + elevation rõ
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
                              // Hiển thị email/SĐT để người dùng biết mã gửi tới đâu
                              if (identifier != null && identifier.isNotEmpty) ...[
                                Text(
                                  'Mã OTP đã gửi tới: $identifier',
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.black54),
                                ),
                                const SizedBox(height: 12),
                              ],

                              // OTP
                              TextFormField(
                                controller: _otp,
                                keyboardType: TextInputType.number,
                                decoration: _deco(
                                  label: 'Mã OTP (6 số)',
                                  icon: Icons.verified_user_outlined,
                                ),
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) => _pwdFocus.requestFocus(),
                                validator: (v) => (v == null || v.trim().length != 6)
                                    ? 'Nhập đúng 6 số'
                                    : null,
                              ),
                              const SizedBox(height: 16),

                              // Mật khẩu mới
                              TextFormField(
                                controller: _pwd,
                                focusNode: _pwdFocus,
                                obscureText: _ob1,
                                decoration: _deco(
                                  label: 'Mật khẩu mới (≥ 6 ký tự)',
                                  icon: Icons.lock_reset,
                                  suffix: IconButton(
                                    icon: Icon(
                                        _ob1 ? Icons.visibility : Icons.visibility_off,
                                        color: kBrand),
                                    onPressed: () =>
                                        setState(() => _ob1 = !_ob1),
                                  ),
                                ),
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) => _pwd2Focus.requestFocus(),
                                validator: (v) =>
                                    (v == null || v.length < 6)
                                        ? 'Tối thiểu 6 ký tự'
                                        : null,
                              ),
                              const SizedBox(height: 16),

                              // Nhập lại
                              TextFormField(
                                controller: _pwd2,
                                focusNode: _pwd2Focus,
                                obscureText: _ob2,
                                decoration: _deco(
                                  label: 'Nhập lại mật khẩu',
                                  icon: Icons.lock_outline,
                                  suffix: IconButton(
                                    icon: Icon(
                                        _ob2 ? Icons.visibility : Icons.visibility_off,
                                        color: kBrand),
                                    onPressed: () =>
                                        setState(() => _ob2 = !_ob2),
                                  ),
                                ),
                                validator: (v) =>
                                    (v != _pwd.text) ? 'Không khớp' : null,
                              ),
                              const SizedBox(height: 10),

                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _resending ? null : _resendOtp,
                                  child: _resending
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Text('Gửi lại OTP'),
                                ),
                              ),
                              const SizedBox(height: 6),

                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _submit,
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
                                            'Đổi mật khẩu',
                                            key: ValueKey('reset-text'),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
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

          if (_loading)
            IgnorePointer(
              ignoring: true,
              child: Container(color: Colors.black.withOpacity(.04)),
            ),
        ],
      ),
    );
  }
}

// Icon tròn (đồng bộ phong cách)
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
      child: Icon(Icons.lock_person_outlined, color: kBrand, size: iconSize),
    );
  }
}
