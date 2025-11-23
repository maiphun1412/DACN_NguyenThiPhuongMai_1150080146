// lib/screens/notification_screen.dart
import 'dart:async'; // ⬅️ để dùng Timer
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:thietbidientu_fontend/config.dart'; // có sẵn trong project

/* ==========================
   Model tối giản
========================== */
class AppNotification {
  final int id;
  final String type;
  final String title;
  final String? message;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? data;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.createdAt,
    required this.isRead,
    this.message,
    this.data,
  });

  // ⬇️ helper parse nhiều định dạng thời gian SQL/ISO
  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    final s0 = v.toString().trim();
    if (s0.isEmpty) return DateTime.now();

    // Chuẩn hoá nhanh: cắt mili-giây về 3 chữ số nếu có
    String s = s0;
    final msFix = RegExp(r'\.(\d{4,})'); // .SSSS hoặc dài hơn
    if (msFix.hasMatch(s)) {
      s = s.replaceAllMapped(msFix, (m) => '.${m[1]!.substring(0, 3)}');
    }

    // 1) ISO-8601 chuẩn (có 'T', có/không 'Z')
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso.isUtc ? iso.toLocal() : iso;

    // 2) SQL Server kiểu "yyyy-MM-dd HH:mm:ss.SSS" (không timezone)
    try {
      final d1 = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').parseStrict(s);
      return d1;
    } catch (_) {}

    // 3) "yyyy-MM-dd HH:mm:ss" (không mili)
    try {
      final d2 = DateFormat('yyyy-MM-dd HH:mm:ss').parseStrict(s);
      return d2;
    } catch (_) {}

    // 4) Có offset: "yyyy-MM-dd HH:mm:ss.SSS Z" hoặc "yyyy-MM-dd HH:mm:ss Z"
    // Ví dụ: "2025-11-09 13:45:00.000 +0700" hoặc "+07:00"
    // Chuẩn hoá dấu ":" trong offset nếu có
    final reOffset = RegExp(r'([+\-]\d{2}):?(\d{2})$');
    final sNorm = s.replaceAllMapped(reOffset, (m) => '${m[1]}${m[2]}');

    try {
      final d3 = DateFormat('yyyy-MM-dd HH:mm:ss.SSS Z').parseStrict(sNorm, true);
      return d3.toLocal();
    } catch (_) {}
    try {
      final d4 = DateFormat('yyyy-MM-dd HH:mm:ss Z').parseStrict(sNorm, true);
      return d4.toLocal();
    } catch (_) {}

    // 5) Epoch milliseconds/seconds?
    final n = num.tryParse(s);
    if (n != null) {
      if (s.length > 10) {
        // milliseconds
        return DateTime.fromMillisecondsSinceEpoch(n.toInt()).toLocal();
      } else {
        // seconds
        return DateTime.fromMillisecondsSinceEpoch(n.toInt() * 1000).toLocal();
      }
    }

    // fallback cuối cùng
    return DateTime.now();
  }

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic>? _data;
    if (j['DataJson'] != null) {
      if (j['DataJson'] is String) {
        try {
          _data = jsonDecode(j['DataJson']);
        } catch (_) {
          _data = null;
        }
      } else if (j['DataJson'] is Map) {
        _data = Map<String, dynamic>.from(j['DataJson']);
      }
    }

    final isRead = (j['IsRead'] is bool) ? j['IsRead'] : j['IsRead'] == 1;

    // ⬇️ dùng parser “trâu” ở trên
    final created = _parseDate(j['CreatedAt']);

    return AppNotification(
      id: j['NotificationID'] ?? j['Id'] ?? 0,
      type: (j['Type'] ?? '').toString(),
      title: j['Title'] ?? '',
      message: j['Message'],
      createdAt: created,
      isRead: isRead,
      data: _data,
    );
  }
}

/* ==========================
   Screen
========================== */
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final List<AppNotification> _items = [];
  bool _loading = true;
  String? _error;

  Timer? _ticker; // timer để tự cập nhật mỗi phút

  @override
  void initState() {
    super.initState();
    _fetch();
    _startTicker(); // bắt đầu đồng hồ
  }

  @override
  void dispose() {
    _ticker?.cancel(); // hủy khi rời màn để tránh leak
    super.dispose();
  }

  /// Căn tick về đúng đầu phút cho mượt, sau đó mỗi phút setState 1 lần
  void _startTicker() {
    _ticker?.cancel();
    final now = DateTime.now();
    final msToNextMinute = 60000 - (now.second * 1000 + now.millisecond);
    Future.delayed(Duration(milliseconds: msToNextMinute), () {
      if (!mounted) return;
      setState(() {}); // cập nhật lần đầu
      _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    });
  }

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token'); // <-- đổi nếu bạn lưu key khác
    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ---- Helpers: đảm bảo có userId ----
  int? _userIdFromJwt(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final Map<String, dynamic> j = jsonDecode(payload);
      final v = j['userId'] ?? j['UserID'] ?? j['id'];
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<int> _ensureUserId() async {
    final prefs = await SharedPreferences.getInstance();

    // 1) SharedPreferences
    final sp = prefs.getInt('userId') ?? prefs.getInt('UserID');
    if (sp != null) return sp;

    // 2) decode JWT
    final token = prefs.getString('token');
    if (token != null) {
      final fromJwt = _userIdFromJwt(token);
      if (fromJwt != null) {
        await prefs.setInt('userId', fromJwt);
        return fromJwt;
      }
    }

    // 3) fallback gọi /api/users/me nếu BE có
    try {
      final base = await AppConfig.ensureBaseUrl();
      final meUrl = Uri.parse('$base/api/users/me');
      final r = await http.get(meUrl, headers: await _headers());
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body);
        final v = j['UserID'] ?? j['id'] ?? j['userId'];
        final uid = (v is int) ? v : int.tryParse('$v');
        if (uid != null) {
          await prefs.setInt('userId', uid);
          return uid;
        }
      }
    } catch (_) {}

    throw Exception('Thiếu userId (chưa đăng nhập hoặc token không hợp lệ)');
  }

  Future<void> _fetch() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      final base = await AppConfig.ensureBaseUrl();

      final uid = await _ensureUserId();

      final url = Uri.parse('$base/api/notifications?userId=$uid'); // dùng query theo BE hiện tại
      final r = await http.get(url, headers: await _headers());
      if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
      final List data = json.decode(r.body);
      final list = data.map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
      setState(() {
        _items
          ..clear()
          ..addAll(list);
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(int id) async {
    try {
      final base = await AppConfig.ensureBaseUrl();
      final uid = await _ensureUserId();

      final url = Uri.parse('$base/api/notifications/$id/read?userId=$uid');
      await http.post(url, headers: await _headers());
      final i = _items.indexWhere((x) => x.id == id);
      if (i != -1) {
        setState(() => _items[i] = AppNotification(
              id: _items[i].id,
              type: _items[i].type,
              title: _items[i].title,
              createdAt: _items[i].createdAt,
              isRead: true,
              message: _items[i].message,
              data: _items[i].data,
            ));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Thông báo"),
        centerTitle: true,
        backgroundColor: const Color(0xFF353839),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF4F6FA),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      ));
    }
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 24),
          Center(child: Text('Không tải được thông báo:\n$_error', textAlign: TextAlign.center)),
          const SizedBox(height: 12),
          Center(
            child: TextButton(onPressed: _fetch, child: const Text('Thử lại')),
          ),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 40),
          Center(child: Text('Chưa có thông báo')),
        ],
      );
    }
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 0),
      itemBuilder: (context, index) {
        final n = _items[index];
        final (icon, color) = _iconOf(n.type);
        final time = _relativeTime(n.createdAt);
        final titleStyle = TextStyle(
          fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
          color: n.isRead ? Colors.black87 : const Color(0xFF111827),
        );

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            onTap: () async {
              await _markRead(n.id);
              // TODO: điều hướng theo type nếu muốn
            },
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color),
            ),
            title: Text(n.title, style: titleStyle),
            subtitle: Text(n.message ?? ''),
            trailing: Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        );
      },
    );
  }

  // Gán icon & màu theo type
  (IconData, Color) _iconOf(String type) {
    final t = type.toUpperCase();
    if (t.contains('PAYMENT')) {
      return (Icons.receipt_long, Colors.green);
    } else if (t.contains('DELIVERED') || t.contains('ORDER')) {
      return (CupertinoIcons.cart_fill, Colors.orange);
    } else if (t.contains('PROMO') || t.contains('COUPON')) {
      return (Icons.local_offer, Colors.blue);
    }
    return (Icons.notifications, Colors.purple);
  }

  // Đếm thời gian thực:
  // < 10s: "vừa xong"
  // < 60s: "Xs trước"
  // < 60m: "X phút trước"
  // < 24h: "X giờ trước"
  // < 7d : "X ngày trước"
  // >= 7d: "dd/MM/yyyy"
  String _relativeTime(DateTime dt) {
    final now = DateTime.now();
    var diff = now.difference(dt);
    if (diff.isNegative) diff = Duration.zero;

    if (diff.inSeconds < 10) return 'vừa xong';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s trước';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours   < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays    < 7)  return '${diff.inDays} ngày trước';

    return DateFormat('dd/MM/yyyy').format(dt);
  }
}
