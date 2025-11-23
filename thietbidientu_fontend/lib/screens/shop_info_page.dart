import 'package:flutter/material.dart';

class ShopInfoPage extends StatelessWidget {
  const ShopInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    // dữ liệu mẫu – sau này bind từ API
    const shop = _Shop(
      name: 'MaiTech Shop',
      logo:
          'assets/images/logo/logoshop.png', // hoặc AssetImage
      rating: 4.8,
      followers: 12500,
      address: '236B Lê Văn Sỹ, Tâm Bình, Hồ Chí Minh',
      hotline: '0777435604',
      email: 'maiphun1412@gmail.com',
      website: 'https://maitech.vn',
      openHours: '08:00 – 21:30 (T2 – CN)',
      policyReturn: 'Đổi trả trong 7 ngày nếu lỗi NSX',
      shipInfo: 'Giao nhanh 3h nội thành',
      zalo: 'https://zalo.me/0848482247',
      facebook: 'https://facebook.com/maitech',
    );

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Thông tin shop')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(shop.logo, width: 80, height: 80, fit: BoxFit.cover),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shop.name,
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _ChipIcon(text: '${shop.rating} ★', icon: Icons.star),
                        _ChipIcon(text: '${_k(shop.followers)} theo dõi', icon: Icons.people),
                        _ChipIcon(text: 'Chính hãng', icon: Icons.verified),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Thông tin liên hệ
          _Section(
            title: 'Liên hệ',
            children: [
              _Tile(icon: Icons.location_on, label: 'Địa chỉ', value: shop.address),
              _Tile(icon: Icons.phone, label: 'Hotline', value: shop.hotline, tapHint: 'Gọi'),
              _Tile(icon: Icons.email, label: 'Email', value: shop.email),
              _Tile(icon: Icons.public, label: 'Website', value: shop.website),
              _Tile(icon: Icons.access_time, label: 'Giờ mở cửa', value: shop.openHours),
            ],
          ),

          // Chính sách
          _Section(
            title: 'Chính sách & vận chuyển',
            children: [
              _Tile(icon: Icons.assignment_return, label: 'Đổi trả', value: shop.policyReturn),
              _Tile(icon: Icons.local_shipping, label: 'Giao hàng', value: shop.shipInfo),
            ],
          ),

          // Mạng xã hội
          _Section(
            title: 'Kênh xã hội',
            children: [
              _Tile(icon: Icons.chat, label: 'Zalo', value: shop.zalo),
              _Tile(icon: Icons.facebook, label: 'Facebook', value: shop.facebook),
            ],
          ),

          const SizedBox(height: 12),

          // Nút hành động nhanh
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    // TODO: mở bản đồ với geo: hoặc Google Maps
                  },
                  icon: const Icon(Icons.map),
                  label: const Text('Xem bản đồ'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: gọi điện (url_launcher: tel:19000123)
                  },
                  icon: const Icon(Icons.phone),
                  label: const Text('Gọi ngay'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ======= Helpers UI ======= */

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? tapHint;
  const _Tile({required this.icon, required this.label, required this.value, this.tapHint});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(value),
      trailing: tapHint != null ? Text(tapHint!, style: const TextStyle(color: Colors.blue)) : null,
      onTap: () {
        // TODO: mở link/ gọi/ copy… (dùng url_launcher)
      },
    );
  }
}

class _ChipIcon extends StatelessWidget {
  final String text;
  final IconData icon;
  const _ChipIcon({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(text),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

class _Shop {
  final String name, logo, address, hotline, email, website, openHours,
      policyReturn, shipInfo, zalo, facebook;
  final double rating;
  final int followers;
  const _Shop({
    required this.name,
    required this.logo,
    required this.rating,
    required this.followers,
    required this.address,
    required this.hotline,
    required this.email,
    required this.website,
    required this.openHours,
    required this.policyReturn,
    required this.shipInfo,
    required this.zalo,
    required this.facebook,
  });
}

String _k(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return '$n';
}
