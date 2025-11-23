// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../state/auth_state.dart';

const kBrand = Color(0xFF353839);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _pwdFocus = FocusNode();

  late final AnimationController _enterCtrl; // fade + slide
  late final Animation<double> _fade;
  late final Animation<Offset> _slideUp;

  late final AnimationController _pulseCtrl; // avatar pulse
  late final Animation<double> _pulse;

  bool _obscure = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fade =
        CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, .12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic),
    );
    _enterCtrl.forward();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: .96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final dynamic result =
          await AuthService.login(_idCtrl.text.trim(), _pwdCtrl.text);

      setState(() => _loading = false);

      if (result is Map) {
        final Map<String, dynamic> res =
            Map<String, dynamic>.from(result as Map);
        // Lưu user + token vào AuthState + storage
        await AuthState.I.applyLoginResponse(res);

        final dynamic userDyn = res['user'];
        final Map<String, dynamic> user =
            (userDyn is Map) ? Map<String, dynamic>.from(userDyn as Map) : {};
        final dynamic roleDyn =
            user['Role'] ?? user['role'] ?? res['role'];
        final String roleFromRes =
            (roleDyn ?? '').toString().toLowerCase();

        // Ưu tiên role đã decode trong AuthState, nếu trống thì fallback
        final String finalRole =
            (AuthState.I.role ?? roleFromRes).toLowerCase();

        _showSnack('Đăng nhập thành công!');
        if (!mounted) return;

        if (finalRole == 'admin') {
          Navigator.pushNamedAndRemoveUntil(
              context, '/admin', (_) => false);
        } else if (finalRole == 'shipper') {
          Navigator.pushNamedAndRemoveUntil(
              context, '/shipper', (_) => false);
        } else {
          Navigator.pushNamedAndRemoveUntil(
              context, '/app', (_) => false);
        }
        return;
      }

      if (result == true) {
        _showSnack('Đăng nhập thành công!');
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
            context, '/app', (_) => false);
        return;
      }

      _showSnack('Sai thông tin đăng nhập.');
    } catch (e) {
      setState(() => _loading = false);
      _showSnack(e.toString());
    }
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _pulseCtrl.dispose();
    _idCtrl.dispose();
    _pwdCtrl.dispose();
    _pwdFocus.dispose();
    super.dispose();
  }

  InputDecoration _deco({
    required String label,
    IconData? icon,
    Widget? suffix,
  }) {
    const borderGrey = Color(0xFF9AA4B2); // xám đậm hơn
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: kBrand) : null,
      suffixIcon: suffix,
      hintStyle: TextStyle(
        color: Colors.grey.shade700,
        fontWeight: FontWeight.w500,
      ),
      labelStyle: const TextStyle(
        color: Color(0xFF2C2F33),
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
        borderSide:
            const BorderSide(color: Colors.redAccent, width: 1.8),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            const BorderSide(color: Colors.redAccent, width: 2.2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Thanh trên cùng
      appBar: AppBar(
        backgroundColor: kBrand,
        centerTitle: true,
        title: const Text('Đăng nhập',
            style: TextStyle(color: Colors.white)),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      backgroundColor: const Color(0xFFF8FAFD),
      body: Stack(
        children: [
          // Nền gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(0, -1),
                end: Alignment(0, .9),
                colors: [Color(0xFFF8FAFD), Color(0xFFF1F4F9)],
              ),
            ),
          ),
          // Vòng tròn trang trí
          Positioned(
            top: -80,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kBrand.withOpacity(.06),
              ),
            ),
          ),
          Positioned(
            top: 100,
            left: -60,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kBrand.withOpacity(.05),
              ),
            ),
          ),

          // ✅ Khung nội dung ở giữa, maxWidth ~ 420 cho web
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 420, // trên web chỉ rộng tới đây
              ),
              child: SafeArea(
                child: FadeTransition(
                  opacity: _fade,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 22),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),

                        // Avatar logo
                        ScaleTransition(
                          scale: _pulse,
                          child: const _TopLogo(size: 78),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'MaiTech Shop',
                          style: TextStyle(
                            color: kBrand,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Chào mừng bạn quay lại 👋',
                          style: TextStyle(
                            color: kBrand.withOpacity(.75),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Card form
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
                              padding: const EdgeInsets.fromLTRB(
                                  16, 18, 16, 20),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _idCtrl,
                                      decoration: _deco(
                                        label:
                                            'Email hoặc Số điện thoại',
                                        icon: Icons.person_outline,
                                      ),
                                      textInputAction:
                                          TextInputAction.next,
                                      onFieldSubmitted: (_) =>
                                          _pwdFocus.requestFocus(),
                                      validator: (v) => (v == null ||
                                              v.trim().isEmpty)
                                          ? 'Nhập email/SĐT'
                                          : null,
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _pwdCtrl,
                                      focusNode: _pwdFocus,
                                      obscureText: _obscure,
                                      decoration: _deco(
                                        label: 'Mật khẩu',
                                        icon: Icons.lock_outline,
                                        suffix: IconButton(
                                          tooltip: _obscure
                                              ? 'Hiện mật khẩu'
                                              : 'Ẩn',
                                          icon: Icon(
                                            _obscure
                                                ? Icons.visibility
                                                : Icons.visibility_off,
                                            color: kBrand,
                                          ),
                                          onPressed: () => setState(
                                              () => _obscure =
                                                  !_obscure),
                                        ),
                                      ),
                                      validator: (v) =>
                                          (v == null || v.length < 4)
                                              ? 'Ít nhất 4 ký tự'
                                              : null,
                                      onFieldSubmitted: (_) =>
                                          _handleLogin(),
                                    ),
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () =>
                                            Navigator.pushNamed(
                                          context,
                                          '/request-otp',
                                          arguments:
                                              _idCtrl.text.trim(),
                                        ),
                                        child:
                                            const Text('Quên mật khẩu?'),
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: ElevatedButton(
                                        onPressed: _loading
                                            ? null
                                            : _handleLogin,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: kBrand,
                                          foregroundColor:
                                              Colors.white,
                                          elevation: 2,
                                          shadowColor:
                                              kBrand.withOpacity(.25),
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
                                                  'Đăng nhập',
                                                  key: ValueKey(
                                                      'login-text'),
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight
                                                              .w700),
                                                ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Row(
                                      children: [
                                        Expanded(
                                          child: Divider(
                                            color:
                                                Color(0xFFE2E6EE),
                                            thickness: 1.2,
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets
                                              .symmetric(
                                                  horizontal: 8),
                                          child: Text('hoặc'),
                                        ),
                                        Expanded(
                                          child: Divider(
                                            color:
                                                Color(0xFFE2E6EE),
                                            thickness: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            Navigator.pushNamed(
                                                context,
                                                '/register'),
                                        style:
                                            OutlinedButton.styleFrom(
                                          foregroundColor: kBrand,
                                          side: const BorderSide(
                                              color: kBrand,
                                              width: 1.4),
                                          shape:
                                              RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    14),
                                          ),
                                        ),
                                        child: const Text(
                                          'Đăng ký',
                                          style: TextStyle(
                                              fontWeight:
                                                  FontWeight.w700),
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
          color: const Color(0xFFE5E7EB),
          width: 1.6,
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 16,
            color: Colors.black12,
            offset: Offset(0, 8),
          ),
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
