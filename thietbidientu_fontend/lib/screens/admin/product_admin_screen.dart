import 'dart:async';
import 'package:flutter/material.dart';
import 'package:thietbidientu_fontend/services/admin/admin_product_service.dart';
import 'package:thietbidientu_fontend/services/auth_storage.dart'; // thêm để clear token
import 'package:thietbidientu_fontend/services/category_service.dart'; // NEW: load categories
import '../../config.dart';

/// Debounce nho nhỏ cho ô tìm kiếm
class _Debouncer {
  final int ms;
  Timer? _t;
  _Debouncer([this.ms = 450]);
  void call(void Function() fn) {
    _t?.cancel();
    _t = Timer(Duration(milliseconds: ms), fn);
  }
  void dispose() => _t?.cancel();
}

class ProductAdminScreen extends StatefulWidget {
  const ProductAdminScreen({super.key});
  @override
  State<ProductAdminScreen> createState() => _ProductAdminScreenState();
}

class _ProductAdminScreenState extends State<ProductAdminScreen> {
  final _searchCtrl = TextEditingController();
  final _deb = _Debouncer();

  int _page = 1;
  int _pageSize = 20; // UI only, BE hiện chưa nhận
  int _total = 0;
  bool _loading = false;
  String _q = '';

  List<Map<String, dynamic>> _items = [];

  // ====== NEW: categories (để hiện tên + lọc) ======
  Map<int, String> _catNameById = {};
  List<CategoryItem> _cats = [];
  bool _loadingCats = false;
  int? _filterCatId; // null = tất cả

  @override
  void initState() {
    super.initState();
    _fetch();     // tải trang 1
    _loadCats();  // nạp danh mục
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _deb.dispose();
    super.dispose();
  }

  Future<void> _loadCats() async {
    try {
      setState(() => _loadingCats = true);
      final list = await CategoryService.listSimple();
      _cats = list;
      _catNameById = {for (final c in list) c.id: c.name};
      if (mounted) setState(() {});
    } catch (_) {
      // im lặng nếu lỗi, UI vẫn chạy bình thường
    } finally {
      if (mounted) setState(() => _loadingCats = false);
    }
  }

  Future<void> _fetch({bool reset = false}) async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      if (reset) _page = 1;

      final res = await AdminProductService.list(page: _page, q: _q);

      // ---- mềm hóa cấu trúc trả về
      final rawList = res['items'] ?? res['data'] ?? res['results'] ?? [];
      final list = (rawList as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final totalAny = res['total'] ?? res['Total'] ?? res['count'] ?? res['Count'] ?? 0;
      final total = int.tryParse(totalAny.toString()) ?? 0;

      setState(() {
        _items = list;
        _total = total;
      });
    } catch (e) {
      final msg = e.toString();
      // ---- bắt JWT hết hạn
      if (msg.contains('jwt expired') || msg.contains('401') || msg.contains('Unauthorized')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.')),
          );
        }
        await AuthStorage.clear(); // xóa access/refresh trong storage của em
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xoá sản phẩm?'),
        content: const Text('Sản phẩm sẽ bị vô hiệu hoá (soft delete).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xoá')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AdminProductService.deleteSoft(id);
      _fetch(reset: true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> p) async {
    final id = (p['ProductID'] ?? p['Id'] ?? p['id']) as int;
    final curr = (p['IsActive'] == true) || (p['IsActive'] == 1) || (p['IsActive']?.toString() == 'True');
    try {
      await AdminProductService.update(id, {'IsActive': !curr});
      _fetch();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    final canPrev = _page > 1;
    final maxPage = (_total == 0) ? 1 : ((_total - 1) ~/ _pageSize + 1);
    final canNext = _page < maxPage;

    // NEW: áp dụng lọc danh mục client-side
    final data = _filterCatId == null
        ? _items
        : _items.where((p) {
            final cid = p['CategoryID'] ?? p['categoryId'];
            return cid == _filterCatId;
          }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý sản phẩm')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await Navigator.pushNamed(context, '/admin/products/new');
          if (ok == true) _fetch(reset: true);
        },
        label: const Text('Thêm'),
        icon: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // ===== Thanh tìm kiếm + page size + lọc danh mục =====
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Tìm theo tên/mô tả…',
                      prefixIcon: const Icon(Icons.search),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (v) {
                      _deb(() {
                        _q = v.trim();
                        _fetch(reset: true);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<int>(
                  initialValue: _pageSize,
                  onSelected: (v) {
                    setState(() => _pageSize = v);
                    _fetch(reset: true); // BE hiện chưa đọc pageSize, nhưng UI vẫn hiển thị
                  },
                  itemBuilder: (c) => const [
                    PopupMenuItem(value: 10, child: Text('10 / trang')),
                    PopupMenuItem(value: 20, child: Text('20 / trang')),
                    PopupMenuItem(value: 50, child: Text('50 / trang')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Text('$_pageSize / trang'),
                      const Icon(Icons.arrow_drop_down),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                // NEW: Dropdown lọc danh mục (client-side)
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<int?>(
                    isExpanded: true,
                    value: _filterCatId,
                    decoration: InputDecoration(
                      labelText: 'Danh mục',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Tất cả')),
                      ..._cats.map((c) =>
                          DropdownMenuItem<int?>(value: c.id, child: Text(c.name))),
                    ],
                    onChanged: _loadingCats ? null : (v) => setState(() => _filterCatId = v),
                  ),
                ),
              ],
            ),
          ),

          // ===== List =====
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetch(reset: true),
              child: _loading && _items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : (data.isEmpty
                      ? const Center(child: Text('Không có dữ liệu'))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: data.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final p = data[i];
                            final img = p['MainImage']?.toString();
                            final name = (p['Name'] ?? p['name'] ?? '').toString();
                            final price = (p['Price'] ?? p['price'] ?? '').toString();
                            final stock = int.tryParse((p['Stock'] ?? p['stock'] ?? 0).toString()) ?? 0;
                            final active = (p['IsActive'] == true) || (p['IsActive'] == 1) || (p['IsActive']?.toString() == 'True');
                            final optCount = int.tryParse((p['OptionCount'] ?? 0).toString()) ?? 0;
                            final id = (p['ProductID'] ?? p['Id'] ?? p['id']) as int;

                            final cid = p['CategoryID'] ?? p['categoryId'];
                            final catLabel = cid == null
                                ? '—'
                                : (_catNameById[cid] ?? 'Cat $cid');

                            return Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () async {
                                  final ok = await Navigator.pushNamed(
                                    context,
                                    '/admin/products/edit',
                                    arguments: id,
                                  );
                                  if (ok == true) _fetch();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: img != null && img.isNotEmpty
                                            ? Image.network(
                                                img.startsWith('http') ? img : '${AppConfig.baseUrl}$img',
                                                width: 72,
                                                height: 72,
                                                fit: BoxFit.cover,
                                              )
                                            : Container(
                                                width: 72,
                                                height: 72,
                                                color: Colors.grey.shade200,
                                                child: const Icon(Icons.image_outlined),
                                              ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                            ),
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                _ChipValue(icon: Icons.category_outlined, label: catLabel), // NEW
                                                _ChipValue(icon: Icons.sell_outlined, label: _vnd(price)),
                                                _ChipValue(icon: Icons.inventory_2_outlined, label: 'Stock: $stock'),
                                                _ChipValue(icon: Icons.tune, label: 'Options: $optCount'),
                                                GestureDetector(
                                                  onTap: () => _toggleActive(p),
                                                  child: Chip(
                                                    label: Text(active ? 'Đang bán' : 'Ẩn / Tạm ngưng'),
                                                    avatar: Icon(
                                                      active ? Icons.visibility : Icons.visibility_off,
                                                      size: 18,
                                                      color: active ? Colors.green : Colors.grey,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        children: [
                                          IconButton(
                                            tooltip: 'Sửa',
                                            onPressed: () async {
                                              final id = (p['ProductID'] ?? p['Id'] ?? p['id']) as int;
                                              final ok = await Navigator.pushNamed(
                                                context,
                                                '/admin/products/edit',
                                                arguments: id, // <<< TRUYỀN ID
                                              );
                                              if (ok == true) _fetch();
                                            },
                                            icon: const Icon(Icons.edit_outlined),
                                          ),
                                          IconButton(
                                            tooltip: 'Xoá',
                                            onPressed: () => _delete(id),
                                            icon: const Icon(Icons.delete_outline),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        )),
            ),
          ),

          // ===== Pagination =====
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Text('Trang $_page / $maxPage  •  Tổng $_total',
                      style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Trang trước',
                    onPressed: canPrev ? () { setState(() => _page--); _fetch(); } : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    tooltip: 'Trang sau',
                    onPressed: canNext ? () { setState(() => _page++); _fetch(); } : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // format "12999000" -> "12.999.000đ" (không cần intl)
  String _vnd(String raw) {
    final digits = RegExp(r'\d+').stringMatch(raw) ?? '0';
    final s = digits.replaceAll(RegExp(r'^0+'), '');
    if (s.isEmpty) return '0đ';
    final buf = StringBuffer();
    int cnt = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buf.write(s[i]);
      cnt++;
      if (cnt == 3 && i != 0) {
        buf.write('.');
        cnt = 0;
      }
    }
    return '${buf.toString().split('').reversed.join()}đ';
  }
}

class _ChipValue extends StatelessWidget {
  final String label;
  final IconData icon;
  const _ChipValue({required this.label, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
