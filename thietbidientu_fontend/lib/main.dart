import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thietbidientu_fontend/config.dart';

// Admin screens
import 'package:thietbidientu_fontend/screens/admin/admin_dashboard.dart';
import 'package:thietbidientu_fontend/screens/admin/user_admin_screen.dart';
import 'package:thietbidientu_fontend/screens/admin/warehouse_screen.dart';
import 'package:thietbidientu_fontend/screens/admin/product_admin_screen.dart';
import 'package:thietbidientu_fontend/screens/admin/supplier_screen.dart';
import 'package:thietbidientu_fontend/screens/admin/stock_screen.dart';
import 'package:thietbidientu_fontend/screens/admin/shipper_screen.dart';
import 'package:thietbidientu_fontend/screens/admin/delivery_screen.dart';
import 'package:thietbidientu_fontend/screens/admin/orders_admin_list_screen.dart';
import 'package:thietbidientu_fontend/screens/admin/coupon_admin_screen.dart';
import 'package:thietbidientu_fontend/screens/admin/category_admin_screen.dart';
import 'package:thietbidientu_fontend/screens/admin/category_create_screen.dart';
import 'package:thietbidientu_fontend/screens/admin/category_edit_screen.dart';
import 'package:thietbidientu_fontend/screens/admin/product_create_screen.dart';
import 'package:thietbidientu_fontend/screens/admin/product_edit_screen.dart';
import 'package:thietbidientu_fontend/screens/admin/settings_screen.dart';

// Customer / Shipper screens
import 'package:thietbidientu_fontend/screens/main_tabs.dart';
import 'package:thietbidientu_fontend/screens/ItemPage.dart';
import 'package:thietbidientu_fontend/screens/CartPage.dart';
import 'package:thietbidientu_fontend/screens/login_screen.dart';
import 'package:thietbidientu_fontend/screens/forgot_password_screen.dart';
import 'package:thietbidientu_fontend/screens/my_orders_screen.dart';
import 'package:thietbidientu_fontend/screens/order_tracking_screen.dart';
import 'package:thietbidientu_fontend/screens/otp_screen.dart';
// ⚠️ Alias để tránh trùng tên
import 'package:thietbidientu_fontend/screens/register_screen.dart' as reg;
import 'package:thietbidientu_fontend/screens/reset_password_screen.dart';
import 'package:thietbidientu_fontend/screens/coupon_screen.dart';
import 'package:thietbidientu_fontend/screens/notification_screen.dart';
import 'package:thietbidientu_fontend/screens/checkout_page.dart';
import 'package:thietbidientu_fontend/screens/address_book_screen.dart';
import 'package:thietbidientu_fontend/screens/reviews_screen.dart' as rv;
import 'package:thietbidientu_fontend/screens/thank_you_screen.dart';
import 'package:thietbidientu_fontend/screens/write_review_screen.dart';
import 'package:thietbidientu_fontend/screens/payment_otp_screen.dart';
import 'package:thietbidientu_fontend/screens/shipper_home_screen.dart'; // ✅ thêm

// Services/State
import 'services/auth_storage.dart';
import 'state/auth_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AppConfig.resetSavedBase();
    final base = await AppConfig.ensureBaseUrl();
    // ignore: avoid_print
    print('>>> AppConfig.baseUrl = $base');
  } catch (e) {
    // ignore: avoid_print
    print('>>> ensureBaseUrl error: $e');
  }
  runApp(const MyApp());
}

const _brand = Color(0xFF353839);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme =
        ColorScheme.fromSeed(seedColor: _brand, brightness: Brightness.light);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFF4F6FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: _brand,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          toolbarHeight: 56,
        ),
        iconTheme: const IconThemeData(color: _brand),
      ),
      home: const _RootGate(),
      routes: {
        // ===== Customer =====
        '/app': (context) => const MainTabs(),
        '/shipper': (context) => const ShipperHomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/forgot': (context) => const ForgotPasswordScreen(),
        '/request-otp': (context) => const ForgotPasswordScreen(),
        '/otp': (context) => OtpScreen(),
        '/reset': (context) => ResetPasswordScreen(),
        '/reset-password': (context) => ResetPasswordScreen(),
        '/register': (context) => const reg.RegisterScreen(),
        '/cart': (context) => CartPage(),
        '/coupon': (context) => CouponScreen(),
        '/notification': (context) => NotificationScreen(),
        '/checkout': (context) => CheckoutPage(),
        '/addresses': (context) => const AddressBookScreen(),
        '/order-tracking': (context) => OrderTrackingScreen(),
        '/orders': (context) => const MyOrdersScreen(),
        '/thank-you': (context) => const ThankYouScreen(),
        '/writeReview': (context) => const WriteReviewScreen(),
        '/payment-otp': (context) => const PaymentOtpScreen(),
'/admin/users': (context) => const UserAdminScreen(),

        // '/reviews' nhận productId từ arguments
        '/reviews': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          int productId = 0;
          if (args is int) {
            productId = args;
          } else if (args is String) {
            productId = int.tryParse(args) ?? 0;
          } else if (args is Map) {
            productId =
                int.tryParse('${args['productId'] ?? args['id']}') ?? 0;
          }
          if (productId == 0) {
            return const _RouteError(
                'Thiếu productId khi mở màn tất cả đánh giá');
          }

          return rv.ReviewsScreen(productId: productId);
        },

        // itemPage: nhận int/String/Map{productId}
        '/itemPage': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          int productId = 0;
          if (args is int) {
            productId = args;
          } else if (args is String) {
            productId = int.tryParse(args) ?? 0;
          } else if (args is Map) {
            productId = int.tryParse('${args['productId']}') ?? 0;
          }
          if (productId > 0) return ItemPage(productId: productId);
          return const Scaffold(
              body: Center(child: Text('Product ID không hợp lệ')));
        },

        // ===== Admin =====
        '/admin': (context) => const AdminDashboard(),
        '/admin/warehouse': (context) => const WarehouseScreen(),
        '/admin/products': (context) => const ProductAdminScreen(),
        '/admin/products/new': (context) => const ProductCreateScreen(),
        '/admin/products/edit': (context) {
          final id = ModalRoute.of(context)?.settings.arguments as int?;
          if (id == null) {
            return const _RouteError('Thiếu productId khi mở màn sửa');
          }
          return ProductEditScreen(productId: id);
        },
        '/admin/categories': (context) => const CategoryAdminScreen(),
        '/admin/categories/new': (context) => const CategoryCreateScreen(),
        '/admin/categories/edit': (context) {
          final id = ModalRoute.of(context)?.settings.arguments as int?;
          if (id == null) {
            return const _RouteError('Thiếu categoryId khi mở màn sửa');
          }
          return CategoryEditScreen(categoryId: id);
        },
        '/admin/suppliers': (context) => const SupplierScreen(),
        '/admin/stock': (context) => const StockScreen(),
        '/admin/shippers': (context) => const ShipperScreen(),

        // Giao hàng: 1 route dùng cho cả danh sách & chi tiết
        '/admin/delivery': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is int && args > 0) return DeliveryScreen(orderId: args);
          if (args is Map && args['orderId'] != null) {
            final id = int.tryParse('${args['orderId']}') ?? 0;
            if (id > 0) return DeliveryScreen(orderId: id);
          }
          return const OrderAdminScreen();
        },

        '/admin/orders': (context) => const OrderAdminScreen(),
        '/admin/coupons': (context) => const CouponAdminScreen(),
        '/admin/settings': (context) => const AdminSettingsScreen(),
      },
    );
  }
}

class _GateResult {
  final bool hasToken;
  final String role;
  const _GateResult({required this.hasToken, required this.role});
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  Future<_GateResult> _bootstrap() async {
    final token = await AuthStorage.getAccessToken();
    await AuthState.I.loadFromStorage();
    final sp = await SharedPreferences.getInstance();
    final role = (sp.getString('role') ?? '').toLowerCase().trim();
    final hasToken = token != null && token.isNotEmpty;
    return _GateResult(hasToken: hasToken, role: role);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_GateResult>(
      future: _bootstrap(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final r = snap.data ?? const _GateResult(hasToken: false, role: '');
        if (!r.hasToken) return const LoginScreen();

        // ✅ phân 3 role: admin / shipper / customer
        if (r.role == 'admin') return const AdminDashboard();
        if (r.role == 'shipper') return const ShipperHomeScreen();
        return const MainTabs();
      },
    );
  }
}

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

/// ====== SHIM TẠM THỜI CHO ROUTE /reviews ======
class ReviewsScreenShim extends StatelessWidget {
  final int productId;
  const ReviewsScreenShim({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tất cả đánh giá')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Chưa liên kết màn hình đánh giá.\n'
            'productId: $productId\n\n'
            '→ Khi bạn có class thật trong reviews_screen.dart (ví dụ ProductReviewsScreen), '
            'hãy sửa route /reviews để trả về: \n'
            'return rv.ProductReviewsScreen(productId: productId);',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
