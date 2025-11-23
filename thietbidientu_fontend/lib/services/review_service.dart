// lib/services/review_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models/review.dart';

class ReviewService {
  final String base = AppConfig.baseUrl;

  /// Tạo URL:
  /// - Nếu path bắt đầu bằng "/api/" -> ghép base + path
  /// - Ngược lại -> ghép base + "/api" + path
  Uri _build(String path) {
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = path.startsWith('/') ? path : '/$path';
    final String url = (p.startsWith('/api/')) ? '$b$p' : '$b/api$p';
    return Uri.parse(url);
  }

  Future<(List<Review>, ReviewStats)> getProductReviews(int productId) async {
  final url = _build('/reviews/product/$productId');
  final r = await http.get(url, headers: {'Accept': 'application/json'});
  if (r.statusCode != 200 && r.statusCode != 201) {
    print('GET ${url.toString()} -> ${r.statusCode} ${r.body}');
    throw Exception(r.body);
  }
  final m = json.decode(r.body);
  final stats = ReviewStats.fromJson(m['stats'] ?? {});
  final listRaw = (m['reviews'] as List?) ?? const [];
  final list = listRaw.map((e) => Review.fromJson(e)).toList();
  return (list, stats);
}


  /// trả về danh sách orderItemId còn được review (nếu rỗng là không được)
  Future<List<int>> canReview(int productId) async {
  final sp = await SharedPreferences.getInstance();
  final token = sp.getString('token') ??
      sp.getString('access_token') ??
      sp.getString('accessToken') ??
      sp.getString('jwt') ?? '';
  final url = _build('/reviews/product/$productId/can');
  final r = await http.get(url, headers: {
    'Accept': 'application/json',
    if (token.isNotEmpty) 'Authorization': 'Bearer $token',
  });
  if (r.statusCode != 200) {
    print('GET ${url.toString()} -> ${r.statusCode} ${r.body}');
    throw Exception(r.body);
  }
  final m = json.decode(r.body);
  final raw = (m['orderItemIds'] as List? ?? const []);
  return raw.map((e) => int.tryParse('$e') ?? 0).where((x) => x > 0).toList();
}


  /// Gửi đánh giá kiểu JSON (ảnh là URL)
  Future<int> addReview({
    required int orderItemId,
    required int rating,
    String? comment,
    List<String> imageUrls = const [],
  }) async {
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString('token') ??
        sp.getString('access_token') ??
        sp.getString('accessToken') ??
        sp.getString('jwt') ??
        '';
    final url = _build('/reviews');
    final r = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: json.encode({
        // gửi cặp key để BE bắt được dù là orderItemId hay OrderItemID
        'orderItemId': orderItemId,
        'OrderItemID': orderItemId,
        'rating': rating,
        'Rating': rating,
        'comment': comment,
        'Comment': comment,
        'images': imageUrls,
      }),
    );
    if (r.statusCode != 200) {
      // ignore: avoid_print
      print('POST ${url.toString()} -> ${r.statusCode} ${r.body}');
      throw Exception(r.body);
    }
    final m = json.decode(r.body);
    return m['reviewId'] as int;
  }

  /// Gửi đánh giá kèm ảnh (multipart/form-data)
  Future<int?> addReviewWithFiles({
  required int orderItemId,
  required int rating,
  String? comment,
  List<File> files = const [],
}) async {
  final sp = await SharedPreferences.getInstance();
  final token = sp.getString('token') ??
      sp.getString('access_token') ??
      sp.getString('accessToken') ??
      sp.getString('jwt') ?? '';
  final uri = _build('/reviews');
  final req = http.MultipartRequest('POST', uri);
  if (token.isNotEmpty) req.headers['Authorization'] = 'Bearer $token';

  req.fields['orderItemId'] = '$orderItemId';
  req.fields['OrderItemID'] = '$orderItemId';
  req.fields['rating'] = '$rating';
  req.fields['Rating'] = '$rating';
  if (comment != null && comment.trim().isNotEmpty) {
    final c = comment.trim();
    req.fields['comment'] = c;
    req.fields['Comment'] = c;
  }
  for (final f in files) {
    final filename = f.path.split(Platform.pathSeparator).last;
    req.files.add(await http.MultipartFile.fromPath('images', f.path, filename: filename));
  }

  final res = await req.send();
  final body = await res.stream.bytesToString();
  if (res.statusCode < 200 || res.statusCode >= 300) {
    print('MP POST ${uri.toString()} -> ${res.statusCode} $body');
    throw Exception('Gửi đánh giá thất bại (${res.statusCode}): $body');
  }
  try {
    final m = json.decode(body);
    return m is Map ? m['reviewId'] as int? : null;
  } catch (_) {
    return null; // BE không trả JSON cũng không sao
  }
}


  Future<void> updateReview(int reviewId, {int? rating, String? comment}) async {
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString('token') ??
        sp.getString('access_token') ??
        sp.getString('accessToken') ??
        sp.getString('jwt') ??
        '';
    final url = _build('/reviews/$reviewId');
    final r = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: json.encode({'rating': rating, 'comment': comment}),
    );
    if (r.statusCode != 200) {
      // ignore: avoid_print
      print('PUT ${url.toString()} -> ${r.statusCode} ${r.body}');
      throw Exception(r.body);
    }
  }

  Future<void> deleteReview(int reviewId) async {
    final sp = await SharedPreferences.getInstance();
    final token = sp.getString('token') ??
        sp.getString('access_token') ??
        sp.getString('accessToken') ??
        sp.getString('jwt') ??
        '';
    final url = _build('/reviews/$reviewId');
    final r = await http.delete(
      url,
      headers: {
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );
    if (r.statusCode != 200) {
      // ignore: avoid_print
      print('DELETE ${url.toString()} -> ${r.statusCode} ${r.body}');
      throw Exception(r.body);
    }
  }
}
