import 'package:flutter/material.dart';
import 'package:ha_smart_client/core/models/ha_control.dart';
import 'package:ha_smart_client/core/models/ha_entity.dart';
import 'package:ha_smart_client/state/ha_provider.dart';
import 'package:ha_smart_client/widgets/cards/card_scaffold.dart';
import 'package:provider/provider.dart';

/// 窗帘 / 卷帘卡片：开、停、关 + 可选位置滑杆。
class CoverCard extends StatelessWidget {
  const CoverCard({required this.entity, super.key});

  final HaEntity entity;

  @override
  Widget build(BuildContext context) {
    final ha = context.read<HaProvider>();
    final cap = entity.capability;
    final enabled = !entity.isUnavailable;
    final position = (entity.attributes['current_position'] as num?)?.toDouble();

    return EntityCardShell(
      entity: entity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _ActionButton(
                icon: Icons.north_rounded,
                label: '打开',
                enabled: enabled && cap.supports(HaFeatures.open),
                onTap: () => runHaAction(context, () => ha.openCover(entity)),
              ),
              _ActionButton(
                icon: Icons.pause_rounded,
                label: '停止',
                enabled: enabled && cap.supports(HaFeatures.stop),
                onTap: () => runHaAction(context, () => ha.stopCover(entity)),
              ),
              _ActionButton(
                icon: Icons.south_rounded,
                label: '关闭',
                enabled: enabled && cap.supports(HaFeatures.close),
                onTap: () => runHaAction(context, () => ha.closeCover(entity)),
              ),
            ],
          ),
          if (enabled && cap.supports(HaFeatures.position)) ...<Widget>[
            const SizedBox(height: 8),
            HaSlider(
              value: position ?? (entity.isOn ? 100 : 0),
              min: 0,
              max: 100,
              divisions: 100,
              labelBuilder: (v) => '${v.round()}%',
              onSubmitted: (value) => runHaAction(
                context,
                () => ha.setCoverPosition(entity, value.round()),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          children: <Widget>[
            CircleAvatar(
              radius: 22,
              backgroundColor: enabled
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceVariant,
              child: Icon(
                icon,
                color: enabled
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: enabled
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
