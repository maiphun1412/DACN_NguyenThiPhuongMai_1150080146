import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:thietbidientu_fontend/services/admin/admin_product_service.dart';
import 'package:http/http.dart' as http;           // tải ảnh từ URL
import 'package:path_provider/path_provider.dart'; // lấy thư mục tạm

class ProductCreateScreen extends StatefulWidget {
  const ProductCreateScreen({Key? key}) : super(key: key);

  @override
  State<ProductCreateScreen> createState() => _ProductCreateScreenState();
}

class _ProductCreateScreenState extends State<ProductCreateScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TabController _tab;

  // ---- Thông tin chính
  final _name = TextEditingController();
  final _slug = TextEditingController();
  final _categoryId = TextEditingController();
  final _supplierId = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController();
  final _size = TextEditingController();
  final _color = TextEditingController();
  final _desc = TextEditingController();
  bool _isActive = true;

  // ---- Ảnh
  final _picker = ImagePicker();
  final List<File> _newImages = [];
  int? _newMainIndex;
  final _imgUrlCtrl = TextEditingController(); // ô dán URL

  // ---- Biến thể
  final List<_OptionRow> _options = [];

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this)..addListener(() => setState(() {}));

    _name.addListener(() {
      if (_slug.text.trim().isEmpty) {
        _slug.text = _slugify(_name.text);
        _slug.selection = TextSelection.collapsed(offset: _slug.text.length);
      }
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _name.dispose();
    _slug.dispose();
    _categoryId.dispose();
    _supplierId.dispose();
    _price.dispose();
    _stock.dispose();
    _size.dispose();
    _color.dispose();
    _desc.dispose();
    _imgUrlCtrl.dispose();
    super.dispose();
  }

  // ===== SAVE (create)
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      setState(() => _loading = true);

      // Chuẩn hoá slug để tránh lỗi BE (trùng/format)
      final rawSlug = _slug.text.trim();
      final safeSlug = rawSlug.isEmpty ? _slugify(_name.text) : _slugify(rawSlug);

      // Parse ID; để null nếu không hợp lệ
      final catId = int.tryParse(_categoryId.text.trim());
      final supId = int.tryParse(_supplierId.text.trim());

      final fields = <String, dynamic>{
        'Name': _name.text.trim(),
        'Slug': safeSlug,
        'CategoryID': catId,
        'SupplierID': supId,
        'Price': num.tryParse(_price.text.trim()),
        'Stock': int.tryParse(_stock.text.trim()),
        'Size': _size.text.trim().isEmpty ? null : _size.text.trim(),
        'Color': _color.text.trim().isEmpty ? null : _color.text.trim(),
        'Description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        'IsActive': _isActive,
      }..removeWhere((k, v) => v == null);

      Map<String, dynamic> res;
      if (_newImages.isNotEmpty) {
        res = await AdminProductService.createWithImages(
          fields: fields.map((k, v) => MapEntry(k, v.toString())),
          files: _newImages,
          mainIndex: _newMainIndex,
        );
      } else {
        res = await AdminProductService.create(fields);
      }

      final d = (res['data'] ?? res) as Map<String, dynamic>;
      final productId =
          (d['id'] ?? d['Id'] ?? d['productId'] ?? d['ProductID']) as int;

      // add options mới (nếu có)
      for (final o in _options) {
        await AdminProductService.addOption(
          productId,
          size: o.size.isEmpty ? null : o.size,
          color: o.color.isEmpty ? null : o.color,
          stock: o.stock,
        );
      }

      _toast('Đã tạo sản phẩm');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _toast('Lỗi tạo: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ===== Ảnh
  Future<void> _pickImages() async {
    final list = await _picker.pickMultiImage(imageQuality: 85);
    if (list.isEmpty) return;
    setState(() {
      _newImages.addAll(list.map((x) => File(x.path)));
      _newMainIndex ??= 0;
    });
  }

  // Thêm ảnh từ URL (dán link)
  Future<void> _addImageFromUrl() async {
    final url = _imgUrlCtrl.text.trim();
    if (url.isEmpty) {
      _toast('Vui lòng dán URL ảnh (http/https)');
      return;
    }
    try {
      setState(() => _loading = true);
      final u = Uri.tryParse(url);
      if (u == null || !(u.isScheme('http') || u.isScheme('https'))) {
        throw Exception('URL không hợp lệ');
      }

      final res = await http.get(u);
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) {
        throw Exception('Không tải được ảnh từ URL');
      }

      String _extFrom(String url, String? ct) {
        final l = url.toLowerCase();
        if (l.endsWith('.png')) return 'png';
        if (l.endsWith('.webp')) return 'webp';
        if (l.endsWith('.gif')) return 'gif';
        if ((ct ?? '').contains('png')) return 'png';
        if ((ct ?? '').contains('webp')) return 'webp';
        if ((ct ?? '').contains('gif')) return 'gif';
        return 'jpg';
      }

      final dir = await getTemporaryDirectory();
      final ext = _extFrom(url, res.headers['content-type']);
      final path =
          '${dir.path}/img_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final f = File(path);
      await f.writeAsBytes(res.bodyBytes);

      setState(() {
        _newImages.add(f);
        _newMainIndex ??= 0;
        _imgUrlCtrl.clear();
      });
      _toast('Đã thêm ảnh từ URL');
    } catch (e) {
      _toast('Lỗi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ===== UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm sản phẩm'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Thông tin'),
            Tab(text: 'Ảnh'),
            Tab(text: 'Biến thể'),
          ],
          // chữ trắng như yêu cầu
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
        actions: [
          IconButton(onPressed: _loading ? null : _save, icon: const Icon(Icons.save))
        ],
      ),
      floatingActionButton: _tab.index == 2
          ? FloatingActionButton(
              onPressed: () => setState(() => _options.add(_OptionRow())),
              child: const Icon(Icons.add),
              tooltip: 'Thêm biến thể',
            )
          : null,
      body: Stack(
        children: [
          TabBarView(
            controller: _tab,
            children: [
              _buildInfoTab(),
              _buildImagesTab(),
              _buildOptionsTab(),
            ],
          ),
          if (_loading)
            const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(minHeight: 3),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(children: [
          _t(_name, 'Tên *', required: true),
          const SizedBox(height: 12),
          _t(_slug, 'Slug', hint: 'vd: iphone-17'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _t(_categoryId, 'CategoryID', number: true)),
            const SizedBox(width: 12),
            Expanded(child: _t(_supplierId, 'SupplierID', number: true)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _t(_price, 'Giá *', number: true, required: true)),
            const SizedBox(width: 12),
            Expanded(child: _t(_stock, 'Tồn *', number: true, required: true)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _t(_size, 'Size')),
            const SizedBox(width: 12),
            Expanded(child: _t(_color, 'Color')),
          ]),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Kích hoạt (IsActive)'),
            value: _isActive,
            onChanged: (v) => setState(() => _isActive = v),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _desc,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Mô tả',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 80),
        ]),
      ),
    );
  }

  Widget _buildImagesTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // --- Chọn ảnh từ máy ---
        Row(children: [
          ElevatedButton.icon(
            onPressed: _pickImages,
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('Chọn ảnh'),
          ),
        ]),
        if (_newImages.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Đã chọn: ${_newImages.length} ảnh'),
        ],

        // --- Dán URL ảnh để thêm ---
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _imgUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Dán URL ảnh (http/https)',
                  hintText: 'https://.../image.jpg',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _addImageFromUrl,
              child: const Text('Thêm từ URL'),
            ),
          ],
        ),

        const SizedBox(height: 12),
        if (_newImages.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_newImages.length, (i) {
              return _ImageTile(
                file: _newImages[i],
                isMain: _newMainIndex == i,
                onSetMain: () => setState(() => _newMainIndex = i),
                onDelete: () => setState(() {
                  _newImages.removeAt(i);
                  if (_newMainIndex == i) {
                    _newMainIndex = _newImages.isEmpty ? null : 0;
                  }
                }),
              );
            }),
          ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildOptionsTab() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      itemBuilder: (_, i) {
        final o = _options[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Expanded(
              child: TextFormField(
                initialValue: o.size,
                decoration: const InputDecoration(labelText: 'Size'),
                onChanged: (v) => o.size = v,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: o.color,
                decoration: const InputDecoration(labelText: 'Color'),
                onChanged: (v) => o.color = v,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 90,
              child: TextFormField(
                initialValue: o.stock.toString(),
                decoration: const InputDecoration(labelText: 'Stock'),
                keyboardType: TextInputType.number,
                onChanged: (v) => o.stock = int.tryParse(v.trim()) ?? 0,
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _options.removeAt(i)),
              icon: const Icon(Icons.delete_outline),
            )
          ]),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: _options.length,
    );
  }

  // Helpers
  Widget _t(TextEditingController c, String label,
      {bool required = false, bool number = false, String? hint}) {
    return TextFormField(
      controller: c,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
          labelText: label, hintText: hint, border: const OutlineInputBorder()),
      validator:
          required ? (v) => (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null : null,
    );
  }

  String _slugify(String s) => s
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r"[^\w\s-]"), "")
      .replaceAll(RegExp(r"\s+"), "-")
      .replaceAll(RegExp(r"-+"), "-");

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}

class _OptionRow {
  String size = '';
  String color = '';
  int stock = 0;
}

class _ImageTile extends StatelessWidget {
  final File file;
  final bool isMain;
  final VoidCallback onSetMain;
  final VoidCallback onDelete;
  const _ImageTile({
    super.key,
    required this.file,
    required this.isMain,
    required this.onSetMain,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(file, width: 110, height: 110, fit: BoxFit.cover),
      ),
      Positioned(
        right: 0,
        top: 0,
        child: Row(children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onSetMain,
            icon: Icon(isMain ? Icons.star : Icons.star_border),
            tooltip: 'Đặt làm ảnh đại diện',
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onDelete,
            icon: const Icon(Icons.close),
            tooltip: 'Xóa',
          ),
        ]),
      ),
    ]);
  }
}
