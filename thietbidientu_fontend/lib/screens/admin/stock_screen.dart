// lib/screens/admin/stock_screen.dart
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:thietbidientu_fontend/models/product.dart';
import 'package:thietbidientu_fontend/services/api_service.dart';

// model ProductOption (đặt alias để không đụng tên widget)
import 'package:thietbidientu_fontend/models/product_option.dart' as m;

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final _api = ApiService();
  final _searchCtl = TextEditingController();

  // ========= cấu hình =========
  int _lowThreshold = 10; // dùng cho logic “≤10 là sắp hết”
  bool _includeInactive = false;
  bool _variantMode = false;
  // ============================

  // Ngưỡng màu: <3 ⇒ đỏ; <_lowThreshold(=10) ⇒ vàng
  static const int _redThreshold = 3;
  int get _warnThreshold => _lowThreshold;

  List<Product> _all = [];
  List<Product> _view = [];
  bool _loading = true;

  /// Cache biến thể theo productId
  final Map<String, List<m.ProductOption>> _optCache = {};

  /// DỮ LIỆU INVENTORY (mới)
  final Map<int, int> _invStock = {}; // productId -> stock
  final Map<int, String> _invCode = {}; // productId -> code string
  final Map<int, int> _invOpt = {}; // optionId  -> stock

  /// TỔNG HỢP THEO SẢN PHẨM (dùng cho màn giữa)
  /// pid -> { MinStock, TotalStock, OutCount, LowCount, Severity }
  final Map<int, Map<String, dynamic>> _prodAgg = {};

  /// Tập productId có ÍT NHẤT MỘT biến thể sắp hết (để lọc màn Sản phẩm)
  final Set<int> _lowOptionProductIds = {};

  // Dữ liệu cho chế độ biến thể (dùng chung cho 2 màn biến thể)
  bool _vLoading = false;
  List<_VarRow> _variantRows = [];

  // Phân trang (sản phẩm)
  int _rowsPerPage = 10;
  final List<int> _rowsPerPageOptions = const [5, 10, 20, 50, 100];
  int _currentPage = 0;

  // Sắp xếp (sản phẩm)
  int? _sortColumnIndex;
  bool _sortAscending = true;

  // Nhận tham số khi mở màn
  bool _argsLoaded = false;
  bool _lowOnly = true;

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  bool _toBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase().trim();
      return s == '1' || s == 'true' || s == 'yes';
    }
    return false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    if (args != null) {
      if (args.containsKey('lowOnly')) _lowOnly = args['lowOnly'] == true;
      if (args.containsKey('variantMode')) _variantMode = args['variantMode'] == true;
      if (args.containsKey('threshold')) {
        final t = _toInt(args['threshold']);
        if (t > 0) _lowThreshold = t;
      }
      if (args.containsKey('includeInactive')) {
        _includeInactive = _toBool(args['includeInactive']);
      }
    }
    _argsLoaded = true;
  }

  @override
  void initState() {
    super.initState();
    _lowOnly = false; // ⬅️ màn giữa: hiển thị tất cả sản phẩm
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // 1) lấy danh sách sản phẩm như cũ
      _all = await _api.getProducts();

      // 2) (MỚI) lấy tồn kho & mã SP từ Inventory; nếu BE chưa có API -> ignore, FE vẫn chạy
      await _hydrateInventory();

      // 3) (MỚI) lấy tổng hợp theo sản phẩm để tô màu và hiển thị tổng SL
      await _hydrateProductSummary();

      // 4) (MỚI) tải danh sách biến thể sắp hết — xây cả _variantRows & _lowOptionProductIds
      await _refreshLowVariants();

      // 5) build view
      if (_variantMode && _lowOnly) {
        setState(() {});
      } else {
        _applyFilter();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
      );
      _all = [];
      _view = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Lấy biến thể sắp hết và đồng bộ 2 cache: _variantRows + _lowOptionProductIds
  Future<void> _refreshLowVariants() async {
    setState(() {
      _vLoading = true;
      _variantRows = [];
      _lowOptionProductIds.clear();
    });

    try {
      final raw = await _api.getLowOptions(threshold: _lowThreshold);

      final rows = <_VarRow>[];
      for (final em in (raw as List)) {
        final e = (em as Map);
        final pid = _toInt(e['ProductID'] ?? e['productId']);
        final oid = _toInt(e['OptionID'] ?? e['optionId']);
        final name = (e['ProductName'] ?? e['name'] ?? '').toString();
        final size = e['Size']?.toString();
        final color = e['Color']?.toString();
        final stock = _toInt(e['Stock'] ?? e['stock']);

        // Fallback Product đúng kiểu (id String)
        final p = _all.firstWhere(
          (x) => _toInt(x.id) == pid,
          orElse: () => Product(
            id: '$pid',
            name: name,
            price: 0.0,
            stock: stock,
            images: const [],
            isActive: true,
          ),
        );

        final o = m.ProductOption(
          id: oid,
          productId: pid,
          size: size ?? 'DEFAULT',
          color: color ?? 'DEFAULT',
          stock: stock,
        );

        rows.add(_VarRow(p: p, o: o));
        if (pid > 0) _lowOptionProductIds.add(pid);
      }

      // sắp xếp: đỏ -> vàng -> xanh, rồi theo SL tăng dần
      rows.sort((a, b) {
        int rank(_ChipTone t) => t == _ChipTone.red ? 0 : (t == _ChipTone.orange ? 1 : 2);
        final ta = _toneForStock(a.o.stock ?? 0);
        final tb = _toneForStock(b.o.stock ?? 0);
        final r = rank(ta).compareTo(rank(tb));
        if (r != 0) return r;
        return (a.o.stock ?? 0).compareTo(b.o.stock ?? 0);
      });

      if (!mounted) return;
      setState(() {
        _variantRows = rows;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi lấy biến thể sắp hết: $e')),
      );
    } finally {
      if (mounted) setState(() => _vLoading = false);
    }
  }

  /// Gộp số liệu Inventory vào FE (mới)
  Future<void> _hydrateInventory() async {
    try {
      final inv = await _api.get('/api/inventory/summary');
      if (inv is List) {
        for (final e in inv) {
          if (e is Map) {
            final pid = _toInt(e['productId'] ?? e['ProductID']);
            if (pid <= 0) continue;
            final st = _toInt(e['stock'] ?? e['Stock']);
            final cd = (e['code'] ?? e['Code'] ?? '$pid').toString();
            _invStock[pid] = st;
            _invCode[pid] = cd;
          }
        }
      }
    } catch (_) {
      // không sao, thiếu API thì dùng số liệu hiện tại
    }

    try {
      final opt = await _api.get('/api/inventory/options');
      if (opt is List) {
        for (final e in opt) {
          if (e is Map) {
            final oid = _toInt(e['optionId'] ?? e['OptionID']);
            if (oid <= 0) continue;
            final st = _toInt(e['stock'] ?? e['Stock']);
            _invOpt[oid] = st;
          }
        }
      }
    } catch (_) {
      // optional
    }
  }

  /// Nạp tổng hợp theo sản phẩm: TotalStock/MinStock/Severity...
  /// Nạp tổng hợp theo sản phẩm: TotalStock/MinStock/Severity...
Future<void> _hydrateProductSummary() async {
  try {
    final list = await _api.get(
      '/api/inventory/product-summary?threshold=$_lowThreshold&red=$_redThreshold',
    );
    if (list is List) {
      _prodAgg
        ..clear()
        ..addEntries(
          list.map((e) {
            final map = Map<String, dynamic>.from(e as Map);
            final pid = _toInt(map['ProductID']);
            return MapEntry<int, Map<String, dynamic>>(pid, map);
          }),
        );

      // 🔥 BỔ SUNG: đảm bảo _all có đầy đủ các sản phẩm có trong summary
      final existingIds = _all.map((p) => _toInt(p.id)).toSet();
      for (final entry in _prodAgg.entries) {
        final pid = entry.key;
        if (!existingIds.contains(pid)) {
          final m = entry.value;
          final name = (m['ProductName'] ?? 'SP #$pid').toString();
          final total = _toInt(m['TotalStock']);
          _all.add(Product(
            id: '$pid',
            name: name,
            price: 0.0,
            stock: total,      // fallback: dùng tổng stock từ summary
            images: const [],
            isActive: true,    // không biết trạng thái => mặc định true
          ));
        }
      }
    }
  } catch (_) {
    // optional
  }
}


  // ---------- tone helpers ----------
  _ChipTone _toneForStock(int stock) {
    if (stock <= 0) return _ChipTone.red;                  // Hết
    if (stock < _redThreshold) return _ChipTone.red;       // 1..2 ⇒ đỏ
    if (stock < _warnThreshold) return _ChipTone.orange;   // 3..9 ⇒ vàng
    return _ChipTone.green;                                // ≥10 ⇒ xanh
  }

  /// Tổng SL theo summary (fallback: stock cũ)
  int _summaryTotalStock(Product p) {
    final pid = _toInt(p.id);
    final m = _prodAgg[pid];
    if (m != null) return _toInt(m['TotalStock']);
    return _stockOfProduct(p);
  }

  /// Severity: 3 đỏ đậm (hết) | 2 đỏ nhạt (1..2) | 1 vàng (3..9) | 0 xanh (>=10)
  int _summarySeverity(Product p) {
    final pid = _toInt(p.id);
    final m = _prodAgg[pid];
    if (m != null) return _toInt(m['Severity']);
    // fallback theo tổng stock hiện có
    final st = _summaryTotalStock(p);
    if (st <= 0) return 3;
    if (st < _redThreshold) return 2;
    if (st < _warnThreshold) return 1;
    return 0;
  }

  /// Viền theo severity (màn giữa)
  Color _borderBySeverity(int sev) {
    switch (sev) {
      case 3:
        return Colors.red.shade900;     // đỏ đậm
      case 2:
        return Colors.red.shade400;     // đỏ nhạt
      case 1:
        return Colors.orange.shade600;  // vàng
      default:
        return Colors.green.shade600;   // xanh
    }
  }

  // ⚠️ Hàm này dùng cho các block hiển thị BIẾN THỂ (border theo tồn của biến thể)
  Color _stockBorderColor(int stock) {
    if (stock <= 0) return Colors.red.shade900;       // đỏ đậm
    if (stock < _redThreshold) return Colors.red.shade400; // đỏ nhạt (1..2)
    if (stock < _warnThreshold) return Colors.orange.shade600; // vàng (3..9)
    return Colors.transparent;                        // còn nhiều: không viền
  }

  // (giữ nguyên) Helpers đọc số liệu trực tiếp
  int _stockOfProduct(Product p) {
    final pid = int.tryParse('${p.id}') ?? 0;
    return _invStock[pid] ?? p.stock; // ưu tiên Inventory, fallback dữ liệu cũ
  }

  int _stockOfOption(m.ProductOption o) {
    final oid = (o.id ?? 0);
    return _invOpt[oid] ?? (o.stock ?? 0);
  }

  String _codeOfProduct(Product p) {
    final pid = int.tryParse('${p.id}') ?? 0;
    return _invCode[pid] ?? '${p.id}';
  }

  // ---------- chế độ SẢN PHẨM ----------
  void _applyFilter() {
    final q = _searchCtl.text.trim().toLowerCase();

    _view = q.isEmpty
        ? List<Product>.from(_all)
        : _all.where((p) {
            final code = _codeOfProduct(p);
            return p.name.toLowerCase().contains(q) ||
                code.toLowerCase().contains(q) ||
                ('${p.id}').toLowerCase().contains(q);
          }).toList();

    if (_lowOnly) {
      // ⭐ Lọc theo “có ít nhất một biến thể sắp hết”
      _view = _view.where((p) {
        if (!_includeInactive && p.isActive == false) return false;
        final pid = int.tryParse('${p.id}') ?? 0;
        return _lowOptionProductIds.contains(pid);
      }).toList();
    } else {
      if (!_includeInactive) {
        _view = _view.where((p) => p.isActive != false).toList();
      }
    }

    _currentPage = 0;
    setState(() {});
  }

  void _sort<T>(
    Comparable<T> Function(Product p) getField,
    int columnIndex,
    bool ascending,
  ) {
    _view.sort((a, b) {
      final aVal = getField(a);
      final bVal = getField(b);
      final cmp = Comparable.compare(aVal, bVal);
      return ascending ? cmp : -cmp;
    });
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
  }

  int _pid(Product p) => int.tryParse('${p.id}') ?? 0;

  List<Product> _pageSlice() {
    if (_view.isEmpty) return const [];
    final start = _currentPage * _rowsPerPage;
    final rawEnd = (start + _rowsPerPage);
    final end = rawEnd.clamp(0, _view.length).toInt();
    if (start >= _view.length) return const [];
    return _view.sublist(start, end);
  }

  // ---------- thumbs ----------
  String? _thumbUrlOf(Product p) {
    if (p.thumb != null && p.thumb!.isNotEmpty) return p.thumb;
    if (p.imageUrl != null && p.imageUrl!.isNotEmpty) return p.imageUrl;
    if (p.images.isNotEmpty) return p.images.first;
    return null;
  }

  Widget _thumbBox(Product p, {double size = 44}) {
    final url = _thumbUrlOf(p);
    final border = BorderRadius.circular(8);
    return ClipRRect(
      borderRadius: border,
      child: Container(
        width: size,
        height: size,
        color: Colors.grey.withOpacity(.15),
        child: url == null
            ? Icon(Icons.inventory_2, size: size * .65, color: Colors.grey)
            : Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.broken_image, size: size * .65, color: Colors.grey),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  // ====== API biến thể ======
  Future<List<m.ProductOption>> _getOptions(Product p) async {
    final key = '${p.id}';
    if (_optCache.containsKey(key)) return _optCache[key]!;
    final id = int.tryParse(key) ?? 0;
    if (id <= 0) return const [];
    try {
      final list = await _api.getProductOptions(id);
      _optCache[key] = list;
      return list;
    } catch (_) {
      return const [];
    }
  }

  // ====== UI biến thể ======
  String _optionLabel(m.ProductOption o) {
    final sizeRaw = o.size == null ? null : o.size.toString();
    final colorRaw = o.color == null ? null : o.color.toString();
    final size = (sizeRaw == null || sizeRaw.trim().isEmpty) ? null : sizeRaw.trim();
    final color = (colorRaw == null || colorRaw.trim().isEmpty) ? null : colorRaw.trim();
    if (size != null && color != null) return '$size • $color';
    return size ?? color ?? 'Biến thể';
  }

  Widget _variantStatus(int stock) {
    if (stock <= 0) {
      return const _StatusChip(label: 'Hết', tone: _ChipTone.red);
    }
    if (stock < _redThreshold) {
      return const _StatusChip(label: 'Sắp hết', tone: _ChipTone.red);
    }
    if (stock < _warnThreshold) {
      return const _StatusChip(label: 'Sắp hết', tone: _ChipTone.orange);
    }
    return const _StatusChip(label: 'Còn', tone: _ChipTone.green);
  }

  List<_VarRow> _filterVariantRows(List<_VarRow> src) {
    final q = _searchCtl.text.trim().toLowerCase();
    if (q.isEmpty) return src;
    return src.where((r) {
      final code = _codeOfProduct(r.p);
      final label = _optionLabel(r.o).toLowerCase();
      return r.p.name.toLowerCase().contains(q) ||
          code.toLowerCase().contains(q) ||
          label.contains(q);
    }).toList();
  }

  // ====== xem chi tiết biến thể 1 sản phẩm ======
  void _showVariants(Product p) async {
    String filter = 'all';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SafeArea(
                top: false,
                child: FutureBuilder<List<m.ProductOption>>(
                  future: _getOptions(p),
                  builder: (ctx, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const SizedBox(
                        height: 240,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final optsRaw = snap.data ?? const <m.ProductOption>[];
                    final opts = List<m.ProductOption>.from(optsRaw)
                      ..sort((a, b) {
                        int ra(_ChipTone t) =>
                            t == _ChipTone.red ? 0 : (t == _ChipTone.orange ? 1 : 2);
                        final ta = _toneForStock(_stockOfOption(a));
                        final tb = _toneForStock(_stockOfOption(b));
                        final r = ra(ta).compareTo(ra(tb));
                        if (r != 0) return r;
                        return _stockOfOption(a).compareTo(_stockOfOption(b));
                      });

                    List<m.ProductOption> filtered = opts.where((o) {
                      final st = _stockOfOption(o);
                      switch (filter) {
                        case 'low':
                          return st > 0 && st <= _lowThreshold;
                        case 'out':
                          return st <= 0;
                        case 'in':
                          return st > _lowThreshold;
                        default:
                          return true;
                      }
                    }).toList();

                    final total = opts.fold<int>(0, (s, o) => s + _stockOfOption(o));
                    final lowCount = opts
                        .where((o) {
                          final st = _stockOfOption(o);
                          return st > 0 && st <= _lowThreshold;
                        })
                        .length;
                    final outCount = opts.where((o) => _stockOfOption(o) <= 0).length;
                    final inCount = opts.where((o) => _stockOfOption(o) > _lowThreshold).length;

                    Widget chip(String label, String key, int count, Color c) {
                      final sel = filter == key;
                      return ChoiceChip(
                        label: Text('$label ($count)'),
                        selected: sel,
                        onSelected: (_) => setModal(() => filter = key),
                        selectedColor: c.withOpacity(.15),
                      );
                    }

                    final code = _codeOfProduct(p);

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const _StatusChip(
                                  label: 'Chi tiết biến thể', tone: _ChipTone.grey),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Mã SP: $code • Biến thể: ${opts.length} • Sắp hết: $lowCount • Hết: $outCount • Còn: $inCount • Tổng SL: $total',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              chip('Tất cả', 'all', opts.length, Colors.blueGrey),
                              chip('Sắp hết', 'low', lowCount, Colors.orange),
                              chip('Hết', 'out', outCount, Colors.red),
                              chip('Còn', 'in', inCount, Colors.green),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (filtered.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Không có biến thể phù hợp bộ lọc.'),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (ctx, i) {
                                final o = filtered[i];
                                final stock = _stockOfOption(o);
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent, // bỏ nền
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _stockBorderColor(stock), // ⬅️ dùng lại
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(_optionLabel(o),
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w600)),
                                            const SizedBox(height: 4),
                                            Text('Mã SP: $code',
                                                style: const TextStyle(
                                                    fontSize: 12.5,
                                                    color: Colors.black54)),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(right: 10),
                                        child: Text('SL: $stock',
                                            style: const TextStyle(
                                              fontFeatures: [FontFeature.tabularFigures()],
                                            )),
                                      ),
                                      _variantStatus(stock),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ====== xem TẤT CẢ biến thể sắp hết ======
  Future<void> _showAllLowVariants() async {
    // Sử dụng cache hiện tại để đồng nhất số liệu giữa 2 màn
    final rows = List<_VarRow>.from(_variantRows);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final totalLow = rows.length;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Biến thể sắp hết (≤ $_lowThreshold)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Tổng: $totalLow biến thể',
                    style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 10),
                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Không có biến thể sắp hết.'),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final r = rows[i];
                        final stock = _stockOfOption(r.o);
                        final code = _codeOfProduct(r.p);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _stockBorderColor(stock), // ⬅️ dùng lại
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              _thumbBox(r.p, size: 40),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r.p.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text('Mã SP: $code • ${_optionLabel(r.o)}',
                                        style: const TextStyle(color: Colors.black54)),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: Text('SL: $stock',
                                    style: const TextStyle(
                                        fontFeatures: [FontFeature.tabularFigures()])),
                              ),
                              _variantStatus(stock),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tồn kho')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // ✨ CHẾ ĐỘ BIẾN THỂ
    if (_variantMode && _lowOnly) {
      final visible = _filterVariantRows(_variantRows);
      return Scaffold(
        appBar: AppBar(
          title: const Text('Tồn kho (biến thể)'),
          actions: [
            IconButton(
              tooltip: 'Xem tất cả biến thể sắp hết',
              onPressed: _showAllLowVariants,
              icon: const Icon(Icons.list_alt),
            ),
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Đang hiển thị: Biến thể sắp hết (≤ $_lowThreshold)'
                '${_includeInactive ? '' : ' • chỉ sản phẩm đang bán'}'
                ' • Tổng: ${_variantRows.length}',
                style:
                    const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: TextField(
                controller: _searchCtl,
                decoration: InputDecoration(
                  hintText: 'Tìm theo mã / tên SP / biến thể…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchCtl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtl.clear();
                            setState(() {});
                          },
                        ),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: _vLoading
                  ? const Center(child: CircularProgressIndicator())
                  : (visible.isEmpty
                      ? const Center(child: Text('Không có biến thể sắp hết'))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final r = visible[i];
                            final stock = _stockOfOption(r.o);
                            final code = _codeOfProduct(r.p);
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _stockBorderColor(stock), // ⬅️ dùng lại
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  _thumbBox(r.p, size: 40),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(r.p.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 2),
                                        Text('Mã SP: $code • ${_optionLabel(r.o)}',
                                            style: const TextStyle(
                                                color: Colors.black54)),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: Text('SL: $stock',
                                        style: const TextStyle(
                                            fontFeatures: [
                                              FontFeature.tabularFigures()
                                            ])),
                                  ),
                                  _variantStatus(stock),
                                ],
                              ),
                            );
                          },
                        )),
            ),
          ],
        ),
      );
    }

    // ====== CHẾ ĐỘ SẢN PHẨM ======
    final pageRows = _pageSlice();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tồn kho'),
        actions: [
          IconButton(
            tooltip: 'Biến thể sắp hết',
            onPressed: _showAllLowVariants,
            icon: const Icon(Icons.list_alt),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;

          return Column(
            children: [
              if (_lowOnly)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Đang lọc: Sản phẩm có biến thể sắp hết (≤ $_lowThreshold)'
                    '${_includeInactive ? '' : ' • chỉ sản phẩm đang bán'}',
                    style: const TextStyle(
                        color: Colors.orange, fontWeight: FontWeight.w600),
                  ),
                ),

              // Tìm kiếm
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: TextField(
                  controller: _searchCtl,
                  decoration: InputDecoration(
                    hintText: 'Tìm theo mã / tên sản phẩm…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtl.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtl.clear();
                              _applyFilter();
                            },
                          ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => _applyFilter(),
                ),
              ),

              Expanded(
                child: isWide
                    ? _buildWideTable(context, pageRows, constraints.maxWidth)
                    : _buildNarrowList(context, pageRows),
              ),

              _buildPager(context, pageRows.length),
            ],
          );
        },
      ),
    );
  }

  // ---------------- UI blocks (Sản phẩm) ----------------

  Widget _buildWideTable(
      BuildContext context, List<Product> pageRows, double maxW) {
    if (pageRows.isEmpty) {
      return const Center(child: Text('Không có dữ liệu'));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: maxW),
        child: SingleChildScrollView(
          child: DataTable(
            sortColumnIndex: _sortColumnIndex,
            sortAscending: _sortAscending,
            columns: [
              const DataColumn(label: Text('Ảnh')),
              DataColumn(
                label: const Text('Mã SP'),
                onSort: (i, asc) => _sort<String>((p) => _codeOfProduct(p), i, asc),
              ),
              DataColumn(
                label: const Text('Tên SP'),
                onSort: (i, asc) => _sort<String>((p) => p.name, i, asc),
              ),
              DataColumn(
                numeric: true,
                label: const Text('Số lượng'),
                onSort: (i, asc) =>
                    _sort<num>((p) => _summaryTotalStock(p), i, asc), // ⬅️ tổng theo summary
              ),
              const DataColumn(label: Text('Trạng thái')),
            ],
            rows: pageRows.map((p) {
              final code = _codeOfProduct(p);
              return DataRow(
                onSelectChanged: (_) => _showVariants(p),
                cells: [
                  DataCell(_thumbBox(p, size: 40)),
                  DataCell(Text(code)),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Text(
                        p.name,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  DataCell(Text('${_summaryTotalStock(p)}')), // ⬅️ tổng theo summary
                  DataCell(_statusChip(p)),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildNarrowList(BuildContext context, List<Product> pageRows) {
    if (pageRows.isEmpty) {
      return const Center(child: Text('Không có dữ liệu'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      itemCount: pageRows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final p = pageRows[i];
        final code = _codeOfProduct(p);
        final stock = _summaryTotalStock(p);    // ⬅️ tổng theo summary
        final sev = _summarySeverity(p);        // ⬅️ màu theo severity
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: _borderBySeverity(sev), // ⬅️ màu viền
              width: 1.5,
            ),
          ),
          child: ListTile(
            onTap: () => _showVariants(p),
            leading: _thumbBox(p, size: 44),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            title: Text(
              p.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Mã SP: $code'),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('SL: $stock',
                    style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()])),
                const SizedBox(height: 6),
                _statusChip(p),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPager(BuildContext context, int pageCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          const Text('Dòng/trang:'),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: _rowsPerPage,
            items: _rowsPerPageOptions
                .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _rowsPerPage = v;
                _currentPage = 0;
              });
            },
          ),
          const Spacer(),
          Text(
            _view.isEmpty
                ? '0–0 / 0'
                : '${_currentPage * _rowsPerPage + 1}–${(_currentPage * _rowsPerPage + pageCount)} / ${_view.length}',
          ),
          IconButton(
            tooltip: 'Trang trước',
            onPressed:
                _currentPage > 0 ? () => setState(() => _currentPage--) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Trang sau',
            onPressed: (_currentPage + 1) * _rowsPerPage < _view.length
                ? () => setState(() => _currentPage++)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  // ---------------- helpers ----------------

  Widget _statusChip(Product p) {
    if (p.isActive == false && !_includeInactive) {
      return const _StatusChip(label: 'Ngưng bán', tone: _ChipTone.grey);
    }
    final sev = _summarySeverity(p);
    switch (sev) {
      case 3:
        return const _StatusChip(label: 'Hết', tone: _ChipTone.red);         // đỏ đậm
      case 2:
        return const _StatusChip(label: 'Sắp hết', tone: _ChipTone.red);     // đỏ nhạt
      case 1:
        return const _StatusChip(label: 'Sắp hết', tone: _ChipTone.orange);  // vàng
      default:
        return const _StatusChip(label: 'Còn', tone: _ChipTone.green);       // xanh
    }
  }
}

enum _ChipTone { green, orange, red, grey }

class _StatusChip extends StatelessWidget {
  final String label;
  final _ChipTone tone;
  const _StatusChip({required this.label, required this.tone});

  Color _bg(BuildContext ctx) {
    switch (tone) {
      case _ChipTone.green:
        return Colors.green.withOpacity(.15);
      case _ChipTone.orange:
        return Colors.orange.withOpacity(.15);
      case _ChipTone.red:
        return Colors.red.withOpacity(.15);
      case _ChipTone.grey:
        return Colors.grey.withOpacity(.2);
    }
  }

  Color _fg(BuildContext ctx) {
    switch (tone) {
      case _ChipTone.green:
        return Colors.green.shade700;
      case _ChipTone.orange:
        return Colors.orange.shade800;
      case _ChipTone.red:
        return Colors.red.shade700;
      case _ChipTone.grey:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _bg(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(color: _fg(context))),
    );
  }
}

class _VarRow {
  final Product p;
  final m.ProductOption o;
  _VarRow({required this.p, required this.o});
}
