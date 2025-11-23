import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:badges/badges.dart' as badges;

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeAppBar({
    super.key,
    this.onMenuTap,
    this.onCartTap,
    this.onAccountTap,
    this.title,
  });

  final VoidCallback? onMenuTap;
  final VoidCallback? onCartTap;
  final VoidCallback? onAccountTap;
  final String? title;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final isDesktopWeb = kIsWeb && MediaQuery.of(context).size.width >= 1024;
    const brand = Color(0xFF353839);

    return AppBar(
      backgroundColor: brand,
      title: Text(title ?? 'MaiTech'),
      automaticallyImplyLeading: false,
      leading: (!isDesktopWeb && onMenuTap != null)
          ? IconButton(icon: const Icon(Icons.sort), onPressed: onMenuTap)
          : null,
      actions: [
        if (!isDesktopWeb && onAccountTap != null)
          IconButton(
            tooltip: 'Tôi',
            icon: const Icon(Icons.person_outline),
            onPressed: onAccountTap,
          ),
        badges.Badge(
          position: badges.BadgePosition.topEnd(top: -4, end: -4),
          badgeStyle: const badges.BadgeStyle(badgeColor: Colors.red),
          badgeContent: const Text('3', style: TextStyle(color: Colors.white, fontSize: 10)),
          child: IconButton(
            tooltip: 'Giỏ hàng',
            icon: const Icon(Icons.shopping_bag_outlined),
            onPressed: onCartTap ?? () => Navigator.pushNamed(context, '/cart'),
          ),
        ),
      ],
    );
  }
}
