import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'home_screen.dart';
import 'coupon_screen.dart';
import 'notification_screen.dart';
import 'account_screen.dart';

class MainTabs extends StatefulWidget {
  const MainTabs({super.key});
  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  int _currentIndex = 0;
  void _setTab(int i) => setState(() => _currentIndex = i);

  late final List<Widget> _pages = [
    HomeScreen(
      onCartTap: () => Navigator.pushNamed(context, '/cart'),
      onAccountTap: () => _setTab(3),
    ),
    const CouponScreen(),
    const NotificationScreen(),
    const AccountScreen(),
  ];

  Future<bool> _onWillPop() async {
    if (_currentIndex != 0) {
      _setTab(0);
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopWeb = kIsWeb && MediaQuery.of(context).size.width >= 1024;

    final content = IndexedStack(index: _currentIndex, children: _pages);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        extendBody: true,

        // ✅ WEB DESKTOP: có sidebar NavigationRail màu hồng bên trái
        body: isDesktopWeb
            ? Row(
                children: [
                  Container(
                    width: 80,
                    color: const Color(0xFFF7ECFA), // hồng nhạt
                    child: SafeArea(
                      child: NavigationRail(
                        selectedIndex: _currentIndex,
                        onDestinationSelected: _setTab,
                        labelType: NavigationRailLabelType.selected,
                        groupAlignment: -1,
                        useIndicator: true,
                        indicatorColor: const Color(0xFFEAD7F6),
                        selectedIconTheme: const IconThemeData(size: 26),
                        unselectedIconTheme: const IconThemeData(size: 24),
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(Icons.home_outlined),
                            selectedIcon: Icon(Icons.home),
                            label: Text('Trang chủ'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.card_giftcard_outlined),
                            selectedIcon: Icon(Icons.card_giftcard),
                            label: Text('Ưu đãi'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.notifications_none),
                            selectedIcon: Icon(Icons.notifications),
                            label: Text('Thông báo'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.person_outline),
                            selectedIcon: Icon(Icons.person),
                            label: Text('Tôi'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: content),
                ],
              )
            : content,

        // ✅ MOBILE/TABLET: giữ BottomNav như cũ
        bottomNavigationBar: isDesktopWeb
            ? null
            : CurvedNavigationBar(
                backgroundColor: Colors.transparent,
                color: const Color(0xFF353839),
                height: 60,
                index: _currentIndex,
                items: const [
                  Icon(Icons.home, size: 30, color: Colors.white),
                  Icon(Icons.card_giftcard, size: 30, color: Colors.white),
                  Icon(Icons.notifications, size: 30, color: Colors.white),
                  Icon(Icons.person, size: 30, color: Colors.white),
                ],
                onTap: _setTab,
              ),
      ),
    );
  }
}
