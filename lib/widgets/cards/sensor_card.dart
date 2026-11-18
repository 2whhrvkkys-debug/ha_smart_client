import 'package:flutter/material.dart';
import 'package:ha_smart_client/core/models/ha_entity.dart';
import 'package:ha_smart_client/core/utils/ha_format.dart';
import 'package:ha_smart_client/widgets/cards/card_scaffold.dart';

/// 传感器卡片：只读展示，不提供任何控制入口。
class SensorCard extends StatelessWidget {
  const SensorCard({required this.entity, super.key});

  final HaEntity entity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBinary = entity.domain == 'binary_sensor';
    final updated = HaFormat.relativeTime(entity.lastUpdated);
    final subtitle = updated.isEmpty
        ? HaFormat.stateLabel(entity)
        : '更新于 $updated';

    return EntityCardShell(
      entity: entity,
      subtitle: subtitle,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Text(
              isBinary
                  ? (entity.isOn ? '触发' : '正常')
                  : HaFormat.sensorValue(entity),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: entity.isUnavailable
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
          if (isBinary)
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: entity.isOn && !entity.isUnavailable
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
              ),
            ),
        ],
      ),
    );
  }
}
