import 'package:flutter/material.dart';
import 'package:thietbidientu_fontend/services/admin_category_service.dart';
import 'package:thietbidientu_fontend/services/category_service.dart';

class CategoryEditScreen extends StatefulWidget {
  final int categoryId;
  const CategoryEditScreen({super.key, required this.categoryId});

  @override
  State<CategoryEditScreen> createState() => _CategoryEditScreenState();
}

class _CategoryEditScreenState extends State<CategoryEditScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  int? _parentId;
  bool _loading = false;

  List<CategoryItem> _cats = [];
  bool _loadingCats = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _loadCats();
  }

  Future<void> _loadCats() async {
    try {
      setState(()=>_loadingCats = true);
      _cats = await CategoryService.listSimple();
      setState((){});
    } catch (e) {
      _toast('Lỗi tải danh mục cha: $e');
    } finally {
      if (mounted) setState(()=>_loadingCats = false);
    }
  }

  Future<void> _loadDetail() async {
    try {
      setState(()=>_loading = true);
      final res = await AdminCategoryService.detail(widget.categoryId);
      final dAny = res['data'] ?? res['item'] ?? res['category'] ?? res;
      final d = Map<String,dynamic>.from(dAny as Map);
      _name.text = (d['Name'] ?? d['name'] ?? '').toString();
      _parentId = (d['ParentID'] ?? d['parentId']) as int?;
      setState((){});
    } catch (e) {
      _toast('Lỗi tải chi tiết: $e');
    } finally { if (mounted) setState(()=>_loading = false); }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    try {
      setState(()=>_loading = true);
      final body = <String, dynamic>{
        'Name': _name.text.trim(),
        'ParentID': _parentId,
      }..removeWhere((k,v)=>v==null);

      await AdminCategoryService.update(widget.categoryId, body);
      _toast('Đã lưu thay đổi');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _toast('Lỗi cập nhật: $e');
    } finally {
      if (mounted) setState(()=>_loading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sửa danh mục'),
        actions: [ IconButton(onPressed: _loading?null:_save, icon: const Icon(Icons.save)) ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _form,
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Tên *', border: OutlineInputBorder()),
                    validator: (v)=> v==null || v.trim().isEmpty ? 'Bắt buộc' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _parentId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Danh mục cha (tuỳ chọn)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('— Không chọn —'),
                      ),
                      ..._cats.map((c)=>DropdownMenuItem<int>(
                        value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis),
                      )),
                    ],
                    onChanged: _loadingCats ? null : (v)=> setState(()=> _parentId = v),
                  ),
                ],
              ),
            ),
          ),
          if (_loading) const Align(alignment: Alignment.topCenter, child: LinearProgressIndicator(minHeight: 3)),
        ],
      ),
    );
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}
