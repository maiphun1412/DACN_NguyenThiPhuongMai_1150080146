import 'package:flutter/material.dart';
import 'package:thietbidientu_fontend/models/warehouse.dart';
import 'package:thietbidientu_fontend/services/warehouse_service.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  bool _loading = true;
  String? _error;
  List<Warehouse> _warehouses = [];

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
  }

  Future<void> _loadWarehouses() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      final data = await WarehouseService.fetchAll();
      setState(() {
        _warehouses = data;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _showWarehouseForm({Warehouse? warehouse}) async {
    final isEdit = warehouse != null;

    final nameCtrl = TextEditingController(text: warehouse?.name ?? '');
    final addressCtrl = TextEditingController(text: warehouse?.address ?? '');
    final descCtrl = TextEditingController(text: warehouse?.description ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEdit ? 'Sửa kho' : 'Thêm kho'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên kho',
                  ),
                ),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Địa chỉ',
                  ),
                ),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú / mô tả',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng nhập tên kho')),
                  );
                  return;
                }

                try {
                  if (isEdit) {
                    final updated = Warehouse(
                      warehouseId: warehouse!.warehouseId,
                      name: nameCtrl.text.trim(),
                      address: addressCtrl.text.trim().isEmpty
                          ? null
                          : addressCtrl.text.trim(),
                      description: descCtrl.text.trim().isEmpty
                          ? null
                          : descCtrl.text.trim(),
                    );
                    await WarehouseService.update(updated);
                  } else {
                    await WarehouseService.create(
                      name: nameCtrl.text.trim(),
                      address: addressCtrl.text.trim().isEmpty
                          ? null
                          : addressCtrl.text.trim(),
                      description: descCtrl.text.trim().isEmpty
                          ? null
                          : descCtrl.text.trim(),
                    );
                  }

                  if (!mounted) return;
                  Navigator.pop(context, true);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi: $e')),
                  );
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      _loadWarehouses();
    }
  }

  Future<void> _confirmDelete(Warehouse w) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa kho'),
        content: Text('Bạn có chắc muốn xóa kho "${w.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await WarehouseService.delete(w.warehouseId);
        _loadWarehouses();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi xóa: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Quản lý kho")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _warehouses.isEmpty
                  ? const Center(child: Text('Chưa có kho nào'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _warehouses.length,
                      itemBuilder: (context, index) {
                        final w = _warehouses[index];
                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: Icon(
                              index == 0
                                  ? Icons.warehouse
                                  : Icons.store,
                              color: index == 0
                                  ? Colors.indigo
                                  : Colors.green,
                            ),
                            title: Text(
                              w.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              w.address ?? 'Chưa có địa chỉ',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.edit),
                                  onPressed: () =>
                                      _showWarehouseForm(warehouse: w),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _confirmDelete(w),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showWarehouseForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
