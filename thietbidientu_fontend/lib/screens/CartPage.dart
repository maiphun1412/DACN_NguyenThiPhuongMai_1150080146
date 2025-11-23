// lib/screens/CartPage.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:thietbidientu_fontend/models/cart_item.dart';
import 'package:thietbidientu_fontend/services/cart_service.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final _svc = CartService();

  bool _loading = true;
  String? _error;
  List<CartItem> _items = [];
  String _token = '';

  // chống double-tap theo từng sản phẩm
  final Set<String> _busy = {};

  // lựa chọn để mua: dùng cartItemId
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_loadCart);
  }

  Future<void> _loadCart() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('token') ??
          prefs.getString('accessToken') ??
          prefs.getString('jwt') ??
          '';

      // ignore: avoid_print
      print('[CART] token=${_token.isEmpty ? "<EMPTY>" : _token.substring(0, 12) + "..."}');

      if (_token.isEmpty) {
        if (!mounted) return;
        setState(() {
          _items = [];
          _selectedIds.clear();
          _error = 'Bạn chưa đăng nhập';
          _loading = false;
        });
        return;
      }

      final items = await _svc.getCart(token: _token);

      // auto-select tất cả sau mỗi lần load (có thể đổi)
      _selectedIds
        ..clear()
        ..addAll(items.map((e) => e.cartItemId));

      // ignore: avoid_print
      print('[CART] items.length=${items.length}');

      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
        _items = [];
        _selectedIds.clear();
      });
      // ignore: avoid_print
      print('[CART][ERROR] $e');
    }
  }

  // helper: parse id chuỗi -> int
  int? _pid(String id) => int.tryParse(id);

  Future<void> _incQty(CartItem it) async {
    final pid = _pid(it.product.id);
    if (pid == null) return _toast('ID sản phẩm không hợp lệ');
    if (_busy.contains(it.product.id)) return;
    _busy.add(it.product.id);
    try {
      await _svc.updateQuantity(
        token: _token,
        productId: pid,
        optionId: it.optionId, // ✅ gửi optionId
        quantity: it.quantity + 1,
      );
      await _loadCart();
    } catch (e) {
      _toast('Không thể tăng số lượng: $e');
    } finally {
      _busy.remove(it.product.id);
    }
  }

  Future<void> _decQty(CartItem it) async {
    final pid = _pid(it.product.id);
    if (pid == null) return _toast('ID sản phẩm không hợp lệ');
    if (_busy.contains(it.product.id)) return;
    _busy.add(it.product.id);
    try {
      final newQty = it.quantity - 1;
      if (newQty <= 0) {
        await _svc.removeFromCart(
          token: _token,
          productId: pid,
          optionId: it.optionId, // ✅ gửi optionId
        );
      } else {
        await _svc.updateQuantity(
          token: _token,
          productId: pid,
          optionId: it.optionId, // ✅ gửi optionId
          quantity: newQty,
        );
      }
      await _loadCart();
    } catch (e) {
      _toast('Không thể giảm số lượng: $e');
    } finally {
      _busy.remove(it.product.id);
    }
  }

  Future<void> _remove(CartItem it) async {
    final pid = _pid(it.product.id);
    if (pid == null) return _toast('ID sản phẩm không hợp lệ');
    if (_busy.contains(it.product.id)) return;
    _busy.add(it.product.id);
    try {
      await _svc.removeFromCart(
        token: _token,
        productId: pid,
        optionId: it.optionId, // ✅ gửi optionId
      );
      await _loadCart();
    } catch (e) {
      _toast('Không thể xoá sản phẩm: $e');
    } finally {
      _busy.remove(it.product.id);
    }
  }

  Future<void> _clear() async {
    try {
      await _svc.clearCart(token: _token);
      await _loadCart();
    } catch (e) {
      _toast('Không thể xoá giỏ hàng: $e');
    }
  }

  String _formatVND(num v) =>
      intl.NumberFormat.currency(locale: 'vi_VN', symbol: '', decimalDigits: 0)
          .format(v)
          .trim();

  // Tổng tiền chỉ tính các món đang chọn
  double get _totalPrice => _items
      .where((it) => _selectedIds.contains(it.cartItemId))
      .fold<double>(0, (s, it) => s + it.totalPrice);

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final hasAnySelected = _selectedIds.isNotEmpty;
    final showBottom = _error == null && !_loading && _items.isNotEmpty;

    // ignore: avoid_print
    print('[CART][UI] loading=$_loading error=$_error items=${_items.length} selected=${_selectedIds.length}');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Giỏ hàng'),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              tooltip: 'Xoá giỏ',
              onPressed: _clear,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadCart,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorView(message: _error!, onRetry: _loadCart)
                : _items.isEmpty
                    ? const _EmptyView()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          _CouponCard(onTap: () {
                            _toast('Tính năng mã giảm giá sẽ bổ sung sau');
                          }),
                          const SizedBox(height: 16),
                          // Chọn/bỏ chọn tất cả
                          Row(
                            children: [
                              Checkbox(
                                value: hasAnySelected && _selectedIds.length == _items.length,
                                tristate: false,
                                onChanged: (_) {
                                  setState(() {
                                    if (_selectedIds.length == _items.length) {
                                      _selectedIds.clear();
                                    } else {
                                      _selectedIds
                                        ..clear()
                                        ..addAll(_items.map((e) => e.cartItemId));
                                    }
                                  });
                                },
                              ),
                              const SizedBox(width: 4),
                              const Text('Chọn tất cả', style: TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ..._items.map((it) => _CartItemTile(
                                item: it,
                                selected: _selectedIds.contains(it.cartItemId),
                                onToggleSelected: () {
                                  setState(() {
                                    if (_selectedIds.contains(it.cartItemId)) {
                                      _selectedIds.remove(it.cartItemId);
                                    } else {
                                      _selectedIds.add(it.cartItemId);
                                    }
                                  });
                                },
                                priceText: _formatVND(it.product.price),
                                onInc: () => _incQty(it),
                                onDec: () => _decQty(it),
                                onRemove: () => _remove(it),
                              )),
                        ],
                      ),
      ),
      bottomNavigationBar: showBottom
          ? _BottomBar(
              total: _formatVND(_totalPrice),
              enabled: hasAnySelected, // chỉ bật nếu có chọn
              onCheckout: hasAnySelected
                  ? () {
                      final itemsArg = _items
                          .where((it) => _selectedIds.contains(it.cartItemId))
                          .map((it) => {
                                'productId': int.tryParse(it.product.id) ?? it.product.id,
                                'quantity': it.quantity,
                                // nếu sau này cần optionId để checkout theo biến thể:
                                if (it.optionId != null) 'optionId': it.optionId,
                              })
                          .toList();

                      Navigator.pushNamed(
                        context,
                        '/checkout',
                        arguments: {
                          'subtotal': _totalPrice.round(),
                          'items': itemsArg,
                        },
                      );
                    }
                  : null,
            )
          : null,
    );
  }
}

class _CouponCard extends StatelessWidget {
  final VoidCallback onTap;
  const _CouponCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(.06),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: const [
            CircleAvatar(radius: 16, child: Icon(Icons.percent)),
            SizedBox(width: 12),
            Text('Thêm mã giảm giá', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final String priceText;
  final bool selected;
  final VoidCallback onToggleSelected;
  final VoidCallback onInc;
  final VoidCallback onDec;
  final VoidCallback onRemove;

  const _CartItemTile({
    required this.item,
    required this.priceText,
    required this.selected,
    required this.onToggleSelected,
    required this.onInc,
    required this.onDec,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(value: selected, onChanged: (_) => onToggleSelected()),
            _ProductImage(url: item.product.imageUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    if (item.variant.color?.isNotEmpty == true || item.variant.size?.isNotEmpty == true)
                      Text(
                        [
                          if (item.variant.color?.isNotEmpty == true) item.variant.color!,
                          if (item.variant.size?.isNotEmpty == true) item.variant.size!,
                        ].join(' / '),
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      '$priceText đ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _QtyButton(icon: Icons.remove, onPressed: onDec),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        _QtyButton(icon: Icons.add, onPressed: onInc),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Xoá',
                          onPressed: onRemove,
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String? url;
  const _ProductImage({required this.url});

  @override
  Widget build(BuildContext context) {
    final u = (url ?? '').trim();

    final placeholder = Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.black12.withOpacity(.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.image_not_supported_outlined),
    );

    if (u.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        u,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (c, w, p) =>
            p == null ? w : const SizedBox(width: 72, height: 72, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _QtyButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final String total;
  final VoidCallback? onCheckout;
  final bool enabled;
  const _BottomBar({required this.total, required this.onCheckout, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 16),
      decoration: const BoxDecoration(boxShadow: [
        BoxShadow(color: Colors.black12, offset: Offset(0, -1), blurRadius: 6)
      ], color: Colors.white),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Tổng:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text('$total đ', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            SizedBox(
              width: 160,
              child: ElevatedButton(
                onPressed: enabled ? onCheckout : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Thanh toán'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: const [
        SizedBox(height: 40),
        Icon(Icons.remove_shopping_cart_outlined, size: 64),
        SizedBox(height: 12),
        Center(child: Text('Giỏ hàng trống', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
        SizedBox(height: 6),
        Center(child: Text('Hãy thêm vài món bạn thích nhé!')),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.error_outline, size: 64),
        const SizedBox(height: 12),
        const Center(child: Text('Đã có lỗi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 16),
        Center(child: OutlinedButton(onPressed: onRetry, child: const Text('Thử lại'))),
      ],
    );
  }
}
