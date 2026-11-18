import 'package:flutter/material.dart';
import 'package:ha_smart_client/core/models/ha_control.dart';
import 'package:ha_smart_client/core/models/ha_entity.dart';
import 'package:ha_smart_client/state/ha_provider.dart';
import 'package:ha_smart_client/widgets/cards/card_scaffold.dart';
import 'package:provider/provider.dart';

/// 灯光卡片：电源开关 + 亮度滑杆 + 色温 / 彩色快捷选择。
class LightCard extends StatelessWidget {
  const LightCard({required this.entity, super.key});

  final HaEntity entity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ha = context.read<HaProvider>();
    final cap = entity.capability;

    final rawBrightness = (entity.attributes['brightness'] as num?)?.toInt();
    final brightnessPct = rawBrightness == null
        ? (entity.isOn ? 100.0 : 0.0)
        : (rawBrightness / 255 * 100).roundToDouble();

    final kelvin = (entity.attributes['color_temp_kelvin'] as num?)?.toDouble() ??
        (entity.attributes['color_temp'] is num
            ? 1000000 / (entity.attributes['color_temp'] as num).toDouble()
            : 4000);

    return EntityCardShell(
      entity: entity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Semantics(
                button: true,
                child: GestureDetector(
                  onTap: () => runHaAction(context, () => ha.toggle(entity)),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: entity.isOn
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceVariant,
                    ),
                    child: Icon(
                      Icons.power_settings_new_rounded,
                      size: 26,
                      color: entity.isOn
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entity.isOn ? '$brightnessPct%' : '已关闭',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cap.supports(HaFeatures.brightness) ? '亮度可调' : '仅支持开关',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (entity.isOn && cap.supports(HaFeatures.brightness)) ...<Widget>[
            const SizedBox(height: 6),
            HaSlider(
              value: brightnessPct,
              min: 1,
              max: 100,
              divisions: 100,
              labelBuilder: (v) => '${v.round()}%',
              onSubmitted: (value) => runHaAction(
                context,
                () => ha.setBrightness(entity, value.round()),
              ),
            ),
          ],
          if (entity.isOn &&
              (cap.supports(HaFeatures.colorTemp) ||
                  cap.supports(HaFeatures.rgb))) ...<Widget>[
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                if (cap.supports(HaFeatures.colorTemp))
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showColorTempSheet(
                        context,
                        ha,
                        kelvin,
                      ),
                      icon: const Icon(Icons.wb_sunny_outlined, size: 16),
                      label: const Text('色温'),
                    ),
                  ),
                if (cap.supports(HaFeatures.colorTemp) &&
                    cap.supports(HaFeatures.rgb))
                  const SizedBox(width: 10),
                if (cap.supports(HaFeatures.rgb))
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showColorSheet(context, ha),
                      icon: const Icon(Icons.palette_outlined, size: 16),
                      label: const Text('颜色'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showColorTempSheet(BuildContext context, HaProvider ha, double kelvin) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '色温 · ${kelvin.round()}K',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            HaSlider(
              value: kelvin,
              min: 2000,
              max: 6500,
              divisions: 45,
              labelBuilder: (v) => '${v.round()}K',
              onSubmitted: (value) {
                runHaAction(
                  ctx,
                  () => ha.setColorTemp(entity, value.round()),
                );
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showColorSheet(BuildContext context, HaProvider ha) {
    const colors = <(String, Color, List<int>)>[
      ('暖白', Color(0xFFFFD9A0), <int>[255, 180, 107]),
      ('冷白', Color(0xFFDCEBFF), <int>[204, 226, 255]),
      ('红', Color(0xFFFF6B6B), <int>[255, 80, 80]),
      ('绿', Color(0xFF69DB7C), <int>[105, 219, 124]),
      ('蓝', Color(0xFF74C0FC), <int>[116, 192, 252]),
      ('紫', Color(0xFFB197FC), <int>[177, 151, 252]),
      ('橙', Color(0xFFFFA94D), <int>[255, 169, 77]),
    ];

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('选择颜色', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 18),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: colors
                  .map(
                    (item) => GestureDetector(
                      onTap: () {
                        runHaAction(
                          ctx,
                          () => ha.setRgbColor(
                            entity,
                            item.$2.red,
                            item.$2.green,
                            item.$2.blue,
                          ),
                        );
                        Navigator.pop(ctx);
                      },
                      child: Column(
                        children: <Widget>[
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: item.$2,
                            child: const Icon(
                              Icons.check,
                              color: Colors.black54,
                              size: 18,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(item.$1, style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}
