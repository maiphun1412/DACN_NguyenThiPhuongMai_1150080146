import 'dart:async';
import 'package:flutter/material.dart';
import 'package:thietbidientu_fontend/services/admin_category_service.dart';
import 'package:thietbidientu_fontend/services/category_service.dart';

class CategoryAdminScreen extends StatefulWidget {
  const CategoryAdminScreen({super.key});

  @override
  State<CategoryAdminScreen> createState() => _CategoryAdminScreenState();
}

class _Debouncer {
  final int ms;
  Timer? _t;
  _Debouncer([this.ms = 400]);
  void call(void Function() fn) { _t?.cancel(); _t = Timer(Duration(milliseconds: ms), fn); }
  void dispose() => _t?.cancel();
}

class _CategoryAdminScreenState extends State<CategoryAdminScreen> {
  final _searchCtrl = TextEditingController();
  final _deb = _Debouncer();

  bool _loading = false;
  int _page = 1;
  int _total = 0;
  int _pageSize = 20;
  String _q = '';

  List<Map<String, dynamic>> _items = [];
  Map<int, String> _catNameById = {}; // để hiện Parent name

  @override
  void initState() {
    super.initState();
    _prefetchNames();
    _fetch(reset: true);
  }

  Future<void> _prefetchNames() async {
    try {
      final list = await CategoryService.listSimple();
      _catNameById = { for (final c in list) c.id : c.name };
      if (mounted) setState((){});
    } catch (_) {}
  }

  Future<void> _fetch({bool reset = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      if (reset) _page = 1;
      final res = await AdminCategoryService.list(page: _page, q: _q);
      _total = (res['total'] ?? 0) as int;
      final list = (res['items'] ?? res['data'] ?? res['categories'] ?? []) as List;
      _items = list.map((e) => Map<String,dynamic>.from(e as Map)).toList();
      setState((){});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xoá danh mục?'),
        content: const Text('Thao tác này có thể là xoá mềm tuỳ BE.'),
        actions: [
          TextButton(onPressed: ()=>Navigator.pop(context,false), child: const Text('Huỷ')),
          FilledButton(onPressed: ()=>Navigator.pop(context,true), child: const Text('Xoá')),
        ],
      ),
    );
    if (ok != true) return;
    await AdminCategoryService.deleteSoft(id);
    _fetch(reset: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _deb.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxPage = _total == 0 ? 1 : ((_total - 1) ~/ _pageSize + 1);
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý danh mục')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await Navigator.pushNamed(context, '/admin/categories/new');
          if (ok == true) _fetch(reset: true);
        },
        icon: const Icon(Icons.add),
        label: const Text('Thêm'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Tìm theo tên…',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onChanged: (v) => _deb((){ _q = v.trim(); _fetch(reset: true); }),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<int>(
                  initialValue: _pageSize,
                  onSelected: (v) { setState(()=>_pageSize = v); _fetch(reset: true); },
                  itemBuilder: (_) => const [
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
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetch(reset: true),
              child: _loading && _items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : (_items.isEmpty
                    ? const Center(child: Text('Không có dữ liệu'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final m = _items[i];
                          final id = (m['CategoryID'] ?? m['id']) as int;
                          final name = (m['Name'] ?? m['name'] ?? '').toString();
                          final parentId = (m['ParentID'] ?? m['parentId']);
                          final parentStr = parentId == null ? '—' : _catNameById[parentId] ?? parentId.toString();

                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: ListTile(
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('ID: $id  •  Parent: $parentStr'),
                              onTap: () async {
                                final ok = await Navigator.pushNamed(
                                  context, '/admin/categories/edit',
                                  arguments: id,
                                );
                                if (ok == true) _fetch();
                              },
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Sửa',
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () async {
                                      final ok = await Navigator.pushNamed(
                                        context, '/admin/categories/edit',
                                        arguments: id,
                                      );
                                      if (ok == true) _fetch();
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Xoá',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _delete(id),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      )),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(children: [
                Text('Trang $_page / $maxPage  •  Tổng $_total',
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const Spacer(),
                IconButton(
                  onPressed: _page > 1 ? () { setState(()=>_page--); _fetch(); } : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  onPressed: _page < maxPage ? () { setState(()=>_page++); _fetch(); } : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
