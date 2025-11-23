import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:thietbidientu_fontend/config.dart';
import 'package:thietbidientu_fontend/models/product.dart';
import 'package:thietbidientu_fontend/models/product_option.dart';
import 'package:thietbidientu_fontend/services/api_service.dart';
import 'package:thietbidientu_fontend/services/cart_service.dart';
import 'package:thietbidientu_fontend/widgets/ItemAppBar.dart';
import 'package:thietbidientu_fontend/widgets/ItemBottomNavBar.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;

const _brand = Color(0xFF353839);
const _text = Color(0xFF111827);
const _muted = Color(0xFF6B7280);
const _bg = Color(0xFFF6F7FB);
const _card = Colors.white;
const _line = Color(0xFFE5E7EB);
const double _maxContentW = 1080;

class ItemPage extends StatefulWidget {
  final int productId;
  const ItemPage({super.key, required this.productId});

  @override
  State<ItemPage> createState() => _ItemPageState();
}

class _ItemPageState extends State<ItemPage> {
  Future<Product>? _productF;
  Future<List<ProductOption>>? _optionsF;

  final _cartSvc = CartService();
  bool _adding = false;
  int _imgIndex = 0;

  String? _selectedColor;
  String? _selectedSize;
  String _userCity = 'Hồ Chí Minh';

  @override
  void initState() {
    super.initState();
    _productF = _fetchProduct(widget.productId);
    _optionsF = _fetchOptions(widget.productId);
    _loadUserCity();
  }

  Future<void> _loadUserCity() async {
    final sp = await SharedPreferences.getInstance();
    final c = sp.getString('city') ?? sp.getString('user_city');
    if (c != null && c.trim().isNotEmpty && mounted) {
      setState(() => _userCity = c.trim());
    }
  }

  Future<Product> _fetchProduct(int id) async {
    final json = await ApiService().getProductDetails(id);
    return Product.fromJson(json);
  }

  Future<List<ProductOption>> _fetchOptions(int id) async {
    try {
      final list = await ApiService().getProductOptions(id);
      return list;
    } catch (_) {
      return <ProductOption>[];
    }
  }

  String _absUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${AppConfig.baseUrl}$path';
  }

  String _vnd(num n) =>
      n.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');

  num _afterDiscount(num price, num? d) {
    if (d == null || d <= 0) return price;
    return price * (100 - d) / 100;
  }

  String _etaLabel(String city) {
    final c = city.toLowerCase();
    int days;
    if (c.contains('hồ chí minh') || c.contains('ho chi minh') || c.contains('hcm')) {
      days = 1;
    } else if (c.contains('đà nẵng') || c.contains('da nang')) {
      days = 2;
    } else if (c.contains('cần thơ') || c.contains('can tho')) {
      days = 2;
    } else if (c.contains('hà nội') || c.contains('ha noi')) {
      days = 3;
    } else {
      days = 3;
    }
    if (days == 1) return 'Giao nhanh • Nhận trong Ngày Mai 12:00';
    return 'Dự kiến giao trong $days ngày';
  }

  List<String> _colorsOf(List<ProductOption> opts) {
    final s = <String>{};
    for (final o in opts) {
      final v = o.color.trim();
      if (v.isNotEmpty) s.add(v);
    }
    return s.toList();
  }

  List<String> _sizesOf(List<ProductOption> opts, {String? color}) {
    final s = <String>{};
    for (final o in opts) {
      if (color != null && color.isNotEmpty && o.color != color) continue;
      final v = o.size.trim();
      if (v.isNotEmpty) s.add(v);
    }
    final out = s.toList()..sort((a, b) => a.compareTo(b));
    return out;
  }

  bool _colorHasStock(String color, List<ProductOption> opts) {
    return opts.any((o) =>
        o.color == color &&
        (_selectedSize == null || o.size == _selectedSize) &&
        (o.stock ?? 0) > 0);
  }

  bool _sizeHasStock(String size, List<ProductOption> opts) {
    return opts.any((o) =>
        o.size == size &&
        (_selectedColor == null || o.color == _selectedColor) &&
        (o.stock ?? 0) > 0);
  }

  ProductOption? _currentVariant(List<ProductOption> opts) {
    try {
      if (_selectedColor == null && _selectedSize == null) return null;
      return opts.firstWhere(
        (o) =>
            (_selectedColor == null || o.color == _selectedColor) &&
            (_selectedSize == null || o.size == _selectedSize),
      );
    } catch (_) {
      return null;
    }
  }

  int _soldOf(Product p) {
    try {
      final d = p as dynamic;
      final v = d.sold ?? d.soldCount ?? d.totalSold ?? d.sales ?? d.orders ?? 0;
      return int.tryParse('$v') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  int _stockFor(List<ProductOption> opts) {
    final v = _currentVariant(opts);
    if (v != null) return (v.stock ?? 0);
    int sum = 0;
    for (final o in opts) {
      if (_selectedColor != null && o.color != _selectedColor) continue;
      if (_selectedSize != null && o.size != _selectedSize) continue;
      sum += (o.stock ?? 0);
    }
    return sum;
  }

  Future<void> _addToCart(int productId) async {
    if (_adding) return;
    setState(() => _adding = true);
    try {
      final opts = await (_optionsF ??= _fetchOptions(widget.productId));
      final hasColor = opts.any((o) => o.color.trim().isNotEmpty);
      final hasSize = opts.any((o) => o.size.trim().isNotEmpty);

      if ((hasColor && _selectedColor == null) || (hasSize && _selectedSize == null)) {
        _showSnack('Vui lòng chọn Màu sắc và Kích cỡ');
        return;
      }

      final variant = _currentVariant(opts);
      if (variant != null && (variant.stock ?? 0) <= 0) {
        _showSnack('Biến thể đã hết hàng, vui lòng chọn biến thể khác');
        return;
      }

      final sp = await SharedPreferences.getInstance();
      final token = sp.getString('token') ?? '';
      if (token.isEmpty) {
        _showSnack('Bạn chưa đăng nhập');
        return;
      }

      await _cartSvc.addToCart(
        token: token,
        productId: productId,
        quantity: 1,
        optionId: variant?.id,
        color: _selectedColor,
        size: _selectedSize,
      );

      _showSnack('Đã thêm vào giỏ');
    } catch (e) {
      _showSnack('Không thể thêm giỏ: $e');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _buyNow(Product p) async {
    final opts = await (_optionsF ??= _fetchOptions(widget.productId));
    final hasColor = opts.any((o) => o.color.trim().isNotEmpty);
    final hasSize = opts.any((o) => o.size.trim().isNotEmpty);

    if ((hasColor && _selectedColor == null) || (hasSize && _selectedSize == null)) {
      _showSnack('Vui lòng chọn Màu sắc và Kích cỡ');
      return;
    }

    final variant = _currentVariant(opts);
    if (variant != null && (variant.stock ?? 0) <= 0) {
      _showSnack('Biến thể đã hết hàng, vui lòng chọn biến thể khác');
      return;
    }

    final double pay = _afterDiscount(p.price, p.discount).toDouble();
    if (!mounted) return;
    Navigator.pushNamed(
      context,
      '/checkout',
      arguments: {
        'mode': 'buy_now',
        'item': {
          'productId': p.id,
          'name': p.name,
          'price': pay,
          'qty': 1,
          'thumb': p.thumb ?? p.imageUrl,
          'optionId': variant?.id,
          'color': _selectedColor,
          'size': _selectedSize,
        },
      },
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isWide = kIsWeb && MediaQuery.of(context).size.width >= 1024;

    return Scaffold(
      backgroundColor: _bg,
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: ItemAppBar(),
      ),
      bottomNavigationBar: FutureBuilder<Product>(
        future: _productF ??= _fetchProduct(widget.productId),
        builder: (_, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const SizedBox.shrink();
          }
          if (!s.hasData) return const SizedBox.shrink();
          final p = s.data!;
          return ItemBottomNavBar(
            onContact: () => _contactSheet(context),
            onAddToCart: () => _addToCart(widget.productId),
            onBuyNow: () => _buyNow(p),
            adding: _adding,
          );
        },
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isWide ? _maxContentW : double.infinity,
          ),
          child: FutureBuilder<Product>(
            future: _productF ??= _fetchProduct(widget.productId),
            builder: (_, s) {
              if (s.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!s.hasData) return const SizedBox();

              final p = s.data!;
              final imgs = (p.images.isNotEmpty)
                  ? p.images.map(_absUrl).toList()
                  : (p.imageUrl?.isNotEmpty == true)
                      ? [_absUrl(p.imageUrl)]
                      : <String>[];

              return FutureBuilder<List<ProductOption>>(
                future: _optionsF ??= _fetchOptions(widget.productId),
                builder: (_, o) {
                  final options = o.data ?? const <ProductOption>[];
                  final colors = _colorsOf(options);
                  final sizes = _sizesOf(options, color: _selectedColor);

                  final int productIdForReview =
                      (p.id is int) ? (p.id as int) : int.parse(p.id.toString());

                  return ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _MediaCarousel(
                        images: imgs,
                        index: _imgIndex,
                        onChanged: (i) => setState(() => _imgIndex = i),
                      ),

                      _Section(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${_vnd(_afterDiscount(p.price, p.discount))} đ',
                                  style: const TextStyle(
                                    color: _brand,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if ((p.discount ?? 0) > 0)
                                  Text(
                                    '${_vnd(p.price)} đ',
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 13,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              p.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _text,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const SizedBox(width: 8),
                                const Text('•', style: TextStyle(color: _muted)),
                                const SizedBox(width: 8),
                                Text('Đã bán ${_soldOf(p)}',
                                    style: const TextStyle(color: _muted)),
                              ],
                            ),
                            if ((p.shortDescription ?? p.description)?.trim().isNotEmpty == true) ...[
                              const SizedBox(height: 10),
                              _ExpandableText(
                                text: (p.shortDescription ?? p.description)!.trim(),
                                trimLines: 2,
                              ),
                            ],
                          ],
                        ),
                      ),

                      if (colors.isNotEmpty || sizes.isNotEmpty)
                        _Section(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Chọn biến thể',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800, color: _text)),
                              const SizedBox(height: 10),
                              if (colors.isNotEmpty) ...[
                                const Text('Màu sắc',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700, color: _text)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: colors.map((c) {
                                    final sel = _selectedColor == c;
                                    final enable = _colorHasStock(c, options);
                                    return ChoiceChip(
                                      label: Text(c),
                                      selected: sel,
                                      onSelected: enable
                                          ? (_) {
                                              setState(() {
                                                _selectedColor = c;
                                                if (_selectedSize != null &&
                                                    !_sizeHasStock(
                                                        _selectedSize!, options)) {
                                                  _selectedSize = null;
                                                }
                                              });
                                            }
                                          : null,
                                      labelStyle: TextStyle(
                                        color: sel
                                            ? Colors.white
                                            : (enable ? _text : Colors.black38),
                                        fontWeight: FontWeight.w700,
                                      ),
                                      selectedColor: _brand,
                                      backgroundColor: const Color(0xFFF3F4F6),
                                      side: const BorderSide(color: _line),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (sizes.isNotEmpty) ...[
                                const Text('Kích cỡ',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700, color: _text)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: sizes.map((s2) {
                                    final sel = _selectedSize == s2;
                                    final enable = _sizeHasStock(s2, options);
                                    return ChoiceChip(
                                      label: Text(s2),
                                      selected: sel,
                                      onSelected: enable
                                          ? (_) => setState(() => _selectedSize = s2)
                                          : null,
                                      labelStyle: TextStyle(
                                        color: sel
                                            ? Colors.white
                                            : (enable ? _text : Colors.black38),
                                        fontWeight: FontWeight.w700,
                                      ),
                                      selectedColor: _brand,
                                      backgroundColor: const Color(0xFFF7F7FA),
                                      side: const BorderSide(color: _line),
                                    );
                                  }).toList(),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Builder(
                                builder: (_) {
                                  if (options.isEmpty) {
                                    return const SizedBox.shrink();
                                  }

                                  final stock = _stockFor(options);
                                  final variant = _currentVariant(options);

                                  String text;
                                  Color color;

                                  if (_selectedColor == null &&
                                      _selectedSize == null) {
                                    text =
                                        'Chọn màu / size để xem tồn kho từng biến thể';
                                    color = _muted;
                                  } else if (variant != null) {
                                    if (stock > 0) {
                                      final parts = <String>[];
                                      final vc = variant.color.trim();
                                      final vs = variant.size.trim();
                                      if (vc.isNotEmpty) parts.add(vc);
                                      if (vs.isNotEmpty) parts.add('size $vs');
                                      final label = parts.isEmpty
                                          ? ''
                                          : ' (${parts.join(' - ')})';
                                      text = 'Còn $stock sản phẩm$label';
                                      color = Colors.green;
                                    } else {
                                      text =
                                          'Biến thể đã chọn hiện đã hết hàng';
                                      color = Colors.red;
                                    }
                                  } else {
                                    if (stock > 0) {
                                      final desc = [
                                        if (_selectedColor != null)
                                          'màu $_selectedColor',
                                        if (_selectedSize != null)
                                          'size $_selectedSize',
                                      ].join(' - ');
                                      text =
                                          'Các biến thể $desc: tổng còn $stock sản phẩm';
                                      color = Colors.green;
                                    } else {
                                      text =
                                          'Không còn hàng cho lựa chọn hiện tại';
                                      color = Colors.red;
                                    }
                                  }

                                  return Row(
                                    children: [
                                      const Icon(Icons.inventory_2_outlined,
                                          size: 18, color: _muted),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          text,
                                          style: TextStyle(
                                            color: color,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                      _Section(
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.local_shipping_rounded,
                                  color: Colors.green),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Giao hàng',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: _text)),
                                  const SizedBox(height: 4),
                                  Text(_etaLabel(_userCity),
                                      style:
                                          const TextStyle(color: _muted)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: _muted),
                          ],
                        ),
                      ),

                      _ReviewsBlock(productId: productIdForReview),

                      const SizedBox(height: 8),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _contactSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Liên hệ shop',
                style:
                    TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            ListTile(
              leading:
                  const Icon(Icons.chat_bubble_outline, color: _brand),
              title: const Text('Chat với shop'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading:
                  const Icon(Icons.phone_outlined, color: _brand),
              title: const Text('Gọi 0900 000 000'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

/* ================= MEDIA CAROUSEL (ảnh nhỏ hơn trên web) ================= */

class _MediaCarousel extends StatelessWidget {
  final List<String> images;
  final int index;
  final ValueChanged<int> onChanged;

  const _MediaCarousel({
    required this.images,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasImg = images.isNotEmpty;
    final width = MediaQuery.of(context).size.width;

    double height;
    if (kIsWeb) {
      // Web / laptop: ảnh thấp hơn, không tràn màn
      height = width * 0.35; // 35% chiều ngang
      if (height > 360) height = 360;
      if (height < 220) height = 220;
    } else {
      // Mobile: vẫn cao, trải nghiệm tốt
      height = width * 0.6; // tương đương ~16:10
    }

    return Stack(
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: PageView.builder(
            onPageChanged: onChanged,
            itemCount: hasImg ? images.length : 1,
            itemBuilder: (_, i) {
              if (!hasImg) {
                return Container(
                  color: _card,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    size: 48,
                    color: Colors.black26,
                  ),
                );
              }
              return Container(
                color: _card,
                alignment: Alignment.center,
                child: Image.network(
                  images[i],
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    size: 48,
                    color: Colors.black26,
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              hasImg ? '${index + 1}/${images.length}' : '0/0',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/* ================== REVIEWS ================== */

class _ReviewsBlock extends StatefulWidget {
  final int productId;
  const _ReviewsBlock({required this.productId});

  @override
  State<_ReviewsBlock> createState() => _ReviewsBlockState();
}

class _ReviewsBlockState extends State<_ReviewsBlock> {
  bool _loading = true;
  List<Map<String, dynamic>> _reviews = const [];
  Map<String, dynamic> _stats = const {'TotalReviews': 0, 'AvgRating': 0};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      await _fetchReviews();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchReviews() async {
    final base = AppConfig.baseUrl.endsWith('/')
        ? AppConfig.baseUrl.substring(0, AppConfig.baseUrl.length - 1)
        : AppConfig.baseUrl;
    final url = Uri.parse('$base/api/reviews/product/${widget.productId}');

    final r =
        await http.get(url, headers: {'Accept': 'application/json'});
    if (r.statusCode != 200) return;

    final m = json.decode(r.body) as Map<String, dynamic>;
    final raw =
        (m['reviews'] as List? ?? []).cast<Map<String, dynamic>>();

    final normalized = raw.map((e) {
      final mm = Map<String, dynamic>.from(e);
      final imgs = (mm['images'] as List? ?? []).map((u) {
        final s = u.toString();
        return s.startsWith('http') ? s : '$base$s';
      }).toList();
      mm['images'] = imgs;
      mm['__name'] =
          (mm['CustomerName'] ?? mm['FullName'] ?? mm['Email'] ?? 'Khách hàng')
              .toString();
      mm['__created'] = mm['CreatedAt'];
      return mm;
    }).toList();

    if (!mounted) return;
    setState(() {
      _reviews = normalized;
      _stats = (m['stats'] as Map?)?.cast<String, dynamic>() ??
          {'TotalReviews': 0, 'AvgRating': 0};
    });
  }

  DateTime _parseDt(String? iso) {
    if (iso == null) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    try {
      return DateTime.parse(iso);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: _card,
        padding: const EdgeInsets.all(12),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final avg = (_stats['AvgRating'] ?? 0).toString();
    final total = _stats['TotalReviews'] ?? 0;

    final sorted = List<Map<String, dynamic>>.from(_reviews)
      ..sort((a, b) => _parseDt(a['__created']?.toString())
          .compareTo(_parseDt(b['__created']?.toString())));
    final display = sorted.take(2).toList();

    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Đánh giá',
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: _text)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 18),
              const SizedBox(width: 4),
              Text(
                '$avg/5 • $total đánh giá',
                style: const TextStyle(color: _muted),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/reviews',
                    arguments: {'productId': widget.productId},
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _brand,
                  side: const BorderSide(color: _line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Xem tất cả'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_reviews.isEmpty)
            const Text('Chưa có đánh giá',
                style: TextStyle(color: _muted)),
          for (final r in display) ...[
            _ReviewItem(
              name: (r['__name'] ?? r['CustomerName'] ?? 'Khách hàng')
                  .toString(),
              content: (r['Comment'] ?? '').toString(),
              rating:
                  int.tryParse('${r['Rating'] ?? 0}') ?? 0,
              time: r['__created']?.toString(),
            ),
            if ((r['images'] as List?)?.isNotEmpty == true)
              Padding(
                padding:
                    const EdgeInsets.only(left: 38, top: 6, bottom: 12),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ((r['images'] as List?) ?? const [])
                      .map((u) => ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              u.toString(),
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  Container(
                                width: 72,
                                height: 72,
                                color: const Color(0xFFF3F4F6),
                                child: const Icon(
                                  Icons
                                      .broken_image_outlined,
                                  size: 20,
                                  color: _muted,
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  final String name;
  final String content;
  final int rating;
  final String? time;

  const _ReviewItem({
    required this.name,
    required this.content,
    required this.rating,
    this.time,
  });

  String _fmt(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.only(bottom: 10),
      decoration: const BoxDecoration(
        border:
            Border(bottom: BorderSide(color: _line, width: .7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 14,
            backgroundColor: Color(0xFFF7F7FA),
            child: Icon(Icons.person,
                color: _muted, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _text),
                      ),
                    ),
                    if (_fmt(time).isNotEmpty)
                      Text(
                        _fmt(time),
                        style: const TextStyle(
                            fontSize: 12, color: _muted),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(5, (i) {
                    final filled = i < rating;
                    return Icon(
                      filled
                          ? Icons.star
                          : Icons.star_border,
                      size: 16,
                      color: Colors.amber,
                    );
                  }),
                ),
                const SizedBox(height: 6),
                if (content.trim().isNotEmpty)
                  Text(
                    content,
                    style:
                        const TextStyle(color: _text),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ================== UI UTIL ================== */

class _Section extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  const _Section({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 12),
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      color: _card,
      padding: padding,
      child: child,
    );
  }
}

class _ExpandableText extends StatefulWidget {
  final String text;
  final int trimLines;
  const _ExpandableText({required this.text, this.trimLines = 2});

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;
  bool _overflow = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tp = TextPainter(
      text: TextSpan(
        text: widget.text,
        style: const TextStyle(
          fontSize: 14.5,
          color: Color(0xFF4B5563),
          height: 1.5,
        ),
      ),
      maxLines: widget.trimLines,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: MediaQuery.of(context).size.width - 24);
    _overflow = tp.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    final body = Text(
      widget.text,
      maxLines: _expanded ? null : widget.trimLines,
      overflow:
          _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 14.5,
        color: Color(0xFF4B5563),
        height: 1.5,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedCrossFade(
          firstChild: body,
          secondChild: body,
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration:
              const Duration(milliseconds: 180),
        ),
        if (_overflow) ...[
          const SizedBox(height: 6),
          InkWell(
            onTap: () =>
                setState(() => _expanded = !_expanded),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _expanded ? 'Thu gọn' : 'Xem thêm',
                  style: const TextStyle(
                    color: _brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  size: 18,
                  color: _brand,
                ),
              ],
            ),
          )
        ],
      ],
    );
  }
}
