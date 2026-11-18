import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:ha_smart_client/core/models/ha_entity.dart';
import 'package:ha_smart_client/core/utils/ha_format.dart';
import 'package:ha_smart_client/core/utils/ha_icons.dart';
import 'package:ha_smart_client/state/ha_provider.dart';
import 'package:ha_smart_client/widgets/cards/entity_card.dart';
import 'package:ha_smart_client/widgets/common/empty_state.dart';
import 'package:ha_smart_client/widgets/common/section_header.dart';
import 'package:provider/provider.dart';

/// 首页：环境概览 + 收藏设备 + 异常提醒 + 快捷场景。
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final ha = context.watch<HaProvider>();
    final home = ha.home;

    final favorites = home.allEntities
        .where((entity) => ha.isFavorite(entity.entityId))
        .toList(growable: false);
    final scenes = home.allEntities
        .where((entity) => entity.domain == 'scene')
        .toList(growable: false);
    final environment = _pickEnvironment(home.sensors);
    final quickDevices = home.allEntities
        .where((entity) => !entity.capability.isReadOnly)
        .take(4)
        .toList(growable: false);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: ha.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          children: <Widget>[
            _Header(ha: ha),
            if (home.problemEntities.isNotEmpty)
              _AlertCard(entities: home.problemEntities),
            const SectionHeader(title: '环境概览', subtitle: '传感器实时读数'),
            if (environment.isEmpty)
              _EmptyEnvironment()
            else
              _EnvironmentRow(items: environment),
            SectionHeader(
              title: '收藏设备',
              subtitle: '${favorites.length} 个已收藏',
            ),
            if (favorites.isEmpty)
              EmptyState(
                icon: HaIcons.favoriteOutline,
                title: '还没有收藏',
                message: '点击任意设备卡片右上角的星标，即可固定到这里',
              )
            else
              EntityCardGrid(entities: favorites),
            const SectionHeader(title: '快捷场景', subtitle: '一键触发'),
            if (scenes.isEmpty)
              EmptyState(
                icon: HaIcons.navScenes,
                title: '暂无场景',
                message: '在 HA 中创建的场景会显示在这里',
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: scenes
                    .take(6)
                    .map(
                      (entity) => ActionChip(
                        avatar: Icon(
                          HaIcons.forEntity(entity),
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        label: Text(entity.displayName),
                        onPressed: () => ha.activate(entity),
                      ),
                    )
                    .toList(growable: false),
              ),
            SectionHeader(
              title: '设备速览',
              subtitle: '${home.allEntities.length} 个实体 · ${home.devices.length} 个设备',
            ),
            EntityCardGrid(entities: quickDevices),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  List<_EnvItem> _pickEnvironment(List<HaEntity> sensors) {
    final picked = <HaEntity>[];
    for (final deviceClass in <String>['temperature', 'humidity', 'illuminance']) {
      final match = sensors
          .where((entity) => entity.deviceClass == deviceClass)
          .firstOrNull;
      if (match != null) picked.add(match);
    }
    for (final entity in sensors) {
      if (picked.length >= 3) break;
      if (!picked.contains(entity)) picked.add(entity);
    }
    return picked
        .take(3)
        .map(
          (entity) => _EnvItem(
            label: entity.displayName,
            value: HaFormat.sensorValue(entity),
            icon: HaIcons.forEntity(entity),
          ),
        )
        .toList(growable: false);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.ha});

  final HaProvider ha;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hour = DateTime.now().hour;
    final greeting = hour < 6
        ? '夜深了'
        : hour < 11
            ? '早上好'
            : hour < 14
                ? '中午好'
                : hour < 18
                    ? '下午好'
                    : '晚上好';
    final location = ha.serverInfo?.locationName ?? '我的家';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  greeting,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  location,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ha.isWsConnected ? '实时同步中' : '离线缓存模式',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: ha.isWsConnected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              ha.isWsConnected ? HaIcons.navHome : HaIcons.offline,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.entities});

  final List<HaEntity> entities;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(HaIcons.warning, size: 20, color: theme.colorScheme.onErrorContainer),
              const SizedBox(width: 8),
              Text(
                '${entities.length} 项需要关注',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...entities.take(3).map(
                (entity) => Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    '• ${entity.displayName}：${HaFormat.stateLabel(entity)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _EmptyEnvironment extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text('暂无可用传感器数据'),
    );
  }
}

class _EnvironmentRow extends StatelessWidget {
  const _EnvironmentRow({required this.items});

  final List<_EnvItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = 10.0;
        final width = (constraints.maxWidth - gap * (items.length - 1)) / items.length;
        return Row(
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(item.icon, size: 20, color: theme.colorScheme.primary),
                        const SizedBox(height: 10),
                        Text(
                          item.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _EnvItem {
  const _EnvItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}
