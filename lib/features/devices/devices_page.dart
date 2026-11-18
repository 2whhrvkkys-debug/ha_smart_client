import 'package:flutter/material.dart';
import 'package:ha_smart_client/core/models/ha_entity.dart';
import 'package:ha_smart_client/core/utils/ha_format.dart';
import 'package:ha_smart_client/core/utils/ha_icons.dart';
import 'package:ha_smart_client/state/ha_provider.dart';
import 'package:ha_smart_client/widgets/cards/entity_card.dart';
import 'package:ha_smart_client/widgets/common/empty_state.dart';
import 'package:ha_smart_client/widgets/common/section_header.dart';
import 'package:provider/provider.dart';

/// 设备页：按 domain 分组展示全部可控设备与传感器，支持即时搜索。
class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _searching = false;

  /// 可控 domain 优先展示，传感器与只读实体靠后。
  static const List<String> _domainOrder = <String>[
    'light',
    'switch',
    'cover',
    'climate',
    'lock',
    'media_player',
    'scene',
    'script',
    'button',
    'vacuum',
    'fan',
    'sensor',
    'binary_sensor',
    'automation',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ha = context.watch<HaProvider>();
    final filtered = ha.home.allEntities.where(_matches).toList(growable: false);
    final grouped = _group(filtered);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设备'),
        actions: <Widget>[
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            tooltip: _searching ? '关闭搜索' : '搜索设备',
            onPressed: () {
              setState(() {
                _searching = !_searching;
                if (!_searching) {
                  _searchController.clear();
                  _query = '';
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (_searching)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '搜索名称或实体 ID',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
                ),
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: ha.refresh,
              child: grouped.isEmpty
                  ? ListView(
                      children: <Widget>[
                        const SizedBox(height: 120),
                        EmptyState(
                          icon: HaIcons.navDevices,
                          title: _query.isEmpty ? '还没有设备' : '没有匹配的设备',
                          message: _query.isEmpty
                              ? '连接成功后，HA 中的实体会按类型显示在这里'
                              : '试试其他关键词',
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      itemCount: grouped.length,
                      itemBuilder: (context, index) {
                        final domain = grouped.keys.elementAt(index);
                        final entities = grouped[domain]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            SectionHeader(
                              title: HaFormat.domainName(domain),
                              subtitle: '${entities.length} 个实体',
                            ),
                            EntityCardGrid(entities: entities),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  bool _matches(HaEntity entity) {
    if (_query.isEmpty) return true;
    final keyword = _query.toLowerCase();
    return entity.displayName.toLowerCase().contains(keyword) ||
        entity.entityId.toLowerCase().contains(keyword);
  }

  Map<String, List<HaEntity>> _group(List<HaEntity> entities) {
    final grouped = <String, List<HaEntity>>{};
    for (final entity in entities) {
      grouped.putIfAbsent(entity.domain, () => <HaEntity>[]).add(entity);
    }
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        final indexA = _domainOrder.indexOf(a);
        final indexB = _domainOrder.indexOf(b);
        return (indexA == -1 ? 999 : indexA).compareTo(
          indexB == -1 ? 999 : indexB,
        );
      });
    return <String, List<HaEntity>>{
      for (final key in sortedKeys) key: grouped[key]!,
    };
  }
}
