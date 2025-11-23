import 'package:flutter/material.dart';
import 'package:thietbidientu_fontend/screens/admin/product_create_screen.dart';
import 'package:thietbidientu_fontend/screens/admin/product_edit_screen.dart';
// ❌ bỏ import delivery_screen ở đây vì shipper dùng màn riêng
// import 'package:thietbidientu_fontend/screens/admin/delivery_screen.dart';

import 'screens/login_screen.dart';
import 'screens/main_tabs.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/shipper_home_screen.dart'; // ✅ thêm
import 'services/auth_storage.dart';

class Routes {
  static const login = '/login';
  static const mainTabs = '/';                 // khách hàng (đang có)
  static const adminDashboard = '/admin';      // admin mới

  // === Thêm 2 route tên rõ ràng cho sản phẩm (admin) ===
  static const adminProductNew  = '/admin/products/new';
  static const adminProductEdit = '/admin/products/edit';

  // === Route dành cho shipper ===
  static const shipperHome = '/shipper';

  static Route<dynamic> onGenerateRoute(RouteSettings s) {
    switch (s.name) {
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case adminDashboard:
        return MaterialPageRoute(
          builder: (_) => const _AdminGuard(child: AdminDashboard()),
        );

      // ---- Thêm sản phẩm (admin) ----
      case adminProductNew:
        return MaterialPageRoute(
          builder: (_) => const _AdminGuard(child: ProductCreateScreen()),
          settings: s,
        );

      // ---- Sửa sản phẩm (admin) ----
      case adminProductEdit:
        final id = s.arguments as int?;
        return MaterialPageRoute(
          builder: (_) => _AdminGuard(
            child: (id == null)
                ? const _RouteError('Thiếu productId khi mở màn sửa')
                : ProductEditScreen(productId: id),
          ),
          settings: s,
        );

      // ---- Màn hình dành cho shipper: dùng ShipperHomeScreen ----
      case shipperHome:
        return MaterialPageRoute(
          builder: (_) => const _ShipperGuard(child: ShipperHomeScreen()),
          settings: s,
        );

      case mainTabs:
      default:
        return MaterialPageRoute(builder: (_) => const MainTabs());
    }
  }
}

/// Chặn truy cập admin nếu role != admin
class _AdminGuard extends StatefulWidget {
  final Widget child;
  const _AdminGuard({required this.child});
  @override
  State<_AdminGuard> createState() => _AdminGuardState();
}

class _AdminGuardState extends State<_AdminGuard> {
  bool? allow;
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final role = (await AuthStorage.getRole())?.toLowerCase();
    setState(() => allow = role == 'admin');
  }

  @override
  Widget build(BuildContext context) {
    if (allow == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (allow == false) {
      Future.microtask(
        () => Navigator.pushReplacementNamed(context, Routes.mainTabs),
      );
      return const SizedBox.shrink();
    }
    return widget.child;
  }
}

/// Guard riêng cho shipper (role == 'shipper')
class _ShipperGuard extends StatefulWidget {
  final Widget child;
  const _ShipperGuard({required this.child});
  @override
  State<_ShipperGuard> createState() => _ShipperGuardState();
}

class _ShipperGuardState extends State<_ShipperGuard> {
  bool? allow;
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final role = (await AuthStorage.getRole())?.toLowerCase();
    setState(() => allow = role == 'shipper');
  }

  @override
  Widget build(BuildContext context) {
    if (allow == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (allow == false) {
      Future.microtask(
        () => Navigator.pushReplacementNamed(context, Routes.mainTabs),
      );
      return const SizedBox.shrink();
    }
    return widget.child;
  }
}

// Nhỏ gọn: hiện lỗi route/args nếu có
class _RouteError extends StatelessWidget {
  final String msg;
  const _RouteError(this.msg);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lỗi')),
      body: Center(child: Text(msg)),
    );
  }
}
