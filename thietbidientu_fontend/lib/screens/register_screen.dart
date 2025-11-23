// lib/screens/register_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:thietbidientu_fontend/config.dart';          // ✅ để xem baseUrl
import 'package:thietbidientu_fontend/services/api_service.dart'; // ✅ gọi API qua service

const kBrand = Color(0xFF353839);

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();

  final _emailFocus = FocusNode();
  final _pwdFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _obscurePwd = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  // Animations (đồng bộ với Login)
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
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    _emailFocus.dispose();
    _pwdFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pwdCtrl.text != _confirmPwdCtrl.text) {
      _toast('Mật khẩu không khớp');
      return;
    }

    setState(() => _loading = true);
    try {
      // ✅ Log base để chắc chắn app đang trỏ đúng host
      // ignore: avoid_print
      print('→ REGISTER using base: ${AppConfig.baseUrl}');

      final api = ApiService();
      final rs = await api.register(
        email: _emailCtrl.text.trim(),
        password: _pwdCtrl.text,
        fullName: _nameCtrl.text.trim(),
      );
      // ignore: avoid_print
      print('← REGISTER OK: $rs');

      if (!mounted) return;
      _toast('Đăng ký thành công, vui lòng đăng nhập');
      Navigator.pushReplacementNamed(context, '/login');
    } on TimeoutException {
      if (!mounted) return;
      _toast('Hết thời gian chờ kết nối (timeout)');
    } catch (e) {
      if (!mounted) return;
      _toast('Đăng ký thất bại: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // InputDecoration đồng bộ với Login: viền rõ & dày hơn
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
      // Nền sáng giống màn Login
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: kBrand,
        title: const Text('Đăng ký', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Gradient + vòng tròn mờ
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

          // ✅ Bọc nội dung trong Center + ConstrainedBox giống Login
          FadeTransition(
            opacity: _fade,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    child: Column(
                      children: [
                        const SizedBox(height: 4),
                        // Icon tròn + pulse (đồng bộ)
                        ScaleTransition(
                          scale: _pulse,
                          child: const _TopLogo(size: 72),
                        ),
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

                        // Card form: border + elevation rõ ràng
                        SlideTransition(
                          position: _slideUp,
                          child: Material(
                            elevation: 16,
                            color: Colors.white,
                            shadowColor: Colors.black12,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: const BorderSide(
                                color: Color(0xFFC7CFDA),
                                width: 1.6,
                              ),
                            ),
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 18, 16, 20),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    // Họ tên
                                    TextFormField(
                                      controller: _nameCtrl,
                                      decoration: _deco(
                                        label: 'Họ và tên',
                                        icon: Icons.person_outline,
                                      ),
                                      textInputAction: TextInputAction.next,
                                      onFieldSubmitted: (_) =>
                                          _emailFocus.requestFocus(),
                                      validator: (v) => (v == null ||
                                              v.trim().isEmpty)
                                          ? 'Nhập họ tên'
                                          : null,
                                    ),
                                    const SizedBox(height: 16),

                                    // Email
                                    TextFormField(
                                      controller: _emailCtrl,
                                      focusNode: _emailFocus,
                                      decoration: _deco(
                                        label: 'Email',
                                        icon: Icons.email_outlined,
                                      ),
                                      keyboardType:
                                          TextInputType.emailAddress,
                                      textInputAction:
                                          TextInputAction.next,
                                      onFieldSubmitted: (_) =>
                                          _pwdFocus.requestFocus(),
                                      validator: (v) =>
                                          (v == null || !v.contains('@'))
                                              ? 'Email không hợp lệ'
                                              : null,
                                    ),
                                    const SizedBox(height: 16),

                                    // Mật khẩu
                                    TextFormField(
                                      controller: _pwdCtrl,
                                      focusNode: _pwdFocus,
                                      obscureText: _obscurePwd,
                                      decoration: _deco(
                                        label: 'Mật khẩu',
                                        icon: Icons.lock_outline,
                                        suffix: IconButton(
                                          icon: Icon(
                                            _obscurePwd
                                                ? Icons.visibility
                                                : Icons.visibility_off,
                                            color: kBrand,
                                          ),
                                          onPressed: () => setState(
                                              () =>
                                                  _obscurePwd =
                                                      !_obscurePwd),
                                        ),
                                      ),
                                      textInputAction:
                                          TextInputAction.next,
                                      onFieldSubmitted: (_) =>
                                          _confirmFocus.requestFocus(),
                                      validator: (v) =>
                                          (v == null || v.length < 4)
                                              ? 'Ít nhất 4 ký tự'
                                              : null,
                                    ),
                                    const SizedBox(height: 16),

                                    // Xác nhận mật khẩu
                                    TextFormField(
                                      controller: _confirmPwdCtrl,
                                      focusNode: _confirmFocus,
                                      obscureText: _obscureConfirm,
                                      decoration: _deco(
                                        label: 'Xác nhận mật khẩu',
                                        icon: Icons.lock,
                                        suffix: IconButton(
                                          icon: Icon(
                                            _obscureConfirm
                                                ? Icons.visibility
                                                : Icons.visibility_off,
                                            color: kBrand,
                                          ),
                                          onPressed: () => setState(
                                              () =>
                                                  _obscureConfirm =
                                                      !_obscureConfirm),
                                        ),
                                      ),
                                      validator: (v) =>
                                          v != _pwdCtrl.text
                                              ? 'Mật khẩu không khớp'
                                              : null,
                                    ),
                                    const SizedBox(height: 20),

                                    // Nút Đăng ký
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: ElevatedButton(
                                        onPressed: _loading
                                            ? null
                                            : _handleRegister,
                                        style:
                                            ElevatedButton.styleFrom(
                                          backgroundColor: kBrand,
                                          foregroundColor:
                                              Colors.white,
                                          elevation: 2,
                                          shadowColor: kBrand
                                              .withOpacity(.25),
                                          shape:
                                              RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    14),
                                          ),
                                        ),
                                        child: AnimatedSwitcher(
                                          duration: const Duration(
                                              milliseconds: 220),
                                          child: _loading
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2.4,
                                                    color:
                                                        Colors.white,
                                                  ),
                                                )
                                              : const Text(
                                                  'Đăng ký',
                                                  key: ValueKey(
                                                      'reg-text'),
                                                  style: TextStyle(
                                                    fontWeight:
                                                        FontWeight
                                                            .w700,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 14),

                                    // Quay lại đăng nhập
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                            "Đã có tài khoản?"),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator
                                                  .pushReplacementNamed(
                                            context,
                                            '/login',
                                          ),
                                          child: const Text(
                                              "Đăng nhập"),
                                        ),
                                      ],
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
              ),
            ),
          ),

          if (_loading)
            IgnorePointer(
              ignoring: true,
              child: Container(
                color: Colors.black.withOpacity(.04),
              ),
            ),
        ],
      ),
    );
  }
}

// Icon tròn (đồng bộ phong cách với Login)
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
        border: Border.all(
            color: const Color(0xFFE5E7EB), width: 1.6),
        boxShadow: const [
          BoxShadow(
            blurRadius: 16,
            color: Colors.black12,
            offset: Offset(0, 8),
          )
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.store_mall_directory,
        color: kBrand,
        size: iconSize,
      ),
    );
  }
}
