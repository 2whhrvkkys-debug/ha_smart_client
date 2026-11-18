import 'package:flutter/material.dart';
import 'package:ha_smart_client/app/router.dart';
import 'package:ha_smart_client/core/models/ha_area.dart';
import 'package:ha_smart_client/core/utils/ha_icons.dart';
import 'package:ha_smart_client/features/rooms/room_detail_page.dart';
import 'package:ha_smart_client/state/ha_provider.dart';
import 'package:ha_smart_client/widgets/common/empty_state.dart';
import 'package:provider/provider.dart';

/// 房间页：按 家 → 楼层 → 房间 的层级展示，点击进入房间详情。
class RoomsPage extends StatelessWidget {
  const RoomsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ha = context.watch<HaProvider>();
    final floors = ha.home.floors;

    return Scaffold(
      appBar: AppBar(title: const Text('房间')),
      body: RefreshIndicator(
        onRefresh: ha.refresh,
        child: floors.isEmpty
            ? ListView(
                children: <Widget>[
                  const SizedBox(height: 120),
                  EmptyState(
                    icon: HaIcons.navRooms,
                    title: '还没有房间信息',
                    message: '在 HA 中为设备分配区域与楼层后，这里会自动生成房间树',
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                itemCount: floors.length,
                itemBuilder: (context, index) =>
                    _FloorSection(floor: floors[index]),
              ),
      ),
    );
  }
}

class _FloorSection extends StatelessWidget {
  const _FloorSection({required this.floor});

  final HaFloor floor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
          child: Row(
            children: <Widget>[
              Icon(HaIcons.navRooms, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                floor.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${floor.areas.length} 个房间',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: floor.areas
              .map((area) => _RoomTile(area: area))
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.area});

  final HaArea area;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ha = context.watch<HaProvider>();
    final entities = ha.home.entitiesForArea(area.id);
    final activeCount = entities
        .where((entity) => entity.isOn && !entity.capability.isReadOnly)
        .length;

    return SizedBox(
      width: 160,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).pushNamed(
            AppRoutes.room,
            arguments: RoomRouteArgs(areaId: area.id, title: area.name),
          ),
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    HaIcons.forDomain(
                      entities.isNotEmpty ? entities.first.domain : 'light',
                    ),
                    size: 20,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  area.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$activeCount 开启 · ${entities.length} 个实体',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
