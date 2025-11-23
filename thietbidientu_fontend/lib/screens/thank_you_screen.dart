// lib/screens/thank_you_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';

class ThankYouScreen extends StatefulWidget {
  const ThankYouScreen({super.key});

  @override
  State<ThankYouScreen> createState() => _ThankYouScreenState();
}

class _ThankYouScreenState extends State<ThankYouScreen> {
  static const Color kGrey = Color(0xFF353839);
  bool _pulseUp = true; // để lặp hiệu ứng scale

  int _asInt(dynamic v, [int fb = 0]) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fb;
    if (v is Map) {
      final m = v.map((k, val) => MapEntry(k.toString(), val));
      return _asInt(m['orderId'] ?? m['OrderID'] ?? m['id'], fb);
    }
    return fb;
  }

  void _goTrack(int orderId) {
    if (orderId > 0) {
      Navigator.pushReplacementNamed(
        context,
        '/order-tracking',
        arguments: orderId,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy mã đơn để theo dõi')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final int orderId = _asInt(args, 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hoàn tất đặt hàng'),
        backgroundColor: kGrey,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF5F6F8),
      body: LayoutBuilder(
        builder: (ctx, c) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  children: [
                    // Badge + particles “bling bling”
                    _AnimatedBadge(
                      color: kGrey,
                      pulseUp: _pulseUp,
                      onEnd: () => setState(() => _pulseUp = !_pulseUp),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Cảm ơn bạn đã mua hàng!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    if (orderId > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          'Mã đơn của bạn: #$orderId',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Hộp link “tại đây”
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.06),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Bạn có thể theo dõi đơn hàng',
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _goTrack(orderId),
                            style: TextButton.styleFrom(
                              foregroundColor: kGrey,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            child: const Text('tại đây'),
                          ),
                          const Text('.'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Nút hành động
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/app',
                                (r) => false,
                              );
                            },
                            icon: const Icon(Icons.home_outlined),
                            label: const Text('Về trang chủ'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black87,
                              side: const BorderSide(color: Colors.black12),
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle:
                                  const TextStyle(fontWeight: FontWeight.w700),
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _goTrack(orderId),
                            icon: const Icon(Icons.local_shipping_outlined),
                            label: const Text('Theo dõi đơn hàng'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              backgroundColor: kGrey,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle:
                                  const TextStyle(fontWeight: FontWeight.w800),
                              elevation: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Dải sparkle nhỏ ở dưới cho đỡ trống
                    _SubtleSparkles(color: kGrey.withOpacity(.4)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Badge tròn với hiệu ứng pulse (không dùng AnimationController)
class _AnimatedBadge extends StatelessWidget {
  final Color color;
  final bool pulseUp;
  final VoidCallback onEnd;

  const _AnimatedBadge({
    required this.color,
    required this.pulseUp,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: pulseUp ? 1.05 : 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      onEnd: onEnd,
      builder: (ctx, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // viền tán xạ
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withOpacity(.05),
                  color.withOpacity(.02),
                  Colors.transparent
                ],
                stops: const [0.3, 0.7, 1.0],
              ),
            ),
          ),
          // vòng sáng
          Container(
            width: 134,
            height: 134,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.white.withOpacity(.75),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(.18),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          // vòng trong + tick
          Container(
            width: 118,
            height: 118,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 6),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
          // 3 hạt lấp lánh nhỏ
          Positioned(
            right: 14,
            top: 22,
            child: _Dot(),
          ),
          Positioned(
            left: 20,
            bottom: 26,
            child: _Dot(),
          ),
          Positioned(
            right: 34,
            bottom: 14,
            child: _Dot(size: 6),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final double size;
  const _Dot({this.size = 8});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .6, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (_, v, __) => Opacity(
        opacity: v,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Hàng “sparkles” nhẹ nhàng phía dưới để lấp khoảng trống
class _SubtleSparkles extends StatelessWidget {
  final Color color;
  const _SubtleSparkles({required this.color});

  @override
  Widget build(BuildContext context) {
    final rnd = Random();
    return SizedBox(
      height: 50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(12, (i) {
          final delay = (i % 6) * 120;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: .3, end: 1),
              duration: Duration(milliseconds: 900 + delay),
              curve: Curves.easeInOut,
              builder: (_, t, __) => Opacity(
                opacity: t,
                child: Icon(
                  Icons.star_rounded,
                  size: 10 + rnd.nextInt(4).toDouble(),
                  color: color,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
