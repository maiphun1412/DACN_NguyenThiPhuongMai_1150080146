import 'package:flutter/material.dart';
import 'package:thietbidientu_fontend/models/category.dart';
import 'package:thietbidientu_fontend/services/category_service.dart';
import 'package:thietbidientu_fontend/widgets/category_tile.dart';

class CategoriesWidget extends StatefulWidget {
  const CategoriesWidget({
    super.key,
    this.onSelected,
    this.selectedCategoryId,
  });

  final ValueChanged<CategoryModel>? onSelected;
  final String? selectedCategoryId;

  @override
  State<CategoriesWidget> createState() => _CategoriesWidgetState();
}

class _CategoriesWidgetState extends State<CategoriesWidget> {
  late Future<List<CategoryModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = CategoryService.list(); // giữ thứ tự từ BE (SortOrder)
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CategoryModel>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 56,
            child: Center(
              child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }

        if (snapshot.hasError) {
          return SizedBox(
            height: 56,
            child: Center(
              child: Text('Lỗi khi tải danh mục', style: TextStyle(color: Colors.red.shade700)),
            ),
          );
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const SizedBox(
            height: 56,
            child: Center(child: Text('Chưa có danh mục')),
          );
        }

        return SizedBox(
          height: 56, // ✅ nhỏ hơn nữa
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final c = items[i];
              final selected = c.id.toString() == widget.selectedCategoryId;
              return CategoryChip(
                label: c.name,
                imageUrl: c.image,
                selected: selected,
                onTap: () => widget.onSelected?.call(c),
              );
            },
          ),
        );
      },
    );
  }
}
