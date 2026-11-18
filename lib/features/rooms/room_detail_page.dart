import 'package:flutter/material.dart';
import 'package:ha_smart_client/core/models/ha_device.dart';
import 'package:ha_smart_client/core/utils/ha_format.dart';
import 'package:ha_smart_client/core/utils/ha_icons.dart';
import 'package:ha_smart_client/state/ha_provider.dart';
import 'package:ha_smart_client/widgets/cards/entity_card.dart';
import 'package:ha_smart_client/widgets/common/device_detail_sheet.dart';
import 'package:ha_smart_client/widgets/common/empty_state.dart';
import 'package:ha_smart_client/widgets/common/section_header.dart';
import 'package:provider/provider.dart';

/// 房间详情路由参数。
class RoomRouteArgs {
  const RoomRouteArgs({required this.areaId, required this.title});

  final String areaId;
  final String title;
}

/// 房间详情页：该房间全部实体卡片 + 关联设备 + 诊断信息。
class RoomDetailPage extends StatelessWidget {
  const RoomDetailPage({required this.args, super.key});

  final RoomRouteArgs args;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ha = context.watch<HaProvider>();
    final home = ha.home;

    final entities = home.entitiesForArea(args.areaId);
    final deviceIds = entities
        .map((entity) => entity.deviceId)
        .whereType<String>()
        .toSet();
    final devices = deviceIds
        .map((id) => home.devicesById[id])
        .whereType<HaDevice>()
        .toList(growable: false);
    final diagnostics = home.diagnosticEntities.values
        .where((entity) => entity.areaId == args.areaId)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: Text(args.title)),
      body: RefreshIndicator(
        onRefresh: ha.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: <Widget>[
            if (entities.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: 80),
                child: EmptyState(
                  icon: HaIcons.navRooms,
                  title: '这个房间还没有实体',
                  message: '在 HA 中把设备分配到该区域即可显示',
                ),
              )
            else ...<Widget>[
              SectionHeader(
                title: '设备与实体',
                subtitle: '${entities.length} 个实体',
              ),
              EntityCardGrid(entities: entities),
            ],
            if (devices.isNotEmpty) ...<Widget>[
              const SectionHeader(title: '关联设备'),
              ...devices.map(
                (device) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(
                        HaIcons.navDevices,
                        size: 20,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text(device.displayName),
                    subtitle: Text(
                      device.subtitle.isEmpty
                          ? '${device.entityIds.length} 个实体'
                          : device.subtitle,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showDeviceDetails(context, device),
                  ),
                ),
              ),
            ],
            if (diagnostics.isNotEmpty) ...<Widget>[
              const SectionHeader(title: '诊断信息', subtitle: '只读'),
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
        ),
      ),
    );
  }
}
