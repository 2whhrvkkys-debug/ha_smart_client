import 'package:flutter/material.dart';
import 'package:ha_smart_client/app/wallpapers.dart';
import 'package:ha_smart_client/state/ha_provider.dart';
import 'package:ha_smart_client/features/devices/devices_page.dart';
import 'package:ha_smart_client/features/home/home_page.dart';
import 'package:ha_smart_client/features/rooms/rooms_page.dart';
import 'package:ha_smart_client/features/scenes/scenes_page.dart';
import 'package:ha_smart_client/features/settings/settings_page.dart';
import 'package:ha_smart_client/widgets/common/connection_banner.dart';
import 'package:provider/provider.dart';

/// 底部导航脚手架：五个 Tab 用 IndexedStack 保留各自滚动位置与筛选状态。
///
/// 背景铺当前壁纸渐变，Tab 页的 Scaffold 为透明，让壁纸透出。
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const List<Widget> _pages = <Widget>[
    HomePage(),
    DevicesPage(),
    RoomsPage(),
    ScenesPage(),
    SettingsPage(),
  ];

  static const List<IconData> _icons = <IconData>[
    Icons.home_rounded,
    Icons.grid_view_rounded,
    Icons.weekend_outlined,
    Icons.auto_awesome_outlined,
    Icons.menu_rounded,
  ];

  static const List<String> _labels = <String>[
    '主页',
    '设备',
    '生活',
    '日常程序',
    '菜单',
  ];

  @override
  Widget build(BuildContext context) {
    final wallpaperId = context.select<HaProvider, String>((h) => h.wallpaperId);
    final gradient = AppWallpapers.byId(wallpaperId).gradient;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: Column(
          children: <Widget>[
            const ConnectionBanner(),
            Expanded(
              child: IndexedStack(index: _index, children: _pages),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: <NavigationDestination>[
          for (var i = 0; i < _labels.length; i++)
            NavigationDestination(
              icon: Icon(_icons[i]),
              label: _labels[i],
            ),
        ],
      ),
    );
  }
}
