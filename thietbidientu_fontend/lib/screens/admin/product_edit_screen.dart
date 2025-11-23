import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:thietbidientu_fontend/services/admin/admin_product_service.dart';
import 'package:thietbidientu_fontend/config.dart';
import 'package:http/http.dart' as http;           // tải ảnh từ URL
import 'package:path_provider/path_provider.dart';

class ProductEditScreen extends StatefulWidget {
  final int productId;
  const ProductEditScreen({super.key, required this.productId});

  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // ----- form -----
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

  // ----- tab -----
  late final TabController _tab;

  // ----- ảnh -----
  final _picker = ImagePicker();
  final List<_ExistImage> _existImages = [];
  final List<File> _newImages = [];
  int? _newMainIndex;

  // ô dán URL ảnh mới
  final _imgUrlCtrl = TextEditingController();

  // ----- options -----
  final List<_OptionRow> _options = [];

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this)..addListener(() => setState(() {}));
    _loadDetail(); // <<< NẠP DỮ LIỆU Ở ĐÂY
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

  // ===== LOAD DETAIL (đổ sẵn dữ liệu) =====
  Future<void> _loadDetail() async {
    try {
      setState(() => _loading = true);
      final res = await AdminProductService.detail(widget.productId);
      final dAny = res['data'] ?? res['item'] ?? res['product'] ?? res;
      final d = Map<String, dynamic>.from(dAny as Map);

      String s(String a, [String? b]) =>
          (d[a] ?? (b != null ? d[b] : null) ?? '').toString();

      _name.text = s('Name', 'name');
      _slug.text = s('Slug', 'slug');
      _categoryId.text = s('CategoryID', 'categoryId');
      _supplierId.text = s('SupplierID', 'supplierId');
      _price.text = s('Price', 'price');
      _stock.text = s('Stock', 'stock');
      _size.text = s('Size', 'size');
      _color.text = s('Color', 'color');
      _desc.text = s('Description', 'description');

      final activeAny = d['IsActive'] ?? d['isActive'];
      _isActive = activeAny == true ||
          activeAny == 1 ||
          activeAny?.toString().toLowerCase() == 'true';

      // ảnh hiện có
      final imgsAny = d['ProductImages'] ?? d['Images'] ?? d['images'] ?? [];
      final imgs = (imgsAny as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _existImages
        ..clear()
        ..addAll(imgs.map((m) {
          final raw = (m['Url'] ?? m['url'] ?? '').toString();
          final url = raw.startsWith('http') ? raw : '${AppConfig.baseUrl}$raw';
          return _ExistImage(
            id: m['ImageID'] ?? m['imageId'] ?? m['Id'] ?? m['id'],
            url: url,
            isMain: (m['IsMain'] ?? m['isMain'] ?? false) == true,
          );
        }));

      // options hiện có
      final optsAny = d['ProductOptions'] ?? d['Options'] ?? d['options'] ?? [];
      final opts = (optsAny as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _options
        ..clear()
        ..addAll(opts.map((m) => _OptionRow(
              id: m['OptionID'] ?? m['optionId'] ?? m['Id'] ?? m['id'],
              size: (m['Size'] ?? '').toString(),
              color: (m['Color'] ?? '').toString(),
              stock: int.tryParse((m['Stock'] ?? '0').toString()) ?? 0,
              isNew: false,
            )));

      setState(() {});
    } catch (e) {
      _toast('Lỗi tải chi tiết: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ===== SAVE (update) =====
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      setState(() => _loading = true);

      final fields = <String, dynamic>{
        'Name': _name.text.trim(),
        'Slug': _slug.text.trim(),
        'CategoryID': int.tryParse(_categoryId.text.trim()),
        'SupplierID': int.tryParse(_supplierId.text.trim()),
        'Price': num.tryParse(_price.text.trim()),
        'Stock': int.tryParse(_stock.text.trim()),
        'Size': _size.text.trim().isEmpty ? null : _size.text.trim(),
        'Color': _color.text.trim().isEmpty ? null : _color.text.trim(),
        'Description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
        'IsActive': _isActive,
      }..removeWhere((k, v) => v == null);

      if (_newImages.isNotEmpty) {
        await AdminProductService.updateWithImages(
          id: widget.productId,
          fields: fields.map((k, v) => MapEntry(k, v.toString())),
          files: _newImages,
          mainIndex: _newMainIndex,
        );
      } else {
        await AdminProductService.update(widget.productId, fields);
      }

      // options
      for (final o in _options) {
        if (o.isDeleted && o.id != null) {
          await AdminProductService.deleteOption(o.id!);
        } else if (o.isNew) {
          await AdminProductService.addOption(
            widget.productId,
            size: o.size.isEmpty ? null : o.size,
            color: o.color.isEmpty ? null : o.color,
            stock: o.stock,
          );
        } else if (o.isDirty && o.id != null) {
          await AdminProductService.updateOption(
            o.id!,
            size: o.size.isEmpty ? null : o.size,
            color: o.color.isEmpty ? null : o.color,
            stock: o.stock,
          );
        }
      }

      _toast('Đã lưu thay đổi');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _toast('Lỗi cập nhật: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ===== ẢNH: hiện có =====
  Future<void> _setMainExist(_ExistImage img) async {
    try {
      setState(() => _loading = true);
      await AdminProductService.setMainImage(widget.productId, img.id!);
      for (final i in _existImages) {
        i.isMain = i == img;
      }
      setState(() {});
      _toast('Đã đặt ảnh đại diện');
    } catch (e) {
      _toast('Lỗi đặt ảnh đại diện: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteExistImage(_ExistImage img) async {
    try {
      setState(() => _loading = true);
      await AdminProductService.deleteImage(img.id!);
      _existImages.remove(img);
      setState(() {});
      _toast('Đã xoá ảnh');
    } catch (e) {
      _toast('Lỗi xoá ảnh: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ===== ẢNH: mới =====
  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    setState(() {
      _newImages.addAll(picked.map((x) => File(x.path)));
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

  // ===== OPTIONS =====
  void _addOptionRow() {
    setState(() {
      _options
          .add(_OptionRow(id: null, size: '', color: '', stock: 0, isNew: true));
    });
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sửa sản phẩm'),
        bottom: TabBar(
  controller: _tab,
  tabs: const [
    Tab(text: 'Thông tin'),
    Tab(text: 'Ảnh'),
    Tab(text: 'Biến thể'),
  ],
  labelColor: Colors.white,          // chữ tab đang chọn = trắng
  unselectedLabelColor: Colors.white70, // chữ tab chưa chọn = trắng mờ
  indicatorColor: Colors.white,      // gạch dưới = trắng
),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _loading ? null : _save),
        ],
      ),
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
                child: LinearProgressIndicator(minHeight: 3)),
        ],
      ),
      floatingActionButton: _tab.index == 2
          ? FloatingActionButton(onPressed: _addOptionRow, child: const Icon(Icons.add))
          : null,
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
          _t(_slug, 'Slug'),
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
        if (_existImages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child:
                Text('Ảnh hiện có', style: Theme.of(context).textTheme.titleMedium),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _existImages.map((img) {
            return _ExistImageTile(
              url: img.url,
              isMain: img.isMain,
              onSetMain: () => _setMainExist(img),
              onDelete: () => _deleteExistImage(img),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),

        // --- Chọn ảnh từ máy ---
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Chọn ảnh mới'),
            ),
            const SizedBox(width: 12),
            if (_newImages.isNotEmpty) Text('Đã chọn: ${_newImages.length} ảnh'),
          ],
        ),

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
            ElevatedButton(onPressed: _addImageFromUrl, child: const Text('Thêm từ URL')),
          ],
        ),

        const SizedBox(height: 12),
        if (_newImages.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_newImages.length, (i) {
              return _NewImageTile(
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
      itemCount: _options.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final o = _options[i];
        if (o.isDeleted) return const SizedBox.shrink();
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
                onChanged: (v) => o..size = v..isDirty = true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: o.color,
                decoration: const InputDecoration(labelText: 'Color'),
                onChanged: (v) => o..color = v..isDirty = true,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 90,
              child: TextFormField(
                initialValue: o.stock.toString(),
                decoration: const InputDecoration(labelText: 'Stock'),
                keyboardType: TextInputType.number,
                onChanged: (v) =>
                    o..stock = int.tryParse(v.trim()) ?? 0..isDirty = true,
              ),
            ),
            IconButton(
              onPressed: () => setState(() => o.isDeleted = true),
              icon: const Icon(Icons.delete_outline),
            ),
          ]),
        );
      },
    );
  }

  // helpers
  Widget _t(TextEditingController c, String label,
      {bool required = false, bool number = false}) {
    return TextFormField(
      controller: c,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: const InputDecoration(border: OutlineInputBorder())
          .copyWith(labelText: label),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null
          : null,
    );
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}

// models phụ + tiles ảnh
class _ExistImage {
  final int? id;
  final String url;
  bool isMain;
  _ExistImage({required this.id, required this.url, required this.isMain});
}

class _OptionRow {
  int? id;
  String size;
  String color;
  int stock;
  bool isNew;
  bool isDirty = false;
  bool isDeleted = false;
  _OptionRow(
      {this.id,
      required this.size,
      required this.color,
      required this.stock,
      required this.isNew});
}

class _ExistImageTile extends StatelessWidget {
  final String url;
  final bool isMain;
  final VoidCallback onSetMain;
  final VoidCallback onDelete;
  const _ExistImageTile(
      {super.key,
      required this.url,
      required this.isMain,
      required this.onSetMain,
      required this.onDelete});
  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(url, width: 110, height: 110, fit: BoxFit.cover)),
      Positioned(
          right: 0,
          top: 0,
          child: Row(children: [
            IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onSetMain,
                icon: Icon(isMain ? Icons.star : Icons.star_border)),
            IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
                icon: const Icon(Icons.close)),
          ])),
    ]);
  }
}

class _NewImageTile extends StatelessWidget {
  final File file;
  final bool isMain;
  final VoidCallback onSetMain;
  final VoidCallback onDelete;
  const _NewImageTile(
      {super.key,
      required this.file,
      required this.isMain,
      required this.onSetMain,
      required this.onDelete});
  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(file, width: 110, height: 110, fit: BoxFit.cover)),
      Positioned(
          right: 0,
          top: 0,
          child: Row(children: [
            IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onSetMain,
                icon: Icon(isMain ? Icons.star : Icons.star_border)),
            IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
                icon: const Icon(Icons.close)),
          ])),
    ]);
  }
}
