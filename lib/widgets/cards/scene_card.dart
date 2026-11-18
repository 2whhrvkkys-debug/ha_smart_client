import 'package:flutter/material.dart';
import 'package:ha_smart_client/core/models/ha_entity.dart';
import 'package:ha_smart_client/state/ha_provider.dart';
import 'package:ha_smart_client/widgets/cards/card_scaffold.dart';
import 'package:provider/provider.dart';

/// 场景 / 脚本 / 按钮 / 自动化卡片：一键执行。
class SceneCard extends StatelessWidget {
  const SceneCard({required this.entity, super.key});

  final HaEntity entity;

  @override
  Widget build(BuildContext context) {
    final ha = context.read<HaProvider>();
    final enabled = !entity.isUnavailable;

    return EntityCardShell(
      entity: entity,
      child: FilledButton.icon(
        onPressed: enabled
            ? () => runHaAction(
                  context,
                  () => ha.activate(entity),
                  prefix: '执行失败',
                )
            : null,
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('立即执行'),
      ),
    );
  }
}
