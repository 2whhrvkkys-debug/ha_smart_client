import 'package:flutter/material.dart';
import 'package:ha_smart_client/core/utils/ha_format.dart';
import 'package:ha_smart_client/core/utils/ha_icons.dart';
import 'package:ha_smart_client/state/ha_provider.dart';
import 'package:ha_smart_client/widgets/common/section_header.dart';
import 'package:provider/provider.dart';

/// 设置页：连接信息、主题、隐藏实体管理、统计与退出登录。
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ha = context.watch<HaProvider>();
    final home = ha.home;
    final hiddenCount = ha.allRawEntities
        .where((entity) => ha.isHidden(entity.entityId))
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: <Widget>[
          _ConnectionCard(ha: ha),
          const SectionHeader(title: '外观'),
          Card(
            child: ListTile(
              leading: Icon(Icons.brightness_6_outlined,
                  color: theme.colorScheme.primary),
              title: const Text('主题模式'),
              subtitle: Text(_themeLabel(ha.themeMode)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showThemeSheet(context, ha),
            ),
          ),
          const SectionHeader(title: '实体管理'),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: Icon(HaIcons.hidden, color: theme.colorScheme.primary),
                  title: const Text('隐藏实体管理'),
                  subtitle: Text(
                    hiddenCount == 0 ? '当前没有隐藏实体' : '$hiddenCount 个实体已隐藏',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showHiddenSheet(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(HaIcons.refresh, color: theme.colorScheme.primary),
                  title: const Text('重新加载全部数据'),
                  subtitle: Text(
                    ha.isRefreshing
                        ? '正在刷新…'
                        : '上次同步：${HaFormat.relativeTime(ha.lastSync).isEmpty ? '尚未同步' : HaFormat.relativeTime(ha.lastSync)}',
                  ),
                  onTap: ha.isRefreshing ? null : () => ha.refresh(),
                ),
              ],
            ),
          ),
          const SectionHeader(title: '关于'),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  title: const Text('实体统计'),
                  subtitle: Text(
                    '${home.allEntities.length} 可见 · ${home.diagnosticEntities.length} 诊断 · '
                    '${home.devices.length} 设备 · ${home.floors.length} 楼层',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Home Assistant 版本'),
                  subtitle: Text(ha.serverInfo?.version ?? '未知'),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('连接方式'),
                  subtitle: const Text('REST 全量拉取 + WebSocket 实时订阅'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _confirmLogout(context, ha),
            icon: Icon(HaIcons.logout, size: 18),
            label: const Text('退出登录并清除凭证'),
          ),
        ],
      ),
    );
  }

  void _showThemeSheet(BuildContext context, HaProvider ha) {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text('主题模式', style: theme.textTheme.titleMedium),
            ),
            for (final mode in ThemeMode.values)
              ListTile(
                leading: Icon(_themeIcon(mode)),
                title: Text(_themeLabel(mode)),
                trailing: ha.themeMode == mode
                    ? Icon(Icons.check, color: theme.colorScheme.primary)
                    : null,
                onTap: () {
                  ha.setThemeMode(mode);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showHiddenSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _HiddenEntitySheet(),
    );
  }

  Future<void> _confirmLogout(BuildContext context, HaProvider ha) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('将清除本机保存的地址、令牌与缓存，需要重新连接后才能使用。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed == true) await ha.logout();
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => '跟随系统',
        ThemeMode.light => '浅色',
        ThemeMode.dark => '深色',
      };

  static IconData _themeIcon(ThemeMode mode) => switch (mode) {
        ThemeMode.system => Icons.brightness_auto,
        ThemeMode.light => Icons.light_mode_outlined,
        ThemeMode.dark => Icons.dark_mode_outlined,
      };
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.ha});

  final HaProvider ha;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final live = ha.isWsConnected;
    final background = live
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.errorContainer;
    final foreground = live
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onErrorContainer;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              backgroundColor: background,
              child: Icon(
                live ? HaIcons.navHome : HaIcons.offline,
                size: 20,
                color: foreground,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    ha.serverInfo?.locationName ?? '尚未连接',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ha.baseUrl ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                live ? '实时' : '离线',
                style: TextStyle(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HiddenEntitySheet extends StatefulWidget {
  const _HiddenEntitySheet();

  @override
  State<_HiddenEntitySheet> createState() => _HiddenEntitySheetState();
}

class _HiddenEntitySheetState extends State<_HiddenEntitySheet> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ha = context.watch<HaProvider>();
    final theme = Theme.of(context);
    final entities = ha.allRawEntities.where((entity) {
      if (_query.isEmpty) return true;
      final keyword = _query.toLowerCase();
      return entity.displayName.toLowerCase().contains(keyword) ||
          entity.entityId.toLowerCase().contains(keyword);
    }).toList(growable: false);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.35,
      maxChildSize: 0.94,
      builder: (BuildContext context, ScrollController controller) {
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '关闭开关即隐藏该实体（不会操作设备）',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '搜索实体',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => setState(() => _query = value.trim()),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: entities.length,
                itemBuilder: (context, index) {
                  final entity = entities[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(HaIcons.forEntity(entity), size: 20),
                    title: Text(
                      entity.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${entity.entityId} · ${HaFormat.domainName(entity.domain)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Switch(
                      value: !ha.isHidden(entity.entityId),
                      onChanged: (visible) =>
                          ha.setEntityHidden(entity.entityId, !visible),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
