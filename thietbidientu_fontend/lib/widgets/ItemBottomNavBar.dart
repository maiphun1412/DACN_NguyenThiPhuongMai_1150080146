import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class ItemBottomNavBar extends StatelessWidget {
  const ItemBottomNavBar({
    super.key,
    required this.onContact,
    required this.onAddToCart,
    required this.onBuyNow,
    this.adding = false,
  });

  final VoidCallback onContact;
  final VoidCallback onAddToCart;
  final VoidCallback onBuyNow;
  final bool adding;

  static const Color brand = Color(0xFF353839);
  static const Color line = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    // Clamp text scale trong thanh dưới để không đội chiều cao
    final mq = MediaQuery.of(context);
    final clampedTextScaler = mq.textScaler.clamp(maxScaleFactor: 1.0);

    return MediaQuery(
      data: mq.copyWith(textScaler: clampedTextScaler),
      child: SafeArea(
        // để SafeArea tự thêm padding đáy theo gesture bar
        top: false,
        bottom: true,
        child: Container(
          // KHÔNG margin dưới để không chạm gesture pill
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          height: 60, // khóa cứng tổng chiều cao thanh
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6)),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _PillIcon(icon: CupertinoIcons.chat_bubble_2, label: 'Liên hệ', onTap: onContact),
              const SizedBox(width: 8),
              _PillIcon(
                icon: CupertinoIcons.cart_badge_plus,
                label: 'Giỏ hàng',
                onTap: adding ? null : onAddToCart,
                loading: adding,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44, // thấp hơn 1 chút để dư địa -> không tràn
                  child: ElevatedButton(
                    onPressed: onBuyNow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brand,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('Mua ngay',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillIcon extends StatelessWidget {
  const _PillIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool loading;

  static const Color brand = Color(0xFF353839);
  static const Color line = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;

    // Khóa kích thước để không bao giờ vượt chiều cao thanh
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 60,
        maxWidth: 78,
        maxHeight: 56, // phải < height tổng (60)
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              width: 40,
              height: 34, // icon box thấp lại
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: line),
              ),
              child: loading
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(icon, size: 18, color: disabled ? Colors.black26 : brand),
            ),
          ),
          const SizedBox(height: 2),
          // label gói trong FittedBox + chiều cao cố định
          SizedBox(
            height: 12,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11.5,
                  color: disabled ? Colors.black38 : brand,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                  letterSpacing: .1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
