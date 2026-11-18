import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ha_smart_client/app/app.dart';
import 'package:ha_smart_client/core/storage/secure_storage.dart';
import 'package:ha_smart_client/state/ha_provider.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 手机客户端：锁定竖屏（平板/横屏可在后续版本按宽度自适应）。
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  final storage = SecureStorage();
  final ha = HaProvider(storage: storage);

  // 恢复上次的连接配置并自动重连；失败也不会阻塞 UI 启动。
  await ha.bootstrap();

  runApp(
    ChangeNotifierProvider<HaProvider>.value(
      value: ha,
      child: const HaApp(),
    ),
  );
}
