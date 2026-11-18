import 'package:flutter/material.dart';
import 'package:ha_smart_client/features/rooms/room_detail_page.dart';

/// 路由名称集中管理，方便后续加快捷指令 / 设备详情页。
class AppRoutes {
  const AppRoutes._();

  static const String room = '/room';
}

/// 房间详情页参数与页面本体定义在 features/rooms/room_detail_page.dart，
/// 这里只负责路由分发（该页从 HaProvider 按 areaId 读取实体，避免对象耦合）。

class AppRouter {
  const AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.room:
        final args = settings.arguments;
        if (args is! RoomRouteArgs) {
          return _errorRoute('房间参数无效');
        }
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => RoomDetailPage(args: args),
        );
      default:
        return _errorRoute('未知路由：${settings.name}');
    }
  }

  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('出错了')),
        body: Center(child: Text(message)),
      ),
    );
  }
}
