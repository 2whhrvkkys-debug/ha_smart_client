import 'package:flutter/material.dart';
import 'package:ha_smart_client/core/models/ha_control.dart';
import 'package:ha_smart_client/core/models/ha_entity.dart';
import 'package:ha_smart_client/core/utils/ha_format.dart';
import 'package:ha_smart_client/state/ha_provider.dart';
import 'package:ha_smart_client/widgets/cards/card_scaffold.dart';
import 'package:provider/provider.dart';

/// 空调 / 温控卡片：当前温度、目标温度步进、运行模式、预设模式。
class ClimateCard extends StatelessWidget {
  const ClimateCard({required this.entity, super.key});

  final HaEntity entity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ha = context.read<HaProvider>();
    final cap = entity.capability;
    final attrs = entity.attributes;

    final current = (attrs['current_temperature'] as num?)?.toDouble();
    final target = (attrs['temperature'] as num?)?.toDouble() ??
        (attrs['target_temp_high'] as num?)?.toDouble() ??
        22.0;
    final action = attrs['hvac_action'] as String?;
    final enabled = !entity.isUnavailable;
    final step = cap.tempStep ?? 0.5;

    final subtitle = <String>[
      HaFormat.humanize(entity.state),
      if (action != null) HaFormat.humanize(action),
    ].join(' · ');

    return EntityCardShell(
      entity: entity,
      subtitle: subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    current == null ? '--°' : '${current.toStringAsFixed(1)}°',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  Text(
                    '当前温度',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.remove, size: 18),
                      onPressed: enabled && cap.supports(HaFeatures.targetTemperature)
                          ? () => runHaAction(
                                context,
                                () => ha.setClimateTemperature(
                                  entity,
                                  _clamped(
                                    target - step,
                                    cap,
                                  ),
                                ),
                              )
                          : null,
                    ),
                    Text(
                      '${target.toStringAsFixed(1)}°',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: enabled && cap.supports(HaFeatures.targetTemperature)
                          ? () => runHaAction(
                                context,
                                () => ha.setClimateTemperature(
                                  entity,
                                  _clamped(
                                    target + step,
                                    cap,
                                  ),
                                ),
                              )
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (cap.hvacModes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: cap.hvacModes
                  .map(
                    (mode) => ChoiceChip(
                      label: Text(HaFormat.humanize(mode), style: const TextStyle(fontSize: 12)),
                      selected: mode == entity.state,
                      onSelected: enabled
                          ? (_) => runHaAction(
                                context,
                                () => ha.setHvacMode(entity, mode),
                              )
                          : null,
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          if (cap.presetModes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: PopupMenuButton<String>(
                enabled: enabled,
                onSelected: (preset) => runHaAction(
                  context,
                  () => ha.setPresetMode(entity, preset),
                ),
                itemBuilder: (_) => cap.presetModes
                    .map(
                      (preset) => PopupMenuItem<String>(
                        value: preset,
                        child: Text(HaFormat.humanize(preset)),
                      ),
                    )
                    .toList(growable: false),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.tune, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      '预设：${attrs['preset_mode'] ?? '默认'}',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  double _clamped(double value, HaControlCapability cap) {
    final min = cap.minTemp ?? 16;
    final max = cap.maxTemp ?? 30;
    return value.clamp(min, max).toDouble();
  }
}
