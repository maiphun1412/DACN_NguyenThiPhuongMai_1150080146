// lib/screens/coupon_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:thietbidientu_fontend/widgets/HomeAppBar.dart';
import '../models/coupon.dart';
import '../services/coupon_service.dart';

class CouponScreen extends StatefulWidget {
  const CouponScreen({super.key});
  @override
  State<CouponScreen> createState() => _CouponScreenState();
}

class _CouponScreenState extends State<CouponScreen> {
  late Future<List<Coupon>> _future;

  @override
  void initState() {
    super.initState();
    _future = CouponService.fetchAll();
  }

  Future<void> _refresh() async {
    setState(() => _future = CouponService.fetchAll());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const HomeAppBar(title: 'Ưu đãi'),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          children: [
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: PageView(
                children: [
                  _promoBanner("images/banner1.jpg"),
                  _promoBanner("images/banner2.jpg"),
                  _promoBanner("images/banner3.jpg"),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _quickActions(),
            const SizedBox(height: 12),

            // ====== DATA ======
            FutureBuilder<List<Coupon>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Không tải được ưu đãi: ${snap.error}'),
                  );
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Chưa có ưu đãi nào.'),
                  );
                }

                // Gợi ý: có thể lọc chỉ hiển thị còn hạn & active
                // final now = DateTime.now();
                // final items = (snap.data ?? []).where((c) =>
                //   c.isActive &&
                //   (c.startDate == null || !c.startDate!.isAfter(now)) &&
                //   (c.endDate == null || !c.endDate!.isBefore(now))
                // ).toList();

                return Column(
                  children: [
                    for (final c in items) _couponCard(context, c),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ===== Widgets con =====

  Widget _promoBanner(String path) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(image: AssetImage(path), fit: BoxFit.cover),
      ),
    );
  }

  Widget _quickActions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 12)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _actionButton(Icons.qr_code, 'Nhập mã', () {
            // TODO: mở dialog nhập mã
          }),
          _actionButton(Icons.card_giftcard, 'Quà của tôi', () {}),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey.shade200,
            radius: 28,
            child: Icon(icon, size: 28, color: const Color(0xFF353839)),
          ),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _couponCard(BuildContext context, Coupon c) {
    final fDate = DateFormat('dd/MM/yyyy');
    final isExpired = c.endDate != null && c.endDate!.isBefore(DateTime.now());
    final canUse = c.isActive && !isExpired;
    final color = canUse ? Colors.green : Colors.grey;
    final title = _discountText(c);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 10)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(CupertinoIcons.ticket_fill, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.code,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                if (c.name?.isNotEmpty == true)
                  Text(c.name!, style: const TextStyle(color: Colors.black87)),
                Text(title, style: const TextStyle(color: Colors.black87)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: -4,
                  children: [
                    if (c.minOrderTotal != null && c.minOrderTotal! > 0)
                      _chip('Đơn tối thiểu ${_vnd(c.minOrderTotal!)}'),
                    if (c.maxDiscount != null && c.maxDiscount! > 0)
                      _chip('Giảm tối đa ${_vnd(c.maxDiscount!)}'),
                    if (c.perUserLimit != null) _chip('Giới hạn/người: ${c.perUserLimit}'),
                    if (c.usageLimit != null) _chip('Tổng lượt: ${c.usageLimit}'),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  [
                    if (c.startDate != null) 'Từ ${fDate.format(c.startDate!)}',
                    if (c.endDate != null) 'đến ${fDate.format(c.endDate!)}',
                    if (!canUse) '(Hết hạn/không khả dụng)'
                  ].join(' '),
                  style: TextStyle(fontSize: 12, color: canUse ? Colors.grey[700] : Colors.red),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: canUse ? color : Colors.grey,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: !canUse
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: c.code));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đã sao chép mã ${c.code}')),
                      );
                    }
                  },
            child: const Text('Sao chép'),
          ),
        ],
      ),
    );
  }

  String _discountText(Coupon c) {
    if (c.discountType == 'PERCENT' || c.discountType == 'PERCENTAGE') {
      return 'Giảm ${c.discountValue.toStringAsFixed(0)}%';
    }
    // FIXED/AMOUNT => tiền mặt
    return 'Giảm ${_vnd(c.discountValue)}';
  }

  String _vnd(double v) {
    final nf = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    return nf.format(v);
  }

  Widget _chip(String text) {
    return Chip(
      label: Text(text, style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}
