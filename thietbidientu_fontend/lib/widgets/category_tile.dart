import 'package:flutter/material.dart';

/// Chip danh mục: khung xám nhỏ gọn, icon & chữ giữ nguyên kích thước.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    this.imageUrl,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final String? imageUrl;
  final bool selected;
  final VoidCallback? onTap;

  // ✅ Thu nhỏ pill thêm nữa, nhưng icon/chữ giữ nguyên
  static const double _chipMinHeight = 44; // trước 48
  static const double _iconSize = 30;      // giữ nguyên
  static const double _textSize = 15;      // giữ nguyên
  static const double _vPad = 4;           // trước 6
  static const double _hPad = 10;
  static const double _radius = 24;

  @override
  Widget build(BuildContext context) {
    final bgGradient = selected
        ? const LinearGradient(
            colors: [Color(0xFF353839), Color(0xFF111827)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(colors: [Color(0xFFE5E7EB), Color(0xFFE5E7EB)]);

    final bg = selected ? const Color(0xFFF9FAFB) : Colors.white;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(1.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: bgGradient,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: _hPad, vertical: _vPad),
          constraints: const BoxConstraints(minHeight: _chipMinHeight), // ✅ thấp hơn
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF353839).withOpacity(.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : const [
                    BoxShadow(blurRadius: 3, offset: Offset(0, 1), color: Color(0x08000000)),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(_radius),
                child: (imageUrl != null && imageUrl!.isNotEmpty)
                    ? Image.network(
                        imageUrl!,
                        width: _iconSize,  // giữ nguyên 30
                        height: _iconSize,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallback(),
                      )
                    : _fallback(),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: _textSize, // giữ nguyên 15
                  fontWeight: FontWeight.w700,
                  color: selected ? const Color(0xFF111827) : const Color(0xFF374151),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallback() => Container(
        width: _iconSize,
        height: _iconSize,
        color: const Color(0xFFF3F4F6),
        child: const Icon(Icons.category_outlined, size: 18, color: Color(0xFF9CA3AF)),
      );
}
