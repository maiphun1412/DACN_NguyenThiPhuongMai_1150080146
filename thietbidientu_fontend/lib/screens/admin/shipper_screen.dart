// lib/screens/admin/shipper_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:thietbidientu_fontend/services/admin/shipper_service.dart';

class ShipperScreen extends StatefulWidget {
  const ShipperScreen({super.key});

  @override
  State<ShipperScreen> createState() => _ShipperScreenState();
}

class _ShipperScreenState extends State<ShipperScreen> {
  final _svc = ShipperService();
  final _searchCtrl = TextEditingController();

  bool _loading = false;
  int _page = 1;
  int _size = 20;
  int _total = 0;
  bool? _activeFilter; // null=Tất cả, true=Đang hoạt động, false=Ngưng hoạt động
  List<dynamic> _items = [];

  int _asInt(dynamic v, int fallback) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  @override
  void initState() {
    super.initState();
    // cập nhật suffixIcon theo text (UI-only)
    _searchCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({int? page}) async {
    setState(() => _loading = true);
    try {
      final m = await _svc.list(
        q: _searchCtrl.text.trim(),
        page: page ?? _page,
        size: _size,
        isActive: _activeFilter,
      );

      if (!mounted) return;

      final List<dynamic> items =
          (m['items'] as List?) ?? (m['data'] as List?) ?? <dynamic>[];

      setState(() {
        _page = _asInt(m['page'], 1);
        _size = _asInt(m['size'], 20);
        _total = _asInt(m['total'], items.length);
        _items = List<dynamic>.from(items);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi tải danh sách: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreate() async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const ShipperFormDialog(),
    );
    if (data != null) {
      await _svc.create(data);
      await _load();
    }
  }

  Future<void> _openEdit(Map<String, dynamic> item) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => ShipperFormDialog(initial: item),
    );
    if (data != null) {
      await _svc.update(item['ShipperID'] as int, data);
      await _load();
    }
  }

  Future<void> _toggle(Map<String, dynamic> item) async {
    await _svc.toggle(item['ShipperID'] as int);
    await _load();
  }

  Future<void> _remove(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xoá shipper?'),
        content: Text('Bạn có chắc muốn xoá "${item['Name']}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xoá')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _svc.remove(item['ShipperID'] as int);
        await _load();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không xoá được: $e')),
        );
      }
    }
  }

  Widget _statusChip(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: active ? Colors.green.withOpacity(.12) : Colors.grey.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: active ? Colors.green.shade300 : Colors.grey.shade300,
          width: .8,
        ),
      ),
      child: Text(
        active ? 'Đang hoạt động' : 'Ngưng hoạt động',
        style: TextStyle(
          fontSize: 11, // nhỏ hơn
          color: active ? Colors.green.shade700 : Colors.grey.shade700,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _vehicleEmoji(String v) {
    final s = (v).toLowerCase();
    if (s.contains('máy') || s.contains('may') || s.contains('motor') || s.contains('bike') || s.contains('scooter')) {
      return '🛵';
    }
    if (s.contains('ô tô') || s.contains('oto') || s.contains('car') || s.contains('xe hơi')) {
      return '🚗';
    }
    if (s.contains('tải') || s.contains('truck')) {
      return '🚚';
    }
    return '❓';
  }

  // Hiển thị 2 chữ cái đầu cho avatar
  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.take(2).toString().toUpperCase();
    return (parts.first.characters.take(1).toString() + parts.last.characters.take(1).toString()).toUpperCase();
  }

  Widget _shipperTile(Map<String, dynamic> it) {
    final name = (it['Name'] ?? '') as String;
    final phone = (it['Phone'] ?? '') as String;
    final plate = (it['LicensePlate'] ?? '') as String;
    final vehicle = (it['Vehicle'] ?? '') as String;
    final active = (it['IsActive'] as bool?) ?? false;

    // style nhỏ/mờ cho thông tin phụ
    const subStyle = TextStyle(fontSize: 12, color: Colors.black54);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        isThreeLine: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        leading: CircleAvatar(
          radius: 22,
          child: Text(
            name.trim().isNotEmpty ? _initials(name) : '?',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        // ====== TITLE: ƯU TIÊN TÊN – cho phép xuống 2-3 dòng, chip xuống hàng dưới ======
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name.isEmpty ? 'Chưa đặt tên' : name,
              maxLines: 3,               // cho phép hiển thị gần như full
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            const SizedBox(height: 4),
            _statusChip(active),         // đẩy chip xuống dưới để không tranh chấp chiều ngang
          ],
        ),
        // ====== SUBTITLE: thông tin phụ — nhỏ & 1 dòng ======
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (phone.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.phone, size: 13, color: Colors.black45),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          phone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: subStyle,
                        ),
                      ),
                    ],
                  ),
                ),
              if (plate.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.credit_card, size: 13, color: Colors.black45),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          plate,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: subStyle,
                        ),
                      ),
                    ],
                  ),
                ),
              if (vehicle.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.directions_car, size: 13, color: Colors.black45),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${_vehicleEmoji(vehicle)} $vehicle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: subStyle,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        trailing: Wrap(
          spacing: 0,
          children: [
            IconButton(
              tooltip: active ? 'Tạm ngưng' : 'Kích hoạt',
              icon: Icon(active ? Icons.visibility_off : Icons.visibility, size: 20),
              onPressed: () => _toggle(it),
            ),
            IconButton(
              tooltip: 'Sửa',
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _openEdit(it),
            ),
            IconButton(
              tooltip: 'Xoá',
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => _remove(it),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Tất cả'),
          selected: _activeFilter == null,
          onSelected: (_) {
            setState(() => _activeFilter = null);
            _load(page: 1);
          },
        ),
        ChoiceChip(
          label: const Text('Đang hoạt động'),
          selected: _activeFilter == true,
          onSelected: (_) {
            setState(() => _activeFilter = true);
            _load(page: 1);
          },
        ),
        ChoiceChip(
          label: const Text('Ngưng hoạt động'),
          selected: _activeFilter == false,
          onSelected: (_) {
            setState(() => _activeFilter = false);
            _load(page: 1);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPrev = _page > 1;
    final maxPage = ((_total + _size - 1) / _size).floor().clamp(1, 999999);
    final canNext = _page < maxPage;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Shipper'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _load()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('Thêm shipper'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Tìm theo tên / SĐT / biển số...',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: (_searchCtrl.text.isEmpty)
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchCtrl.clear();
                                _load(page: 1);
                              },
                            ),
                    ),
                    onSubmitted: (_) => _load(page: 1),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _load(page: 1),
                  icon: const Icon(Icons.tune),
                  label: const Text('Lọc'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Align(
                alignment: Alignment.centerLeft, child: _buildFilterChips()),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : (_items.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 120),
                          Center(child: Text('Không có dữ liệu')),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 96),
                          itemCount: _items.length,
                          itemBuilder: (_, i) =>
                              _shipperTile((_items[i] as Map).cast<String, dynamic>()),
                        )),
            ),
          ),
          if (_total > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$_total kết quả'),
                  Row(
                    children: [
                      IconButton(
                        onPressed: canPrev ? () => _load(page: _page - 1) : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text('Trang $_page/$maxPage'),
                      IconButton(
                        onPressed: canNext ? () => _load(page: _page + 1) : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  )
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/* ────────────────────────────────────────────────────────────────────────── */
/*                                   FORM                                     */
/* ────────────────────────────────────────────────────────────────────────── */

class ShipperFormDialog extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const ShipperFormDialog({super.key, this.initial});

  @override
  State<ShipperFormDialog> createState() => _ShipperFormDialogState();
}

class _ShipperFormDialogState extends State<ShipperFormDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  // dropdown + “khác”
  late final TextEditingController _vehicleOther;
  late final TextEditingController _plate;
  late final TextEditingController _note;
  bool _isActive = true;

  /// Các option chuẩn cho phương tiện
  static const List<String> _vehicleOptions = <String>['Xe máy', 'Ô tô', 'Xe tải', 'Khác'];
  String _vehicleChoice = 'Xe máy';

  String _normalizeVehicle(String s) {
    final t = s.toLowerCase().trim();
    if (t.isEmpty) return 'Xe máy';
    if (t.contains('máy') || t.contains('may') || t.contains('motor') || t.contains('bike') || t.contains('scooter')) {
      return 'Xe máy';
    }
    if (t.contains('ô tô') || t.contains('oto') || t.contains('car') || t.contains('xe hơi')) {
      return 'Ô tô';
    }
    if (t.contains('tải') || t.contains('truck')) {
      return 'Xe tải';
    }
    return 'Khác';
  }

  @override
  void initState() {
    super.initState();
    final m = widget.initial ?? {};
    _name = TextEditingController(text: m['Name'] ?? '');
    _phone = TextEditingController(text: m['Phone'] ?? '');
    _plate = TextEditingController(text: m['LicensePlate'] ?? '');
    _note = TextEditingController(text: m['Note'] ?? '');
    _vehicleOther = TextEditingController();

    final vRaw = (m['Vehicle'] ?? '').toString();
    final norm = _normalizeVehicle(vRaw);
    _vehicleChoice = norm;
    if (norm == 'Khác' && vRaw.isNotEmpty) {
      // giữ nguyên chuỗi cũ vào ô “khác”
      _vehicleOther.text = vRaw;
    }

    _isActive = (m['IsActive'] as bool?) ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _vehicleOther.dispose();
    _plate.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;

    final vehicle = (_vehicleChoice == 'Khác')
        ? _vehicleOther.text.trim()
        : _vehicleChoice;

    Navigator.pop<Map<String, dynamic>>(context, {
      'Name': _name.text.trim(),
      'Phone': _phone.text.trim(),
      'Vehicle': vehicle,
      'LicensePlate': _plate.text.trim(),
      'Note': _note.text.trim(),
      'IsActive': _isActive,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;

    InputDecoration deco(String label, {IconData? icon}) => InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon) : null,
          border: const OutlineInputBorder(),
          isDense: true,
        );

    String emojiFor(String v) {
      switch (v) {
        case 'Xe máy':
          return '🛵';
        case 'Ô tô':
          return '🚗';
        case 'Xe tải':
          return '🚚';
        default:
          return '❓';
      }
    }

    return AlertDialog(
      title: Text(isEdit ? 'Sửa shipper' : 'Thêm shipper'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: deco('Tên *', icon: Icons.person),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phone,
                  decoration: deco('Số điện thoại', icon: Icons.phone_iphone),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 8),

                // ▼▼ Dropdown phương tiện ▼▼
                DropdownButtonFormField<String>(
                  value: _vehicleChoice,
                  decoration: deco('Phương tiện', icon: Icons.two_wheeler),
                  items: _vehicleOptions.map((opt) {
                    return DropdownMenuItem<String>(
                      value: opt,
                      child: Row(
                        children: [
                          Text(emojiFor(opt), style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text(opt),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _vehicleChoice = v ?? 'Xe máy'),
                ),
                if (_vehicleChoice == 'Khác') ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _vehicleOther,
                    decoration: deco('Nhập loại phương tiện', icon: Icons.edit),
                    validator: (v) {
                      if (_vehicleChoice == 'Khác' && (v == null || v.trim().isEmpty)) {
                        return 'Vui lòng nhập phương tiện';
                      }
                      return null;
                    },
                  ),
                ],
                // ▲▲ Dropdown phương tiện ▲▲

                const SizedBox(height: 8),
                TextFormField(
                  controller: _plate,
                  decoration: deco('Biển số', icon: Icons.credit_card),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _note,
                  decoration: deco('Ghi chú', icon: Icons.notes),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  title: const Text('Kích hoạt'),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
        ElevatedButton(onPressed: _submit, child: const Text('Lưu')),
      ],
    );
  }
}
