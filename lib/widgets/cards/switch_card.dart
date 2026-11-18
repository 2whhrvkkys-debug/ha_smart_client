import 'package:flutter/material.dart';
import 'package:ha_smart_client/core/models/ha_entity.dart';
import 'package:ha_smart_client/state/ha_provider.dart';
import 'package:ha_smart_client/widgets/cards/card_scaffold.dart';
import 'package:provider/provider.dart';

/// 通用开关卡片：switch / input_boolean / fan 等二态设备。
class SwitchCard extends StatelessWidget {
  const SwitchCard({required this.entity, super.key});

  final HaEntity entity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ha = context.read<HaProvider>();
    final enabled = !entity.isUnavailable;

    return EntityCardShell(
      entity: entity,
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: entity.isOn
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              entity.isOn ? Icons.toggle_on : Icons.toggle_off,
              size: 28,
              color: entity.isOn
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              entity.isOn ? '已开启' : '已关闭',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Switch(
            value: entity.isOn,
            onChanged: enabled
                ? (_) => runHaAction(context, () => ha.toggle(entity))
                : null,
          ),
        ],
      ),
    );
  }
}
