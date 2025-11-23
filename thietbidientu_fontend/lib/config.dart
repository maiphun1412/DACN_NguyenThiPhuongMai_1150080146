// lib/config.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

/// Có thể override khi run:
/// flutter run --dart-define=BASE_API=http://10.0.2.2:3000
/// flutter run --dart-define=PUBLIC_API=https://api.yourdomain.com
/// flutter run --dart-define=DEV_LAN=http://192.168.100.140:3000
const String _PUBLIC_FALLBACK =
    String.fromEnvironment('PUBLIC_API', defaultValue: '');
const String _DEV_LAN_HINT =
    String.fromEnvironment('DEV_LAN', defaultValue: '');

class AppConfig {
  static const _kSavedBase = 'app_base_url';
  static String? _cachedBase;

  /// Gọi ở main():
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   final base = await AppConfig.ensureBaseUrl();
  ///   print('BASE => $base');
  static Future<String> ensureBaseUrl() async {
    if (_cachedBase != null) return _cachedBase!;
    final sp = await SharedPreferences.getInstance();

    // 1) Ưu tiên URL đã lưu (Settings)
    final saved = sp.getString(_kSavedBase);
    if (await _isAlive(saved)) return _use(sp, saved!);

    // 2) Cho phép override build-time
    const buildDefined = String.fromEnvironment('BASE_API', defaultValue: '');
    if (buildDefined.isNotEmpty && await _isAlive(buildDefined)) {
      return _use(sp, buildDefined);
    }

    // 3) Các cầu nối dev phổ biến theo thứ tự “chắc ăn”
    final candidates = <String>[
      if (_isAndroid) 'http://10.0.2.2:3000', // Android Emulator
      if (_isAndroid) 'http://127.0.0.1:3000', // Khi dùng adb reverse
      if (_isWebOrIosSim) 'http://localhost:3000', // Web / iOS / Desktop
      if (_DEV_LAN_HINT.isNotEmpty) _DEV_LAN_HINT, // Gợi ý IP LAN
      ...await _lanGuesses(3000), // Thử IP LAN thực tế
    ];

    for (final u in candidates) {
      print('[AppConfig] Checking $u ...');
      if (await _isAlive(u)) {
        print('[AppConfig] ✅ Connected to $u');
        return _use(sp, u);
      }
    }

    // 4) Fallback công khai (HTTPS)
    if (_PUBLIC_FALLBACK.isNotEmpty && await _isAlive(_PUBLIC_FALLBACK)) {
      return _use(sp, _PUBLIC_FALLBACK);
    }

    // 5) Cuối cùng: localhost để dev còn thấy lỗi rõ
    print('[AppConfig] ⚠️ No server found, fallback to localhost:3000');
    return _use(sp, 'http://localhost:3000');
  }

  static String get baseUrl => _cachedBase ?? 'http://localhost:3000';

  static Future<void> setCustomBaseUrl(String url) async {
    final sp = await SharedPreferences.getInstance();
    if (await _isAlive(url)) {
      await sp.setString(_kSavedBase, url);
      _cachedBase = url;
    } else {
      throw Exception('Server $url không phản hồi /api/health');
    }
  }

  static Future<void> resetSavedBase() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kSavedBase);
    _cachedBase = null;
  }

  static const String categoryBase = '/api/categories';
  static String? authToken;

  static String resolveUrl(String path) {
    final base = baseUrl;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (base.endsWith('/') && path.startsWith('/')) return base + path.substring(1);
    if (!base.endsWith('/') && !path.startsWith('/')) return '$base/$path';
    return '$base$path';
  }

  // ---------------- helpers ----------------
  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get _isWebOrIosSim => kIsWeb || (!kIsWeb && Platform.isIOS && kDebugMode);

  static Future<bool> _isAlive(String? base) async {
    if (base == null || base.isEmpty) return false;
    try {
      final uri = Uri.parse(_join(base, '/api/health'));
      final res = await http.get(uri).timeout(const Duration(milliseconds: 2000));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static String _join(String base, String path) {
    if (base.endsWith('/') && path.startsWith('/')) return base + path.substring(1);
    if (!base.endsWith('/') && !path.startsWith('/')) return '$base/$path';
    return '$base$path';
  }

  static Future<List<String>> _lanGuesses(int port) async {
    final out = <String>{};
    try {
      final ifs = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final ni in ifs) {
        for (final ip in ni.addresses) {
          final s = ip.address;
          final isPrivate = s.startsWith('192.168.') || s.startsWith('10.') || s.startsWith('172.16.');
          if (!isPrivate) continue;
          final parts = s.split('.');
          if (parts.length == 4) {
            final gw = '${parts[0]}.${parts[1]}.${parts[2]}.1';
            out.add('http://$gw:$port');
          }
          out.add('http://$s:$port');
        }
      }
    } catch (_) {}
    return out.toList();
  }

  static String _use(SharedPreferences sp, String url) {
    _cachedBase = url;
    unawaited(sp.setString(_kSavedBase, url));
    return url;
  }
}
