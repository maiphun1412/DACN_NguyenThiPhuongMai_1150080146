import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class ItemBottomNavBar extends StatelessWidget {
  const ItemBottomNavBar({
    super.key,
    required this.price,
    required this.onAddToCart,
    this.adding = false,
  });

  final double price;
  final VoidCallback onAddToCart;
  final bool adding;

  String _formatVnd(double n) =>
      n.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFF353839);

    return BottomAppBar(
      color: Colors.transparent,
      elevation: 0,
      child: SafeArea(
        top: false,
        child: Container(
          height: 78,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              // Giá (pill)
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE9EEF3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Giá ', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    Text(
                      '${_formatVnd(price)}đ',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: brand),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // CTA
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: adding ? null : onAddToCart,
                    icon: adding
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(CupertinoIcons.cart_badge_plus),
                    label: Text(
                      adding ? 'Đang thêm...' : 'Thêm vào giỏ',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brand,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
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
