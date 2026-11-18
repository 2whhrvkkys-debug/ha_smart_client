import 'package:flutter/material.dart';
import 'package:ha_smart_client/core/models/ha_device.dart';
import 'package:ha_smart_client/core/models/ha_entity.dart';
import 'package:ha_smart_client/core/utils/ha_format.dart';
import 'package:ha_smart_client/core/utils/ha_icons.dart';
import 'package:ha_smart_client/state/ha_provider.dart';
import 'package:provider/provider.dart';

/// 设备详情底部面板：展示设备元数据、关联实体与聚合的诊断信息。
void showDeviceDetails(BuildContext context, HaDevice device) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _DeviceDetailSheet(device: device),
  );
}

class _DeviceDetailSheet extends StatelessWidget {
  const _DeviceDetailSheet({required this.device});

  final HaDevice device;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final home = context.watch<HaProvider>().home;
    final entities = device.entityIds
        .map((id) => home.entities[id])
        .whereType<HaEntity>()
        .toList(growable: false);
    final diagnostics = home.diagnosticsForDevice(device.id);
    final area = home.areasById[device.areaId];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.68,
      minChildSize: 0.35,
      maxChildSize: 0.94,
      builder: (BuildContext context, ScrollController controller) {
        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    HaIcons.navDevices,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        device.displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        device.subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (area != null) Chip(label: Text(area.name)),
                if (device.swVersion != null)
                  Chip(label: Text('固件 ${device.swVersion}')),
                Chip(label: Text('${entities.length} 个实体')),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            Text(
              '关联实体',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ...entities.map(
              (entity) => ListTile(
                dense: true,
                leading: Icon(
                  HaIcons.forEntity(entity),
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                title: Text(entity.displayName),
                subtitle: Text(HaFormat.stateLabel(entity)),
                trailing: Text(
                  entity.domain,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            if (diagnostics.isNotEmpty) ...<Widget>[
              const Divider(),
              Text(
                '诊断信息',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              ...diagnostics.map(
                (entity) => ListTile(
                  dense: true,
                  leading: Icon(
                    HaIcons.forEntity(entity),
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  title: Text(entity.displayName),
                  trailing: Text(HaFormat.sensorValue(entity)),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
