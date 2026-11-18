import 'package:flutter/material.dart';
import 'package:ha_smart_client/core/utils/ha_icons.dart';
import 'package:ha_smart_client/state/ha_provider.dart';
import 'package:ha_smart_client/widgets/cards/entity_card.dart';
import 'package:ha_smart_client/widgets/common/empty_state.dart';
import 'package:ha_smart_client/widgets/common/section_header.dart';
import 'package:provider/provider.dart';

/// 场景页：场景一键触发，脚本 / 按钮 / 自动化单独分组。
class ScenesPage extends StatelessWidget {
  const ScenesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ha = context.watch<HaProvider>();
    final entities = ha.home.allEntities;

    final scenes = entities
        .where((entity) => entity.domain == 'scene')
        .toList(growable: false);
    final scripts = entities
        .where(
          (entity) => const <String>{
            'script',
            'button',
            'automation',
          }.contains(entity.domain),
        )
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('场景')),
      body: RefreshIndicator(
        onRefresh: ha.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: <Widget>[
            SectionHeader(title: '场景', subtitle: '${scenes.length} 个可触发场景'),
            if (scenes.isEmpty)
              EmptyState(
                icon: HaIcons.navScenes,
                title: '暂无场景',
                message: '在 Home Assistant 中创建的场景会自动出现在这里',
              )
            else
              EntityCardGrid(entities: scenes),
            SectionHeader(
              title: '脚本与自动化',
              subtitle: '${scripts.length} 个可执行项',
            ),
            if (scripts.isEmpty)
              EmptyState(
                icon: HaIcons.code,
                title: '暂无脚本',
                message: '脚本、按钮与自动化会显示在这里',
              )
            else
              EntityCardGrid(entities: scripts),
          ],
        ),
      ),
    );
  }
}
