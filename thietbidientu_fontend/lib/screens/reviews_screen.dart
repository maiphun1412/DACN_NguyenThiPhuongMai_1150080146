import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'package:thietbidientu_fontend/config.dart';

/// =====================
/// Màn hình: Tất cả đánh giá (AppBar & nút đen, nội dung nền trắng)
/// =====================
class ReviewsScreen extends StatefulWidget {
  final int productId;
  const ReviewsScreen({super.key, required this.productId});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

/* --------- Palette --------- */
// AppBar + nút (đen)
const _appbar = Color(0xFF0B0F13);
// Nền và thẻ (trắng)
const _bg = Colors.white;
const _card = Colors.white;
// Chữ & đường kẻ (tối/nhạt)
const _text = Color(0xFF111827);
const _muted = Color(0xFF6B7280);
const _line = Color(0xFFE5E7EB);
// Nhấn nhá
const _brand = _appbar;   // dùng đen cho nút/chip đã chọn
const _accent = Color(0xFF22C55E);
const _warning = Color(0xFFF59E0B);
const _error = Color(0xFFEF4444);

class _ReviewsScreenState extends State<ReviewsScreen> {
  bool _loading = true;
  String? _error;

  // dữ liệu
  List<Map<String, dynamic>> _all = [];
  double _avg = 0;
  int _total = 0;
  // phân bố theo sao: index 0: 1★, 4: 5★
  final List<int> _dist = [0, 0, 0, 0, 0];

  // lọc: null = tất cả, 1..5 = sao
  int? _filterStar;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final base = AppConfig.baseUrl.endsWith('/')
          ? AppConfig.baseUrl.substring(0, AppConfig.baseUrl.length - 1)
          : AppConfig.baseUrl;
      final url = Uri.parse('$base/api/reviews/product/${widget.productId}');

      final r = await http.get(url, headers: {'Accept': 'application/json'});
      if (r.statusCode != 200) {
        throw Exception('HTTP ${r.statusCode}');
      }

      final m = json.decode(r.body) as Map<String, dynamic>;
      final raw = (m['reviews'] as List? ?? [])
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();

      // Chuẩn hóa ảnh tuyệt đối + tên + thời gian + rating (đa dạng key)
      final normalized = raw.map((mm) {
        final imgs = (mm['images'] as List? ?? []).map((u) {
          final s = '$u';
          return s.startsWith('http') ? s : '$base$s';
        }).toList();
        mm['images'] = imgs;

        mm['__name'] =
            (mm['CustomerName'] ?? mm['FullName'] ?? mm['Email'] ?? 'Khách hàng').toString();

        // createdAt có thể là CreatedAt/createdAt/created_at
        mm['__created'] = mm['CreatedAt'] ?? mm['createdAt'] ?? mm['created_at'];

        // rating có thể là Rating/rating/Stars/stars
        final rawRt = mm['Rating'] ?? mm['rating'] ?? mm['Stars'] ?? mm['stars'] ?? 0;
        final rt = int.tryParse('$rawRt') ?? 0;
        mm['__rating'] = rt.clamp(0, 5);
        return mm;
      }).toList();

      // ===== Stats từ API (có thể thiếu) =====
      final stats = (m['stats'] as Map?) ?? {};
      double apiAvg = double.tryParse('${stats['AvgRating'] ?? stats['avg'] ?? 0}') ?? 0.0;
      int apiTotal = int.tryParse('${stats['TotalReviews'] ?? stats['total'] ?? 0}') ?? 0;

      // dist: {"1":n1..."5":n5} – có thể không có hoặc key kiểu khác
      final distRaw = (stats['dist'] as Map?) ?? (stats['distribution'] as Map?) ?? {};
      // chấp cả key số & chữ
      int readDist(dynamic key) => int.tryParse('${distRaw['$key'] ?? 0}') ?? 0;
      int d1 = readDist('1');
      int d2 = readDist('2');
      int d3 = readDist('3');
      int d4 = readDist('4');
      int d5 = readDist('5');

      // ===== Fallback: tự tính từ normalized =====
      final localDist = List<int>.filled(5, 0); // [1★..5★]
      int sumRating = 0;
      for (final r in normalized) {
        final rt = (r['__rating'] ?? 0) as int;
        if (rt >= 1 && rt <= 5) {
          localDist[rt - 1] += 1;
          sumRating += rt;
        }
      }
      final localTotal = normalized.length;
      final localAvg = localTotal > 0 ? sumRating / localTotal : 0.0;

      // Chọn nguồn dùng
      final apiDistSum = d1 + d2 + d3 + d4 + d5;
      final useDist = apiDistSum > 0 ? [d1, d2, d3, d4, d5] : localDist;
      final useTotal = apiTotal > 0 ? apiTotal : localTotal;
      final useAvg = (apiAvg > 0) ? apiAvg : localAvg;

      setState(() {
        _all = normalized;
        _avg = useAvg;
        _total = useTotal;
        _dist..setAll(0, useDist); // dist[0]=1★ ... dist[4]=5★
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filterStar == null) return _all;
    return _all.where((e) => (e['__rating'] ?? 0) == _filterStar).toList();
  }

  String _fmtDate(String? iso) {
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
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _appbar,
        elevation: 0,
        title: const Text(
          'Đánh giá',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _appbar))
          : _error != null
              ? _ErrorBox(message: 'Không tải được đánh giá.\n$_error', onRetry: _fetchAll)
              : RefreshIndicator(
                  color: Colors.white,
                  backgroundColor: _appbar,
                  onRefresh: _fetchAll,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                    children: [
                      _SummaryCard(avg: _avg, total: _total, dist: _dist),
                      const SizedBox(height: 12),
                      _FilterBar(
                        total: _total,
                        dist: _dist,
                        selected: _filterStar,
                        onChanged: (v) => setState(() => _filterStar = v),
                      ),
                      const SizedBox(height: 12),
                      if (_filtered.isEmpty)
                        _EmptyBox(
                          text: _filterStar == null
                              ? 'Chưa có đánh giá'
                              : 'Chưa có đánh giá ${_filterStar}★',
                        )
                      else
                        ..._filtered.map(
                          (r) => _ReviewTile(
                            name: r['__name'] ?? 'Khách hàng',
                            rating: r['__rating'] ?? 0,
                            date: _fmtDate(r['__created']?.toString()),
                            content: (r['Comment'] ?? '').toString(),
                            images: (r['images'] as List?)?.cast<String>() ?? const [],
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

/// ---------- Widgets nhỏ ----------

class _SummaryCard extends StatelessWidget {
  final double avg;
  final int total;
  /// dist[0]=1★, ... dist[4]=5★
  final List<int> dist;
  const _SummaryCard({required this.avg, required this.total, required this.dist});

  @override
  Widget build(BuildContext context) {
    final hasAny = dist.any((e) => e > 0);
    final maxCount = hasAny ? dist.reduce((a, b) => a > b ? a : b).toDouble() : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4))],
        border: Border.all(color: _line),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Điểm trung bình
          Expanded(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(avg.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: _text)),
                  const SizedBox(height: 6),
                  _StarsRow(rating: avg.round(), size: 18),
                  const SizedBox(height: 8),
                  Text('$total đánh giá', style: const TextStyle(color: _muted)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Phân bố 5★ -> 1★ (mỗi dòng chỉ 1 thanh)
          Expanded(
            flex: 7,
            child: Column(
              children: List.generate(5, (i) {
                final star  = 5 - i;
                final count = (star >= 1 && star <= 5) ? dist[star - 1] : 0;
                final value = maxCount == 0 ? 0.0 : (count / maxCount);

                Color barColor;
                if (star >= 4) {
                  barColor = _accent;         // xanh cho 4-5★
                } else if (star == 3) {
                  barColor = _warning;        // vàng cho 3★
                } else {
                  barColor = _error;          // đỏ cho 1-2★
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text('$star★', style: const TextStyle(color: _muted, fontSize: 12)),
                      ),
                      const SizedBox(width: 8),

                      // ✅ 1 thanh duy nhất
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: value.clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: const Color(0xFFF3F4F6),
                            valueColor: AlwaysStoppedAnimation<Color>(barColor),
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),
                      SizedBox(
                        width: 28,
                        child: Text('$count',
                            textAlign: TextAlign.right,
                            style: const TextStyle(color: _muted, fontSize: 12)),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}



class _FilterBar extends StatelessWidget {
  final int total;
  /// dist[0]=1★, ... dist[4]=5★
  final List<int> dist;
  final int? selected;
  final ValueChanged<int?> onChanged;
  const _FilterBar({
    required this.total,
    required this.dist,
    required this.selected,
    required this.onChanged,
  });

  Widget _chip({required String label, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _brand : _card,
          border: Border.all(color: selected ? Colors.transparent : _line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _chip(
        label: 'Tất cả ($total)',
        selected: selected == null,
        onTap: () => onChanged(null),
      ),
      const SizedBox(width: 8),
      for (int star = 5; star >= 1; star--) ...[
        _chip(
          label: '${star}★ (${dist[star - 1]})',
          selected: selected == star,
          onTap: () => onChanged(star),
        ),
        const SizedBox(width: 8),
      ]
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: chips),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final String name;
  final int rating;
  final String date;
  final String content;
  final List<String> images;
  const _ReviewTile({
    required this.name,
    required this.rating,
    required this.date,
    required this.content,
    required this.images,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header: avatar + name + stars + date
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFE5E7EB),
                child: Text(
                  name.isNotEmpty ? name.trim()[0].toUpperCase() : 'U',
                  style: const TextStyle(color: _text, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        color: _text, fontWeight: FontWeight.w700, fontSize: 14.5)),
              ),
              _StarsRow(rating: rating, size: 16),
              if (date.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(date, style: const TextStyle(color: _muted, fontSize: 12)),
              ]
            ],
          ),
          const SizedBox(height: 10),
          if (content.trim().isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                border: Border.all(color: _line),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(content, style: const TextStyle(color: _text, height: 1.4)),
            ),
          if (images.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: images.take(6).map((u) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    u,
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 90,
                      height: 90,
                      alignment: Alignment.center,
                      color: const Color(0xFFF3F4F6),
                      child: const Icon(Icons.broken_image_outlined, color: _muted),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _StarsRow extends StatelessWidget {
  final int rating; // 0..5
  final double size;
  final double spacing;

  const _StarsRow({
    required this.rating,
    this.size = 14,
    this.spacing = 0,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final filled = i < rating;
          return Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : spacing),
            child: Icon(
              filled ? Icons.star : Icons.star_border,
              size: size,
              color: _warning,
            ),
          );
        }),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ôi, có lỗi rồi!',
                style: TextStyle(color: _text, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(color: _muted)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Thử lại'),
            )
          ],
        ),
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final String text;
  const _EmptyBox({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          const Icon(Icons.inbox_outlined, color: _muted),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(color: _muted))),
        ],
      ),
    );
  }
}
