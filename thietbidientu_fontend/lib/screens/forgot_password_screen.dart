// lib/screens/forgot_password_screen.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

const kBrand = Color(0xFF353839);

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  bool _loading = false;

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
    _idCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final ok = await AuthService.sendOtp(_idCtrl.text.trim());
    setState(() => _loading = false);

    if (!mounted) return;
    if (ok) {
      _showSnack('Đã gửi mã OTP!');
      // Giữ nguyên route như hiện tại của bạn
      Navigator.pushNamed(context, '/otp', arguments: _idCtrl.text.trim());
    } else {
      _showSnack('Không gửi được OTP, thử lại.');
    }
  }

  // InputDecoration: viền rõ, focus dày (giống các màn khác)
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: kBrand,
        title: const Text('Quên mật khẩu', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Nền gradient + vòng tròn mờ (tone sáng, rõ)
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
                              const Text(
                                'Nhập email hoặc số điện thoại để nhận mã OTP',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 14),

                              TextFormField(
                                controller: _idCtrl,
                                decoration: _deco(
                                  label: 'Email / Số điện thoại',
                                  icon: Icons.alternate_email,
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'Không được để trống'
                                    : null,
                                onFieldSubmitted: (_) => _sendOtp(),
                              ),
                              const SizedBox(height: 18),

                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _sendOtp,
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
                                            'Gửi mã OTP',
                                            key: ValueKey('send-otp'),
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
      child: Icon(Icons.privacy_tip_outlined, color: kBrand, size: iconSize),
    );
  }
}
