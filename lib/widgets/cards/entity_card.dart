import 'package:flutter/material.dart';
import 'package:ha_smart_client/core/models/ha_control.dart';
import 'package:ha_smart_client/core/models/ha_entity.dart';
import 'package:ha_smart_client/widgets/cards/climate_card.dart';
import 'package:ha_smart_client/widgets/cards/cover_card.dart';
import 'package:ha_smart_client/widgets/cards/light_card.dart';
import 'package:ha_smart_client/widgets/cards/lock_card.dart';
import 'package:ha_smart_client/widgets/cards/media_card.dart';
import 'package:ha_smart_client/widgets/cards/scene_card.dart';
import 'package:ha_smart_client/widgets/cards/sensor_card.dart';
import 'package:ha_smart_client/widgets/cards/switch_card.dart';

/// 卡片工厂：按 [HaControlCapability.type] 自动分发，新增 domain 只需扩展此处。
class EntityCard extends StatelessWidget {
  const EntityCard({required this.entity, super.key});

  final HaEntity entity;

  @override
  Widget build(BuildContext context) {
    switch (entity.capability.type) {
      case HaControlType.toggle:
        return entity.domain == 'light'
            ? LightCard(entity: entity)
            : SwitchCard(entity: entity);
      case HaControlType.cover:
        return CoverCard(entity: entity);
      case HaControlType.climate:
        return ClimateCard(entity: entity);
      case HaControlType.lock:
        return LockCard(entity: entity);
      case HaControlType.media:
        return MediaCard(entity: entity);
      case HaControlType.scene:
        return SceneCard(entity: entity);
      case HaControlType.none:
        return SensorCard(entity: entity);
    }
  }
}

/// 自适应卡片网格：手机单列、平板/折叠屏双列；高度由内容决定不被裁剪。
class EntityCardGrid extends StatelessWidget {
  const EntityCardGrid({required this.entities, super.key});

  final List<HaEntity> entities;

  @override
  Widget build(BuildContext context) {
    if (entities.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final twoColumns = constraints.maxWidth >= 540;
        final width = twoColumns
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: entities
              .map(
                (entity) => SizedBox(
                  width: width,
                  child: EntityCard(entity: entity),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}
