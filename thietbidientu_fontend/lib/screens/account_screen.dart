// lib/screens/account_screen.dart
import 'package:flutter/material.dart';
import 'package:thietbidientu_fontend/screens/my_orders_screen.dart';
import 'package:thietbidientu_fontend/screens/shop_info_page.dart';
import 'package:thietbidientu_fontend/widgets/HomeAppBar.dart';
import 'package:thietbidientu_fontend/services/auth_service.dart';
import 'package:thietbidientu_fontend/state/auth_state.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:thietbidientu_fontend/config.dart'; // ⬅️ để lấy base URL BE

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  // ===== THÊM: helper mở link / gọi điện bằng url_launcher =====
  static Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở đường dẫn')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const HomeAppBar(title: 'Tài khoản của tôi'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Header thông tin người dùng ────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _box,
            child: ValueListenableBuilder<Map<String, dynamic>?>(
              valueListenable: AuthState.I.user,
              builder: (context, u, _) {
                // Khi vừa mở app, có thể u đang null 1 nhịp → show progress nhỏ
                if (u == null) {
                  return const SizedBox(
                    height: 56,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final name  = u['name'] ?? u['fullName'] ?? 'Khách';
                final email = (u['email'] ?? '').toString();
                final userAvatar = (u['avatarUrl'] as String?)?.trim();

                return Row(
                  children: [
                    // ⬇️ Avatar: ưu tiên ảnh user, fallback ảnh BE /static/logo/logo.jpg, cuối cùng là asset
                    FutureBuilder<String>(
                      future: AppConfig.ensureBaseUrl(),
                      builder: (ctx, snap) {
                        final base = snap.data;
                        final fallback = (base != null) ? '$base/static/logo/logo.jpg' : null;
                        final url = (userAvatar != null && userAvatar.isNotEmpty)
                            ? userAvatar
                            : fallback;

                        return ClipOval(
                          child: (url == null)
                              ? Image.asset(
                                  'assets/images/avatar.png',
                                  width: 56, height: 56, fit: BoxFit.cover,
                                )
                              : Image.network(
                                  url,
                                  width: 56, height: 56, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Image.asset(
                                    'assets/images/avatar.png',
                                    width: 56, height: 56, fit: BoxFit.cover,
                                  ),
                                ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(
                            email.isEmpty ? '—' : email,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.settings),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // ── Nhóm: Đơn hàng của tôi ─────────────────────────────────────
          _group('Đơn hàng của tôi', [
            _tile(Icons.receipt_long, 'Đơn mua', () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
              );
            }),
            _tile(Icons.history, 'Lịch sử mua hàng', () {
              // Nếu MyOrdersScreen có tab/filter, có thể truyền arguments ở đây.
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
              );
            }),
          ]),

          const SizedBox(height: 16),

          // ── Nhóm: Tiện ích ─────────────────────────────────────────────
          _group('Tiện ích', [
            _tile(Icons.account_balance_wallet, 'Ví trả sau', () {}),
            _tile(Icons.local_shipping, 'Đơn đang giao', () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MyOrdersScreen()),
              );
            }),
            _tile(Icons.reviews, 'Đã đánh giá', () {}),
            _tile(Icons.home, 'Sổ địa chỉ', () {
              Navigator.pushNamed(context, '/addresses');
            }),
          ]),

          const SizedBox(height: 16),

          // ── Nhóm: Hỗ trợ ───────────────────────────────────────────────
          _group('Hỗ trợ', [
            // === CHỈ SỬA DÒNG NÀY: bấm gọi điện ===
            _tile(Icons.call, 'Hotline 0777435604', () {
              _openUrl(context, 'tel:0777435604');
            }),
            // giữ nguyên: mở trang thông tin shop
            _tile(Icons.storefront, 'Thông tin shop', () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ShopInfoPage()),
              );
            }),
          ]),
          const SizedBox(height: 24),

          // ── Nút Đăng xuất ──────────────────────────────────────────────
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: const BorderSide(color: Colors.black12),
            ),
            onPressed: () => _confirmSignOut(context),
            child: const Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Confirm logout ────────────────────────────────────────────────────
  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Đăng xuất')),
        ],
      ),
    );

    if (ok == true) {
      await AuthService.logout(); // xoá token + user + AuthState
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────
  static final _box = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 10)],
  );

  static Widget _group(String title, List<Widget> children) {
    return Container(
      decoration: _box,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  static Widget _tile(IconData icon, String text, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF353839)),
      title: Text(text),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
