import 'package:flutter/material.dart';
import 'package:thietbidientu_fontend/models/product.dart';

class ItemsWidget extends StatelessWidget {
  const ItemsWidget({
    super.key,
    this.products,
  });

  /// Nếu truyền vào list Product thì hiển thị theo dữ liệu thật (kèm đã bán)
  /// Nếu null/empty thì dùng data demo như cũ.
  final List<Product>? products;

  String _formatVnd(num n) => n
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');

  @override
  Widget build(BuildContext context) {
    final list = products;

    // ====== MODE DEMO CŨ (không nối API) ======
    if (list == null || list.isEmpty) {
      return GridView.count(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        // Cao hơn nhẹ để có chỗ cho title + giá (không overflow)
        childAspectRatio: 0.86,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          for (int i = 1; i <= 8; i++)
            _ItemCard(
              title: 'Thông tin sản phẩm',
              subtitle: 'Viết mô tả sản phẩm',
              price: 5990000,
              asset: 'images/$i.jpg',
              discount: 50,
              sold: 0, // demo
              onTap: (ctx) => Navigator.pushNamed(ctx, '/itemPage'),
            ),
        ],
      );
    }

    // ====== MODE DÙNG DỮ LIỆU THẬT (products) ======
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: list.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.86,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemBuilder: (ctx, index) {
        final p = list[index];

        // lấy shortDescription hoặc description cho subtitle
        final subtitle = (p.shortDescription ?? p.description ?? '').trim();

        // đọc "sold" từ JSON nếu BE trả về (sold / Sold / soldCount / totalSold ...)
        int baseSold = 0;
        try {
          final d = p as dynamic;
          final v = d.sold ?? d.Sold ?? d.soldCount ?? d.totalSold ?? d.sales ?? 0;
          baseSold = int.tryParse('$v') ?? 0;
        } catch (_) {
          baseSold = 0;
        }

        final discount = (p.discount ?? 0);

        return _ItemCard(
          title: p.name.isEmpty ? 'Thông tin sản phẩm' : p.name,
          subtitle: subtitle.isEmpty ? 'Viết mô tả sản phẩm' : subtitle,
          price: p.price,
          imageUrl: p.thumb ?? p.imageUrl,
          discount: discount > 0 ? discount.toInt() : null,
          sold: baseSold,
          onTap: (ctx) {
            // nếu route itemPage nhận productId thì truyền kèm:
            Navigator.pushNamed(
              ctx,
              '/itemPage',
              arguments: {'productId': p.id},
            );
          },
        );
      },
    );
  }
}

class _ItemCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final num price;

  /// Image từ asset (demo cũ)
  final String? asset;

  /// Ảnh từ network (API)
  final String? imageUrl;

  final int? discount;
  final int sold;
  final void Function(BuildContext) onTap;

  const _ItemCard({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.onTap,
    this.asset,
    this.imageUrl,
    this.discount,
    this.sold = 0,
  });

  String _formatVnd(num n) => n
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFF353839);

    return InkWell(
      onTap: () => onTap(context),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE9EEF3)), // viền mảnh cao cấp
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 10,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top row: badge + tim
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Row(
                children: [
                  if ((discount ?? 0) > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: brand,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '-${discount!.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const Spacer(),
                  const Icon(Icons.favorite_border, color: Color(0xFFE74C3C)),
                ],
              ),
            ),

            // ẢNH – nền trắng, không xám hai bên
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: Colors.white,
                    alignment: Alignment.center,
                    child: _buildImage(),
                  ),
                ),
              ),
            ),

            // Tiêu đề
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, height: 1.15),
              ),
            ),

            // Mô tả nhạt
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.black54),
              ),
            ),

            const SizedBox(height: 6),

            // Info: Đã bán + Giao nhanh
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
                      border: Border.all(color: Color(0xFFE5E7EB)),
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

            // Giá + nút giỏ nổi
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(
                children: [
                  Text(
                    '${_formatVnd(price)} đ',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    elevation: 2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {},
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.add_shopping_cart_rounded,
                          size: 18,
                          color: brand,
                        ),
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

  Widget _buildImage() {
    // ưu tiên ảnh network nếu có
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image_outlined, size: 40, color: Colors.black26),
      );
    }

    if (asset != null && asset!.isNotEmpty) {
      return Image.asset(
        asset!,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image_outlined, size: 40, color: Colors.black26),
      );
    }

    return const Icon(
      Icons.image_outlined,
      size: 40,
      color: Colors.black26,
    );
  }
}
