import 'package:flutter/material.dart';
import 'package:ha_smart_client/core/grouping/entity_aggregator.dart';
import 'package:ha_smart_client/core/models/ha_area.dart';
import 'package:ha_smart_client/core/models/ha_entity.dart';
import 'package:ha_smart_client/core/utils/ha_icons.dart';
import 'package:ha_smart_client/state/ha_provider.dart';
import 'package:ha_smart_client/widgets/cards/compact_device_tile.dart';
import 'package:ha_smart_client/widgets/common/empty_state.dart';
import 'package:provider/provider.dart';

/// SmartThings 风格「设备」页。
///
/// 顶部：位置下拉 + 搜索 + 添加 + 更多；
/// 其下：横向房间分类标签（全部 / 中央空调 / 入户 / 玄关 / 客厅…）；
/// 主体：按房间分组的两列紧凑设备卡片网格。
class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  final TextEditingController _searchController = TextEditingController();

  /// 当前选中的房间 id；null / _allAreas 表示「所有设备」。
  static const String _allAreas = '__all_areas__';
  String _selectedArea = _allAreas;
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ha = context.watch<HaProvider>();
    final home = ha.home;
    final theme = Theme.of(context);

    // 房间分类 = 有可见实体的区域，按 HA 楼层顺序排列。
    final areaTabs = _buildAreaTabs(home);

    // 按选中房间 + 搜索词过滤实体。
    final filtered = home.allEntities.where((entity) {
      if (_selectedArea != _allAreas && entity.areaId != _selectedArea) {
        return false;
      }
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return entity.displayName.toLowerCase().contains(q) ||
          entity.entityId.toLowerCase().contains(q);
    }).toList(growable: false);

    // 分组：选中单个房间时只显示该房间一节；「所有设备」时按房间分节。
    final Map<String, List<HaEntity>> groups = <String, List<HaEntity>>{};
    for (final entity in filtered) {
      final key = entity.areaId ?? EntityAggregator.unassignedAreaId;
      groups.putIfAbsent(key, () => <HaEntity>[]).add(entity);
    }
    final orderedKeys = _orderAreaKeys(groups.keys.toList(), home);

    final locationName = ha.serverInfo?.locationName ?? '我的家';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: ha.refresh,
          child: CustomScrollView(
            slivers: <Widget>[
              // 顶部固定：位置栏 + 搜索/添加/更多 + 房间分类标签。
              SliverPersistentHeader(
                pinned: true,
                delegate: _HeaderDelegate(
                  theme: theme,
                  locationName: locationName,
                  areaTabs: areaTabs,
                  selectedArea: _selectedArea,
                  searching: _searching,
                  query: _query,
                  controller: _searchController,
                  onToggleSearch: () => setState(() {
                    _searching = !_searching;
                    if (!_searching) {
                      _searchController.clear();
                      _query = '';
                    }
                  }),
                  onQueryChanged: (value) => setState(() => _query = value.trim()),
                  onClearQuery: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                  onAreaSelected: (id) => setState(() => _selectedArea = id),
                ),
              ),
              // 主体：按房间分组的两列网格。
              if (groups.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: EmptyState(
                      icon: HaIcons.navDevices,
                      title: _query.isEmpty ? '还没有设备' : '没有匹配的设备',
                      message: _query.isEmpty
                          ? '连接成功后，HA 中的实体会按房间显示在这里'
                          : '试试其他关键词',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final areaId = orderedKeys[index];
                        final entities = groups[areaId]!;
                        final areaName = _areaName(areaId, home);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 14, 4, 10),
                              child: Row(
                                children: <Widget>[
                                  Text(
                                    areaName,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: theme.brightness == Brightness.dark
                                          ? Colors.white
                                          : const Color(0xFF3A3040),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.brightness == Brightness.dark
                                          ? Colors.white.withOpacity(0.14)
                                          : Colors.black.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${entities.length}',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.brightness == Brightness.dark
                                            ? Colors.white.withOpacity(0.8)
                                            : const Color(0xFF7A6E80),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _CompactGrid(entities: entities),
                          ],
                        );
                      },
                      childCount: orderedKeys.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 从楼层 → 房间顺序构建有设备的区域标签列表。
  List<HaArea> _buildAreaTabs(AggregatedHome home) {
    final withEntities = home.entitiesByArea.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => entry.key)
        .toSet();
    final tabs = <HaArea>[];
    for (final floor in home.floors) {
      for (final area in floor.areas) {
        if (withEntities.contains(area.id)) tabs.add(area);
      }
    }
    // 兜底：registry 缺失时按实体自带 areaId 补占位标签。
    for (final id in withEntities) {
      if (tabs.any((a) => a.id == id)) continue;
      tabs.add(HaArea(
        id: id,
        name: id == EntityAggregator.unassignedAreaId
            ? '未分配'
            : home.areasById[id]?.name ?? '其他',
      ));
    }
    return tabs;
  }

  /// 分组 key 按房间标签顺序排列。
  List<String> _orderAreaKeys(List<String> keys, AggregatedHome home) {
    final tabs = _buildAreaTabs(home);
    final order = <String, int>{
      for (var i = 0; i < tabs.length; i++) tabs[i].id: i,
    };
    final sorted = List<String>.from(keys);
    sorted.sort((a, b) {
      final ia = order[a] ?? 9999;
      final ib = order[b] ?? 9999;
      return ia.compareTo(ib);
    });
    return sorted;
  }

  String _areaName(String areaId, AggregatedHome home) {
    if (areaId == EntityAggregator.unassignedAreaId) return '未分配区域';
    return home.areasById[areaId]?.name ?? '其他设备';
  }
}

/// 两列紧凑网格：手机上强制两列，与 SmartThings 一致。
class _CompactGrid extends StatelessWidget {
  const _CompactGrid({required this.entities});

  final List<HaEntity> entities;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = 12.0;
        final width = (constraints.maxWidth - gap) / 2;
        final children = <Widget>[
          for (final entity in entities)
            SizedBox(
              width: width,
              child: CompactDeviceTile(entity: entity),
            ),
        ];
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: children,
        );
      },
    );
  }
}

/// 顶部固定区（位置栏 + 房间标签），高度约 132。
class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  _HeaderDelegate({
    required this.theme,
    required this.locationName,
    required this.areaTabs,
    required this.selectedArea,
    required this.searching,
    required this.query,
    required this.controller,
    required this.onToggleSearch,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onAreaSelected,
  });

  final ThemeData theme;
  final String locationName;
  final List<HaArea> areaTabs;
  final String selectedArea;
  final bool searching;
  final String query;
  final TextEditingController controller;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<String> onAreaSelected;

  static const double _height = 132.0;
  static const String _all = '__all_areas__';

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final isDark = theme.brightness == Brightness.dark;
    final fg = isDark ? Colors.white : const Color(0xFF3A3040);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            (isDark ? Colors.black : Colors.white).withOpacity(0.34),
            (isDark ? Colors.black : Colors.white).withOpacity(0.12),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 第一行：位置下拉 + 搜索 / 添加 / 更多
          Row(
            children: <Widget>[
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => _showLocationInfo(context),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.14)
                          : Colors.white.withOpacity(0.66),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.home_rounded, size: 20, color: fg),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            locationName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: fg,
                            ),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _circleButton(
                icon: searching ? Icons.close : Icons.search,
                tooltip: searching ? '关闭搜索' : '搜索设备',
                isDark: isDark,
                onTap: onToggleSearch,
              ),
              const SizedBox(width: 8),
              _circleButton(
                icon: Icons.add_rounded,
                tooltip: '添加设备（在 HA 中添加）',
                isDark: isDark,
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('请在 Home Assistant 中完成设备添加'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 第二行：搜索框 或 房间分类标签
          if (searching)
            TextField(
              controller: controller,
              autofocus: true,
              onChanged: onQueryChanged,
              decoration: InputDecoration(
                hintText: '搜索设备名称或实体 ID',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: onClearQuery,
                      ),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.12)
                    : Colors.white.withOpacity(0.72),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            )
          else
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: areaTabs.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final isAll = index == 0;
                  final id = isAll ? _all : areaTabs[index - 1].id;
                  final label = isAll ? '所有设备' : areaTabs[index - 1].name;
                  final selected = selectedArea == id;
                  return ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    showCheckmark: false,
                    onSelected: (_) => onAreaSelected(id),
                    backgroundColor: isDark
                        ? Colors.white.withOpacity(0.10)
                        : Colors.white.withOpacity(0.60),
                    selectedColor: theme.colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected
                          ? theme.colorScheme.onPrimaryContainer
                          : (isDark
                              ? Colors.white.withOpacity(0.8)
                              : const Color(0xFF6E6472)),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    side: BorderSide.none,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required String tooltip,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.14)
              : Colors.white.withOpacity(0.66),
          shape: BoxShape.circle,
        ),
        child: Tooltip(message: tooltip, child: Icon(icon, size: 22, color: isDark ? Colors.white : const Color(0xFF3A3040))),
      ),
    );
  }

  void _showLocationInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(locationName),
        content: const Text('当前连接的 Home Assistant 实例。位置名称来自 HA 的「位置名称」设置。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HeaderDelegate oldDelegate) =>
      locationName != oldDelegate.locationName ||
      selectedArea != oldDelegate.selectedArea ||
      searching != oldDelegate.searching ||
      query != oldDelegate.query ||
      areaTabs != oldDelegate.areaTabs ||
      theme != oldDelegate.theme;
}
