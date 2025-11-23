import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/review_service.dart';

class WriteReviewScreen extends StatefulWidget {
  static const route = '/writeReview';
  const WriteReviewScreen({super.key});

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  final _svc = ReviewService();

  int _rating = 5;
  final _cmt = TextEditingController();
  bool _busy = false;

  // --- resolve orderItemId / productId ---
  int? _orderItemId;
  int? _productIdForResolve;
  bool _resolving = false;
  String? _resolveMsg;
  bool _didInitArgs = false;

  // nhiều đơn hợp lệ
  List<int> _candidateOrderItemIds = const [];

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _picked = [];
  static const _maxImages = 5;

  @override
  void dispose() {
    _cmt.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitArgs) return;
    _didInitArgs = true;
    _initArgsAndMaybeResolve(context);
  }

  void _initArgsAndMaybeResolve(BuildContext context) {
    final args = (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};

    _orderItemId = _pickInt(args, const [
      'orderItemId',
      'OrderItemID',
      'order_item_id',
      'orderItemID',
      'id',
    ]);

    _productIdForResolve = _pickInt(args, const [
      'productId',
      'ProductID',
      'productID',
      'pid',
    ]);

    if (_orderItemId == null && _productIdForResolve != null) {
      _resolveOrderItemId();
    }
    setState(() {});
  }

  int? _pickInt(Map args, List<String> keys) {
    for (final k in keys) {
      if (!args.containsKey(k)) continue;
      final v = int.tryParse('${args[k]}');
      if (v != null && v > 0) return v;
    }
    return null;
  }

  Future<void> _resolveOrderItemId() async {
    setState(() {
      _resolving = true;
      _resolveMsg = null;
      _candidateOrderItemIds = const [];
    });
    try {
      final p = _productIdForResolve!;
      final canIds = await _svc.canReview(p); // List<int>
      if (canIds.isEmpty) {
        _resolveMsg =
            'Bạn chưa mua hoặc đơn hàng chưa đủ điều kiện để đánh giá sản phẩm này.';
      } else if (canIds.length == 1) {
        _orderItemId = canIds.first;
      } else {
        _candidateOrderItemIds = canIds;
      }
    } catch (e) {
      _resolveMsg = 'Không lấy được quyền đánh giá: $e';
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  // ========== CHỌN ORDER ITEM WHEN MULTIPLE ==========
  Future<int?> _pickOrderItemId(List<int> ids) async {
    return showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Chọn đơn hàng để đánh giá',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            const Divider(height: 1),
            ...ids.map((id) => ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text('Đơn hàng #$id'),
                  onTap: () => Navigator.pop(context, id),
                )),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  // ======= pick images =======
  Future<void> _pickFromGallery() async {
    try {
      final left = _maxImages - _picked.length;
      if (left <= 0) {
        _toast('Bạn đã chọn tối đa $_maxImages ảnh.');
        return;
      }
      final imgs = await _picker.pickMultiImage(imageQuality: 85);
      if (imgs.isEmpty) return;

      setState(() {
        for (final x in imgs) {
          if (_picked.length >= _maxImages) break;
          _picked.add(x);
        }
      });
    } catch (e) {
      _toast('Không mở được thư viện: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (x == null) return;
      if (_picked.length >= _maxImages) {
        _toast('Bạn đã chọn tối đa $_maxImages ảnh.');
        return;
      }
      setState(() => _picked.add(x));
    } catch (e) {
      _toast('Không mở được camera: $e');
    }
  }

  void _removeAt(int idx) {
    setState(() => _picked.removeAt(idx));
  }

  // ======= THANK-YOU SHEET THEN POP BACK =======
  Future<void> _showThanksSheetAndPop() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 56, color: Colors.green),
                const SizedBox(height: 12),
                const Text(
                  'Cảm ơn bạn đã đánh giá!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ý kiến của bạn giúp chúng tôi cải thiện chất lượng sản phẩm & dịch vụ.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Về trang theo dõi sản phẩm'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    Navigator.pop(context, true); // quay lại trang trước (theo dõi sản phẩm)
  }

  Future<void> _submit(int orderItemId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final files = _picked.map((x) => File(x.path)).toList();

      await _svc.addReviewWithFiles(
        orderItemId: orderItemId,
        rating: _rating,
        comment: _cmt.text.trim(),
        files: files,
      );

      if (!mounted) return;
      // Hiện màn cảm ơn rồi quay lại trang trước
      await _showThanksSheetAndPop();
    } catch (e) {
      if (!mounted) return;
      _toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasId = _orderItemId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Viết đánh giá'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!hasId) _warnMissingOrderItem(),
            if (_resolving) ...[
              const SizedBox(height: 12),
              const _ResolvingBox(),
            ],

            if (_candidateOrderItemIds.isNotEmpty) ...[
              const SizedBox(height: 12),
              _card(
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Có nhiều đơn hàng đủ điều kiện đánh giá.\nHãy chọn một đơn để gắn đánh giá.',
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final chosen = await _pickOrderItemId(_candidateOrderItemIds);
                        if (chosen != null) {
                          setState(() {
                            _orderItemId = chosen;
                          });
                        }
                      },
                      icon: const Icon(Icons.list_alt_outlined, size: 18),
                      label: const Text('Chọn'),
                    ),
                  ],
                ),
              ),
            ],

            if (_orderItemId != null) ...[
              const SizedBox(height: 12),
              _card(
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Đơn hàng được đánh giá: #${_orderItemId!}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    if (_candidateOrderItemIds.isNotEmpty)
                      TextButton(
                        onPressed: () async {
                          final chosen = await _pickOrderItemId(_candidateOrderItemIds);
                          if (chosen != null) setState(() => _orderItemId = chosen);
                        },
                        child: const Text('Đổi'),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            _ratingCard(),
            const SizedBox(height: 12),
            _commentCard(),
            const SizedBox(height: 12),
            _imagesCard(),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: hasId ? () => _submit(_orderItemId!) : null,
                icon: const Icon(Icons.send),
                label: Text(_busy ? 'Đang gửi...' : 'Gửi đánh giá'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _warnMissingOrderItem() {
    final fromProduct = _productIdForResolve != null;
    final msg = _resolveMsg ??
        (fromProduct
            ? 'Đang kiểm tra quyền đánh giá từ sản phẩm #$_productIdForResolve…'
            : 'Thiếu orderItemId. Hãy mở màn này từ "Đơn hàng của tôi" → ⋮ → "Đánh giá sản phẩm",\n'
              'hoặc từ trang chi tiết sản phẩm (đã mua) để hệ thống tự xác định.');

    return _card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Đánh giá tổng thể', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            children: List.generate(
              5,
              (i) => IconButton(
                splashRadius: 22,
                icon: Icon(
                  i < _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 30,
                ),
                onPressed: () => setState(() => _rating = i + 1),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _tag('Đóng gói chắc chắn'),
              _tag('Giao nhanh'),
              _tag('Đúng mẫu mã'),
              _tag('Hiệu năng tốt'),
              _tag('Pin ổn'),
              _tag('Màn hình đẹp'),
              _tag('Âm thanh tốt'),
              _tag('Giá hợp lý'),
              _tag('Sẽ mua lại'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _commentCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nội dung đánh giá', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(
            controller: _cmt,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText:
                  'Chia sẻ trải nghiệm sử dụng (chất lượng, hiệu năng, pin, màn hình, âm thanh, v.v.)…',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagesCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Ảnh minh họa', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              Text('${_picked.length}/$_maxImages',
                  style: const TextStyle(color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _pickerTile(
                icon: Icons.photo_library_outlined,
                label: 'Thư viện',
                onTap: _pickFromGallery,
              ),
              _pickerTile(
                icon: Icons.photo_camera_outlined,
                label: 'Camera',
                onTap: _takePhoto,
              ),
              ...List.generate(_picked.length, (i) {
                final x = _picked[i];
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(x.path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Center(child: Icon(Icons.broken_image)),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -6,
                      top: -6,
                      child: InkWell(
                        onTap: () => _removeAt(i),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          padding: const EdgeInsets.all(3),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Chọn tối đa 5 ảnh. Vui lòng không chia sẻ thông tin cá nhân trong ảnh.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE9E9E9)),
      ),
      child: child,
    );
  }

  Widget _tag(String text) {
    return ChoiceChip(
      label: Text(text),
      selected: false,
      onSelected: (_) {
        if (_cmt.text.isEmpty) {
          _cmt.text = text;
        } else {
          _cmt.text = '${_cmt.text.trim()} • $text';
        }
        setState(() {});
      },
    );
  }

  Widget _pickerTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 86,
        height: 86,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: Colors.black87),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _ResolvingBox extends StatelessWidget {
  const _ResolvingBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE0B2)),
      ),
      child: Row(
        children: const [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Expanded(child: Text('Đang kiểm tra quyền đánh giá…')),
        ],
      ),
    );
  }
}
