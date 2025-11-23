// lib/screens/admin/admin_dashboard.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:thietbidientu_fontend/services/api_service.dart';

const _brand = Color(0xFF353839);

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _api = ApiService();

  bool _loading = true;
  String? _error;

  num _revenueToday = 0;
  int _ordersToday = 0;
  int _lowStock = 0;
  int _newCustomers = 0;

  // ✨ cấu hình đếm tồn kho thấp (đồng bộ với StockScreen)
  int _lowThreshold = 10;
  bool _includeInactive = false;

  List<int> _orders7d = const [];
  List<String> _labels7d = const [];

  /// 'day' | 'month'
  String _gran = 'day';

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ---------- helpers parse ----------
  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return num.tryParse(v)?.toInt() ?? 0;
    return 0;
  }

  num _toNum(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? 0;
    return 0;
  }

  bool _toBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase().trim();
      return s == 'true' || s == '1' || s == 'yes';
    }
    return false;
  }

  String _dowVN(DateTime d) {
    switch (d.weekday) {
      case DateTime.monday:
        return 'T2';
      case DateTime.tuesday:
        return 'T3';
      case DateTime.wednesday:
        return 'T4';
      case DateTime.thursday:
        return 'T5';
      case DateTime.friday:
        return 'T6';
      case DateTime.saturday:
        return 'T7';
      default:
        return 'CN';
    }
  }

  String _fmtMonth(String isoYYYYMM) {
    // "2025-10" -> "10/25"
    if (isoYYYYMM.length >= 7 && isoYYYYMM.contains('-')) {
      final mm = isoYYYYMM.substring(5, 7);
      final yy = isoYYYYMM.substring(2, 4);
      return '$mm/$yy';
    }
    return isoYYYYMM;
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      Map<String, dynamic> data;

      if (_gran == 'month') {
        // Gọi dạng tháng (6 tháng gần đây)
        final resp = await _api.get('/admin/dashboard', params: {
          'granularity': 'month',
          'months': 6,
          // ✨ truyền tham số tồn kho để BE đếm đúng theo biến thể
          'lowThreshold': _lowThreshold,
          'includeInactive': _includeInactive ? 1 : 0,
        });
        data = (resp ?? {}) as Map<String, dynamic>;
      } else {
        // Chế độ ngày
        data = await _api.getAdminDashboard(
          days: 7,
          // ✨ truyền tham số tồn kho để BE đếm đúng theo biến thể
          lowThreshold: _lowThreshold,
          includeInactive: _includeInactive,
        );
      }

      final k = (data['kpis'] ?? {}) as Map<String, dynamic>;
      final s = (data['ordersSeries'] ?? {}) as Map<String, dynamic>;
      final rawLabels = (s['labels'] as List?)?.cast<String>() ?? const [];
      final rawValues = (s['values'] as List?) ?? const [];

      setState(() {
        _revenueToday = _toNum(k['revenueToday']);
        _ordersToday = _toInt(k['ordersToday']);
        _lowStock = _toInt(k['lowStock']);
        _newCustomers = _toInt(k['newCustomers']);

        // ✨ lấy cấu hình đếm tồn thấp từ API (đa dạng khoá, có fallback)
        final inv = (data['inventory'] as Map?) ?? const {};
        _lowThreshold = _toInt(
          k['lowThreshold'] ??
              data['lowThreshold'] ??
              inv['lowThreshold'] ??
              10,
        );
        _includeInactive = _toBool(
          k['includeInactive'] ??
              data['includeInactive'] ??
              inv['includeInactive'] ??
              false,
        );

        _orders7d = rawValues.map(_toInt).toList();

        if (_gran == 'month') {
          _labels7d = rawLabels.map((e) => _fmtMonth(e)).toList();
        } else {
          _labels7d = rawLabels.map((e) {
            DateTime? dt;
            try {
              dt = DateTime.parse(e);
            } catch (_) {}
            return dt != null ? _dowVN(dt) : e;
          }).toList();
        }

        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // ---------- điều hướng ----------
  void _goLowStock() {
    Navigator.pushNamed(context, '/admin/stock', arguments: {
      'lowOnly': true,
      'variantMode': true, // ✨ lọc theo biến thể
      'threshold': _lowThreshold,
      'includeInactive': _includeInactive,
    });
  }

  void _goOrdersToday() {
    final today = DateTime.now();
    final ymd = _ymd(today);
    Navigator.pushNamed(context, '/admin/orders', arguments: {
      'todayOnly': true,
      'date': ymd,
      'title': 'Đơn hàng (hôm nay)',
    });
  }

  void _goOrdersThisMonth() {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, 1);
    final nextMonth = (now.month == 12)
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);
    final last = nextMonth.subtract(const Duration(days: 1));

    Navigator.pushNamed(context, '/admin/orders', arguments: {
      'from': _ymd(first),
      'to': _ymd(last),
      'title': 'Đơn hàng (tháng này)',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _brand,
        title: const Text('Trang Quản Trị'),
        actions: [
          IconButton(
            tooltip: 'Đăng nhập (khách hàng)',
            icon: const Icon(Icons.login),
            onPressed: () => Navigator.pushNamed(context, '/login'),
          ),
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
          const SizedBox(width: 4),
        ],
      ),
      backgroundColor: const Color(0xFFF4F6FA),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 36, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(
                          'Không tải được báo cáo:\n$_error',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : Center(
                  // ✅ Trên web: bó chiều rộng nội dung ở giữa, tối đa 1100px
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // ===== Stats row =====
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _StatCard(
                              title: _gran == 'month'
                                  ? 'Doanh thu tháng này'
                                  : 'Doanh thu hôm nay',
                              value: _currency(_revenueToday),
                              icon: Icons.payments_outlined,
                              color: Colors.teal,
                            ),
                            _StatCard(
                              title: _gran == 'month'
                                  ? 'Đơn tháng này'
                                  : 'Đơn hôm nay',
                              value: '$_ordersToday',
                              icon: Icons.receipt_long_outlined,
                              color: Colors.indigo,
                              onTap: _ordersToday > 0
                                  ? (_gran == 'day'
                                      ? _goOrdersToday
                                      : _goOrdersThisMonth)
                                  : null,
                            ),
                            _StatCard(
                              title: 'Tồn kho thấp',
                              value: '$_lowStock',
                              icon: Icons.inventory_2_rounded,
                              color: Colors.orange,
                              onTap:
                                  _lowStock > 0 ? _goLowStock : null,
                            ),
                            _StatCard(
                              title: 'Khách mới',
                              value: '$_newCustomers',
                              icon: Icons.person_add_alt_1_rounded,
                              color: Colors.pink,
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ===== Toggle Ngày / Tháng =====
                        Row(
                          children: [
                            const Text('Chế độ:',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Ngày'),
                              selected: _gran == 'day',
                              onSelected: (v) {
                                if (!v || _gran == 'day') return;
                                setState(() => _gran = 'day');
                                _load();
                              },
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Tháng'),
                              selected: _gran == 'month',
                              onSelected: (v) {
                                if (!v || _gran == 'month') return;
                                setState(() => _gran = 'month');
                                _load();
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // ===== Orders chart =====
                        _Panel(
                          title: _gran == 'month'
                              ? 'Đơn hàng 6 tháng gần đây'
                              : 'Đơn hàng 7 ngày qua',
                          child: _OrdersChart(
                            values: _orders7d,
                            labels: _labels7d,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ===== Quick actions =====
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics:
                              const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.02,
                          children: const [
                            _NavTile(
                              title: 'Quản lý kho',
                              route: '/admin/warehouse',
                              icon: Icons.warehouse_rounded,
                            ),
                            _NavTile(
                              title: 'Tồn kho',
                              route: '/admin/stock',
                              icon: Icons.storage_rounded,
                            ),
                            _NavTile(
                              title: 'Loại sản phẩm',
                              route: '/admin/categories',
                              icon: Icons.category_rounded,
                            ),
                            _NavTile(
                              title: 'Sản phẩm',
                              route: '/admin/products',
                              icon: Icons.shopping_bag_rounded,
                            ),
                            _NavTile(
                              title: 'Nhà cung cấp',
                              route: '/admin/suppliers',
                              icon: Icons.handshake_rounded,
                            ),
                            _NavTile(
                              title: 'Shipper',
                              route: '/admin/shippers',
                              icon:
                                  Icons.delivery_dining_rounded,
                            ),
                            _NavTile(
                              title: 'Đơn giao hàng',
                              route: '/admin/delivery',
                              icon: Icons.local_shipping_rounded,
                              args: {
                                'status': 'SHIPPED',
                                'title':
                                    'Đơn giao hàng (đang giao)',
                              },
                            ),
                            _NavTile(
                              title: 'Quản lý người dùng',
                              route: '/admin/users',
                              icon: Icons.people_alt_rounded,
                            ),
                            _NavTile(
                              title: 'Mã giảm giá',
                              route: '/admin/coupons',
                              icon: Icons
                                  .confirmation_number_rounded,
                            ),
                            _NavTile(
                              title: 'Cài đặt hệ thống',
                              route: '/admin/settings',
                              icon: Icons
                                  .settings_suggest_rounded,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

/* ================== Widgets ================== */

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final itemW = (w - 16 * 2 - 12) / 2; // 2 cột trên mobile
    final card = Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54)),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _brand),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return SizedBox(
      width: itemW,
      child: onTap == null
          ? card
          : InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: card,
            ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _Panel(
      {required this.title, this.subtitle, required this.child});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _brand)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!,
                  style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.black54)),
            ],
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _OrdersChart extends StatelessWidget {
  final List<int> values;
  final List<String> labels;
  const _OrdersChart(
      {required this.values, required this.labels});
  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text('Chưa có dữ liệu')),
      );
    }
    final maxV =
        values.reduce((a, b) => a > b ? a : b).toDouble();
    final minV =
        values.reduce((a, b) => a < b ? a : b).toDouble();
    return SizedBox(
      height: 260,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (maxV + 5).toDouble(),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem:
                  (group, groupIndex, rod, rodIndex) =>
                      BarTooltipItem(
                '${labels[group.x.toInt()]}: ${rod.toY.toInt()} đơn',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              tooltipBgColor: Colors.black87,
            ),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(
                sideTitles:
                    SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles:
                    SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black45),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  return Padding(
                    padding:
                        const EdgeInsets.only(top: 6),
                    child: Text(
                      i >= 0 && i < labels.length
                          ? labels[i]
                          : '',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval:
                (maxV / 4).clamp(1, 999),
            getDrawingHorizontalLine: (v) =>
                FlLine(
                  color: Colors.black12,
                  strokeWidth: 1,
                ),
          ),
          borderData: FlBorderData(show: false),
          extraLinesData:
              const ExtraLinesData(horizontalLines: []),
          barGroups: [
            for (int i = 0; i < values.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: values[i].toDouble(),
                    width: 18,
                    borderRadius:
                        BorderRadius.circular(6),
                    gradient: LinearGradient(
                      colors: values[i] == maxV
                          ? [
                              Colors.green.shade400,
                              Colors.green.shade700
                            ]
                          : values[i] == minV
                              ? [
                                  Colors.red.shade300,
                                  Colors.red.shade600
                                ]
                              : [
                                  Colors
                                      .blueGrey.shade300,
                                  Colors
                                      .blueGrey.shade700
                                ],
                      begin:
                          Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final String route;
  final Object? args;

  const _NavTile({
    required this.title,
    required this.icon,
    required this.route,
    this.args,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            Navigator.pushNamed(context, route, arguments: args),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: _brand),
              const SizedBox(height: 8),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple VND formatter (12.850.000đ)
String _currency(num v) {
  final s = v.toStringAsFixed(0);
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final rev = s.length - i;
    b.write(s[i]);
    if (rev > 1 && rev % 3 == 1) b.write('.');
  }
  return '${b.toString()}đ';
}
