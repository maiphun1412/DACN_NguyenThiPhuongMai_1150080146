import 'dart:async';
import 'package:flutter/material.dart';

// AppBar & widgets
import 'package:thietbidientu_fontend/widgets/HomeAppBar.dart';
import 'package:thietbidientu_fontend/widgets/categories_widgets.dart'; // ✅ THÊM IMPORT NÀY
import 'package:thietbidientu_fontend/widgets/product_card.dart';

// Models & services
import 'package:thietbidientu_fontend/models/category.dart';
import 'package:thietbidientu_fontend/models/product.dart';
import 'package:thietbidientu_fontend/services/product_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.onCartTap,
    this.onAccountTap,
    this.onSetTab,
  });

  final VoidCallback? onCartTap;
  final VoidCallback? onAccountTap;
  final ValueChanged<int>? onSetTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchCtl = TextEditingController();
  Timer? _debounce;

  String? _selectedCatId;
  bool _loadingProducts = true;
  List<Product> _products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts({String? categoryId, String q = ''}) async {
    setState(() {
      _loadingProducts = true;
      _selectedCatId = categoryId;
    });
    final items = await ProductService.fetchProducts(categoryId: categoryId, q: q);
    if (!mounted) return;
    setState(() {
      _products = items;
      _loadingProducts = false;
    });
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _loadProducts(categoryId: _selectedCatId, q: v.trim());
    });
    setState(() {});
  }

  Future<void> _refresh() async =>
      _loadProducts(categoryId: _selectedCatId, q: _searchCtl.text.trim());

  int _calcCols(double w) {
    if (w >= 1280) return 5;
    if (w >= 1024) return 4;
    if (w >= 768)  return 3;
    return 2;
  }

  // làm item CAO hơn (nhìn to), giảm khoảng trắng thừa
  double _calcAspectRatio(int cols) {
    if (cols >= 5) return 0.62;
    if (cols == 4) return 0.66;
    if (cols == 3) return 0.72;
    return 0.78; // mobile 2 cột
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final cols = _calcCols(w);
    final aspect = _calcAspectRatio(cols);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: HomeAppBar(
        onCartTap: widget.onCartTap,
        onAccountTap: widget.onAccountTap ?? () => widget.onSetTab?.call(3),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // khối chính
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(blurRadius: 8, offset: Offset(0, -2), color: Color(0x08000000))],
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12), // giảm padding tổng
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // tìm kiếm
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0x11000000)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchCtl,
                            onChanged: _onSearchChanged,
                            onSubmitted: (v) => _loadProducts(categoryId: _selectedCatId, q: v.trim()),
                            decoration: InputDecoration(
                              hintText: 'Tìm sản phẩm...',
                              border: InputBorder.none,
                              isDense: true,
                              suffixIcon: (_searchCtl.text.isNotEmpty)
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _searchCtl.clear();
                                        _loadProducts(categoryId: _selectedCatId, q: '');
                                        setState(() {});
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        const Icon(Icons.qr_code_scanner, color: Colors.grey, size: 20),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // heading + Tất cả (cùng 1 hàng)
                  Row(
                    children: [
                      const Icon(Icons.grid_view_rounded, size: 18, color: Color(0xFF6B7280)),
                      const SizedBox(width: 6),
                      const Text('Loại sản phẩm',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _loadProducts(
                          categoryId: null,
                          q: _searchCtl.text.trim(),
                        ),
                        child: const Text('Tất cả'),
                      ),
                    ],
                  ),

                  // danh mục (widget có selectedCategoryId)
                  CategoriesWidget(
                    selectedCategoryId: _selectedCatId,
                    onSelected: (CategoryModel c) {
                      final idStr = c.id.toString();
                      _loadProducts(categoryId: idStr, q: _searchCtl.text.trim());
                    },
                  ),

                  const SizedBox(height: 6),

                  // heading bán chạy
                  const Row(
                    children: [
                      Icon(Icons.local_fire_department_rounded, size: 18, color: Color(0xFF6B7280)),
                      SizedBox(width: 6),
                      Text('Bán chạy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // grid
                  if (_loadingProducts)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _products.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        childAspectRatio: aspect,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                      ),
                      itemBuilder: (_, i) => ProductCard(
                        p: _products[i],
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/itemPage',
                          arguments: _products[i].id,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
