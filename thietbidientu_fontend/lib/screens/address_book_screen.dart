// lib/screens/address_book_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/address.dart';
import '../services/address_service.dart';

class AddressBookScreen extends StatefulWidget {
  const AddressBookScreen({super.key});

  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  AddressService? api;
  Future<List<Address>>? _future;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  // Đọc token từ SharedPreferences và tạo service
  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');

    if (token == null || token.isEmpty) {
      setState(() {
        _future = Future.error(Exception('Chưa đăng nhập: không tìm thấy token'));
      });
      return;
    }

    api = AddressService(
      baseUrl: 'http://10.0.2.2:3000', // emulator Android
      token: token,
    );

    setState(() {
      _future = api!.listMine();
    });
  }

  Future<void> _reload() async {
    if (api == null) return;
    setState(() => _future = api!.listMine());
  }

  Future<void> _addDialog() async {
    if (api == null) return;

    final name = TextEditingController();
    final phone = TextEditingController();
    final line1 = TextEditingController();
    final ward = TextEditingController();
    final district = TextEditingController();
    final province = TextEditingController();
    bool isDefault = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Thêm địa chỉ'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Họ tên')),
              TextField(controller: phone, decoration: const InputDecoration(labelText: 'SĐT')),
              TextField(controller: line1, decoration: const InputDecoration(labelText: 'Địa chỉ')),
              TextField(controller: ward, decoration: const InputDecoration(labelText: 'Phường/Xã')),
              TextField(controller: district, decoration: const InputDecoration(labelText: 'Quận/Huyện')),
              TextField(controller: province, decoration: const InputDecoration(labelText: 'Tỉnh/TP')),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (ctx, setS) => CheckboxListTile(
                  value: isDefault,
                  onChanged: (v) => setS(() => isDefault = v ?? false),
                  title: const Text('Đặt làm mặc định'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Lưu')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await api!.create(
        fullName: name.text.trim(),
        phone: phone.text.trim(),
        line1: line1.text.trim(),
        ward: ward.text.trim().isEmpty ? null : ward.text.trim(),
        district: district.text.trim().isEmpty ? null : district.text.trim(),
        province: province.text.trim().isEmpty ? null : province.text.trim(),
        isDefault: isDefault,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thêm địa chỉ')));
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sổ địa chỉ')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Address>>(
          future: _future,
          builder: (context, snap) {
            if (_future == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Lỗi: ${snap.error}'));
            }
            final items = snap.data ?? [];
            if (items.isEmpty) {
              return const Center(child: Text('Chưa có địa chỉ'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final a = items[i];
                final subtitle = [
                  a.line1,
                  if ((a.ward ?? '').isNotEmpty) a.ward!,
                  if ((a.district ?? '').isNotEmpty) a.district!,
                  if ((a.province ?? '').isNotEmpty) a.province!,
                ].where((e) => e.isNotEmpty).join(', ');

                return ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tileColor: Colors.white,
                  leading: Icon(a.isDefault ? Icons.star : Icons.location_on_outlined),
                  title: Text('${a.fullName} • ${a.phone}'),
                  subtitle: Text(subtitle),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      try {
                        if (v == 'default') {
                          await api!.setDefault(a.addressId);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã đặt mặc định')));
                          _reload();
                        } else if (v == 'delete') {
                          await api!.remove(a.addressId);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa')));
                          _reload();
                        }
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
                      }
                    },
                    itemBuilder: (_) => [
                      if (!a.isDefault)
                        const PopupMenuItem(value: 'default', child: Text('Đặt làm mặc định')),
                      const PopupMenuItem(value: 'delete', child: Text('Xóa')),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDialog,
        label: const Text('Thêm'),
        icon: const Icon(Icons.add_location_alt),
      ),
    );
  }
}
