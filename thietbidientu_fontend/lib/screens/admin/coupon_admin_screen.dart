import 'package:flutter/material.dart';
import 'package:thietbidientu_fontend/models/coupon.dart';
import 'package:thietbidientu_fontend/services/coupon_service.dart';

class CouponAdminScreen extends StatefulWidget {
  const CouponAdminScreen({super.key});

  @override
  State<CouponAdminScreen> createState() => _CouponAdminScreenState();
}

class _CouponAdminScreenState extends State<CouponAdminScreen> {
  bool _loading = true;
  String? _error;
  List<Coupon> _coupons = [];

  @override
  void initState() {
    super.initState();
    _loadCoupons();
  }

  Future<void> _loadCoupons() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      final data = await CouponService.fetchAll();
      setState(() {
        _coupons = data;
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

  String _formatDate(DateTime? d) {
    if (d == null) return 'Không giới hạn';
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd/$mm/$yy';
  }

  Future<void> _showCouponForm({Coupon? coupon}) async {
    final isEdit = coupon != null;

    final codeCtrl = TextEditingController(text: coupon?.code ?? '');
    final nameCtrl = TextEditingController(text: coupon?.name ?? '');
    final valueCtrl = TextEditingController(
        text: coupon != null ? coupon.discountValue.toString() : '');
    final minOrderCtrl = TextEditingController(
        text: coupon?.minOrderTotal?.toString() ?? '');
    final maxDiscountCtrl = TextEditingController(
        text: coupon?.maxDiscount?.toString() ?? '');
    final endDateCtrl = TextEditingController(
      text: coupon?.endDate != null
          ? coupon!.endDate!.toIso8601String().split('T').first
          : '',
    );
    String discountType = coupon?.discountType ?? 'PERCENT';
    bool isActive = coupon?.isActive ?? true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEdit ? 'Sửa mã giảm giá' : 'Thêm mã giảm giá'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mã code',
                  ),
                ),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên hiển thị',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Loại giảm:'),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: discountType,
                      items: const [
                        DropdownMenuItem(
                          value: 'PERCENT',
                          child: Text('Phần trăm (%)'),
                        ),
                        DropdownMenuItem(
                          value: 'FIXED',
                          child: Text('Số tiền cố định'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          discountType = v;
                        });
                      },
                    ),
                  ],
                ),
                TextField(
                  controller: valueCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Giá trị giảm',
                    hintText: 'VD: 10 hoặc 50000',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                TextField(
                  controller: minOrderCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Đơn tối thiểu (đ optional)',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                TextField(
                  controller: maxDiscountCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Giảm tối đa (đ optional)',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                TextField(
                  controller: endDateCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ngày hết hạn (yyyy-MM-dd, để trống nếu không)',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Đang hoạt động'),
                    const Spacer(),
                    Switch(
                      value: isActive,
                      onChanged: (v) {
                        setState(() {
                          isActive = v;
                        });
                      },
                    ),
                  ],
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
                if (codeCtrl.text.trim().isEmpty ||
                    valueCtrl.text.trim().isEmpty) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Vui lòng nhập mã và giá trị giảm')),
                  );
                  return;
                }

                final value = double.tryParse(valueCtrl.text.trim()) ?? 0;
                final minOrder = minOrderCtrl.text.trim().isEmpty
                    ? null
                    : double.tryParse(minOrderCtrl.text.trim());
                final maxDiscount = maxDiscountCtrl.text.trim().isEmpty
                    ? null
                    : double.tryParse(maxDiscountCtrl.text.trim());
                DateTime? endDate;
                if (endDateCtrl.text.trim().isNotEmpty) {
                  try {
                    endDate = DateTime.parse(endDateCtrl.text.trim());
                  } catch (_) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Ngày hết hạn không hợp lệ')),
                    );
                    return;
                  }
                }

                try {
                  if (isEdit) {
                    final updated = Coupon(
                      couponId: coupon!.couponId,
                      code: codeCtrl.text.trim(),
                      name: nameCtrl.text.trim().isEmpty
                          ? null
                          : nameCtrl.text.trim(),
                      discountType: discountType,
                      discountValue: value,
                      minOrderTotal: minOrder,
                      maxDiscount: maxDiscount,
                      startDate: coupon.startDate,
                      endDate: endDate,
                      usageLimit: coupon.usageLimit,
                      perUserLimit: coupon.perUserLimit,
                      isActive: isActive,
                    );
                    await CouponService.update(updated);
                  } else {
                    await CouponService.create(
                      code: codeCtrl.text.trim(),
                      name: nameCtrl.text.trim().isEmpty
                          ? null
                          : nameCtrl.text.trim(),
                      discountType: discountType,
                      discountValue: value,
                      minOrderTotal: minOrder,
                      maxDiscount: maxDiscount,
                      endDate: endDate,
                      usageLimit: null,
                      perUserLimit: null,
                      isActive: isActive,
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
      _loadCoupons();
    }
  }

  Future<void> _confirmDelete(Coupon coupon) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa mã giảm giá'),
        content:
            Text('Bạn có chắc muốn xóa mã "${coupon.code}" khỏi hệ thống?'),
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
        await CouponService.delete(coupon.couponId);
        _loadCoupons();
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
      appBar: AppBar(title: const Text('Mã giảm giá')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _coupons.isEmpty
                  ? const Center(child: Text('Chưa có mã giảm giá nào'))
                  : ListView.builder(
                      itemCount: _coupons.length,
                      itemBuilder: (context, index) {
                        final c = _coupons[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          child: ListTile(
                            leading: Icon(
                              Icons.discount,
                              color: c.isActive
                                  ? Colors.green
                                  : Colors.grey.shade500,
                            ),
                            title: Text(
                              c.code,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${c.name ?? ''}\n'
                              'Loại: ${c.discountType} - Giá trị: ${c.discountValue}',
                            ),
                            isThreeLine: true,
trailing: SizedBox(
  width: 110, // cho đủ chỗ 2 icon
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(
        _formatDate(c.endDate),
        style: const TextStyle(fontSize: 11),
        textAlign: TextAlign.right,
      ),
      // <<< BỎ const SizedBox(height: 4) Ở ĐÂY
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            iconSize: 18,
            icon: const Icon(Icons.edit),
            onPressed: () => _showCouponForm(coupon: c),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            iconSize: 18,
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDelete(c),
          ),
        ],
      ),
    ],
  ),
),


                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCouponForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
