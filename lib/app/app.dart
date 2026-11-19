import 'package:flutter/material.dart';
import 'package:ha_smart_client/app/router.dart';
import 'package:ha_smart_client/app/theme.dart';
import 'package:ha_smart_client/features/login/login_page.dart';
import 'package:ha_smart_client/features/shell/app_shell.dart';
import 'package:ha_smart_client/state/ha_provider.dart';
import 'package:provider/provider.dart';

/// 应用根组件。
/// 通过 Selector 精确订阅，避免实体实时刷新时重建 MaterialApp 整棵树。
class HaApp extends StatelessWidget {
  const HaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Home',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: context.select<HaProvider, ThemeMode>((h) => h.themeMode),
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: const _AuthGate(),
    );
  }
}

/// 根据连接状态决定展示登录页 / 连接中 / 主界面。
/// 断线与错误仍进入主界面（展示缓存实体 + 顶部横幅），符合生产级体验。
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final state = context.select<HaProvider, HaConnectionState>((h) => h.connection);

    return switch (state) {
      HaConnectionState.unconfigured => const LoginPage(),
      HaConnectionState.connecting => const _ConnectingView(),
      _ => const AppShell(),
    };
  }
}

class _ConnectingView extends StatelessWidget {
  const _ConnectingView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ha = context.read<HaProvider>();

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? const Color(0xFF0A0D13)
          : const Color(0xFFF3F5F9),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Icon(
                  Icons.home_rounded,
                  size: 44,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 28),
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                '正在连接家庭中枢…',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                '获取实体与区域信息',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: ha.cancelConnect,
                child: const Text('取消并返回'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
