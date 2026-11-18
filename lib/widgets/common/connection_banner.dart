import 'package:flutter/material.dart';
import 'package:ha_smart_client/core/ha_api/ha_ws_client.dart';
import 'package:ha_smart_client/core/utils/ha_icons.dart';
import 'package:ha_smart_client/state/ha_provider.dart';
import 'package:provider/provider.dart';

/// 顶部连接状态横幅：重连中 / 错误 / 离线时提示，成功时自动隐藏。
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final ha = context.watch<HaProvider>();
    final connection = ha.connection;
    final ws = ha.wsStatus;
    final error = ha.lastError;

    final pending = connection == HaConnectionState.connecting ||
        ws == HaWsStatus.connecting ||
        ws == HaWsStatus.reconnecting;
    final failed = connection == HaConnectionState.error ||
        ws == HaWsStatus.error ||
        (error != null && error.isNotEmpty) ||
        connection == HaConnectionState.disconnected;

    if (!pending && !failed) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isPending = pending && error == null;
    final background = isPending
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.errorContainer;
    final foreground = isPending
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onErrorContainer;

    return Material(
      color: background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: <Widget>[
            isPending
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  )
                : Icon(HaIcons.offline, size: 18, color: foreground),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isPending
                    ? '正在重连家庭中枢…'
                    : (error ?? '连接已断开，显示的是缓存状态'),
                style: TextStyle(color: foreground, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!isPending)
              TextButton(
                onPressed: ha.refresh,
                style: TextButton.styleFrom(foregroundColor: foreground),
                child: const Text('重试'),
              ),
          ],
        ),
      ),
    );
  }
}
