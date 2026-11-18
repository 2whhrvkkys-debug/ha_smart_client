import 'package:flutter/material.dart';
import 'package:ha_smart_client/core/models/ha_entity.dart';
import 'package:ha_smart_client/state/ha_provider.dart';
import 'package:ha_smart_client/widgets/cards/card_scaffold.dart';
import 'package:provider/provider.dart';

/// 门锁卡片：上锁 / 解锁。lock 域中 isOn == 已解锁。
class LockCard extends StatelessWidget {
  const LockCard({required this.entity, super.key});

  final HaEntity entity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ha = context.read<HaProvider>();
    final unlocked = entity.isOn;
    final enabled = !entity.isUnavailable;

    return EntityCardShell(
      entity: entity,
      child: Row(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlocked
                  ? theme.colorScheme.errorContainer
                  : theme.colorScheme.primaryContainer,
            ),
            child: Icon(
              unlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
              color: unlocked
                  ? theme.colorScheme.onErrorContainer
                  : theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              unlocked ? '已解锁' : '已上锁',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          FilledButton(
            onPressed: enabled
                ? () => runHaAction(
                      context,
                      () => unlocked ? ha.lock(entity) : ha.unlock(entity),
                    )
                : null,
            child: Text(unlocked ? '上锁' : '解锁'),
          ),
        ],
      ),
    );
  }
}
