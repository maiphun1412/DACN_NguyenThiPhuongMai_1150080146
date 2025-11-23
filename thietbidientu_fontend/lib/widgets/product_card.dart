import 'package:flutter/material.dart';
import '../models/product.dart';
// Nếu không dùng SoldTracker nữa thì có thể xoá import này,
// nhưng để nguyên cũng không sao, chỉ cảnh báo unused.
// import '../utils/shop_utils.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.p,
    this.onTap,
    this.onFav,
  });

  final Product p;
  final VoidCallback? onTap;
  final VoidCallback? onFav;

  @override
  Widget build(BuildContext context) {
    final discount = (p.discount ?? 0);
    final hasDiscount = discount > 0;
    const primary = Color(0xFF353839);

    // ✅ LẤY TRỰC TIẾP TỪ PRODUCT (API)
    final int sold = p.sold;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Hàng trên cùng: giảm giá + tim ---
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Row(
                children: [
                  if (hasDiscount)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '-${discount.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onFav,
                    child: const Icon(
                      Icons.favorite_border,
                      color: Color(0xFFE74C3C),
                    ),
                  ),
                ],
              ),
            ),

            // --- ẢNH sản phẩm ---
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: Colors.white, // nền trắng
                  alignment: Alignment.center,
                  child: (p.thumb == null || p.thumb!.isEmpty)
                      ? const Icon(Icons.image, size: 40, color: Colors.black26)
                      : Image.network(
                          p.thumb!,
                          fit: BoxFit.contain, // không crop
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image_outlined,
                                  size: 40, color: Colors.black26),
                        ),
                ),
              ),
            ),

            // --- Tên sản phẩm ---
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              child: Text(
                p.name.isEmpty ? 'Thông tin sản phẩm' : p.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
            ),

            const SizedBox(height: 4),

            // --- Info: Đã bán + Giao nhanh ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Text(
                    'Đã bán $sold',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Text(
                      'Giao nhanh',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // --- Giá + nút giỏ ---
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _formatCurrency(p.price),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFDEDEDE)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.shopping_cart_outlined,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(num? v) {
    if (v == null) return '—';
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    var count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buf.write(s[i]);
      count++;
      if (count == 3 && i != 0) {
        buf.write('.');
        count = 0;
      }
    }
    return '${buf.toString().split('').reversed.join()} đ';
  }
}
