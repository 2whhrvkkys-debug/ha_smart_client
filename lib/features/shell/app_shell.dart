import 'package:flutter/material.dart';
import 'package:ha_smart_client/core/utils/ha_icons.dart';
import 'package:ha_smart_client/features/devices/devices_page.dart';
import 'package:ha_smart_client/features/home/home_page.dart';
import 'package:ha_smart_client/features/rooms/rooms_page.dart';
import 'package:ha_smart_client/features/scenes/scenes_page.dart';
import 'package:ha_smart_client/features/settings/settings_page.dart';
import 'package:ha_smart_client/widgets/common/connection_banner.dart';

/// 底部导航脚手架：五个 Tab 用 IndexedStack 保留各自滚动位置与筛选状态。
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          const ConnectionBanner(),
          Expanded(
            child: IndexedStack(index: _index, children: _pages),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: Icon(HaIcons.navHome),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(HaIcons.navDevices),
            label: '设备',
          ),
          NavigationDestination(
            icon: Icon(HaIcons.navRooms),
            label: '房间',
          ),
          NavigationDestination(
            icon: Icon(HaIcons.navScenes),
            label: '场景',
          ),
          NavigationDestination(
            icon: Icon(HaIcons.navSettings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
