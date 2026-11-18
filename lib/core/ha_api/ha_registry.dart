import 'package:flutter/foundation.dart';
import 'package:ha_smart_client/core/errors/ha_exception.dart';
import 'package:ha_smart_client/core/ha_api/ha_ws_client.dart';

/// 四张注册表的原始快照，供聚合算法消费。
@immutable
class RegistrySnapshot {
  const RegistrySnapshot({
    required this.entities,
    required this.devices,
    required this.areas,
    required this.floors,
  });

  final List<Map<String, dynamic>> entities;
  final List<Map<String, dynamic>> devices;
  final List<Map<String, dynamic>> areas;
  final List<Map<String, dynamic>> floors;
}

/// 通过 WebSocket 命令拉取 entity / device / area / floor 注册表。
/// HA 并未为注册表提供 REST 端点，因此统一走 WS。
class HaRegistry {
  const HaRegistry(this._ws);

  final HaWsClient _ws;

  Future<RegistrySnapshot> load() async {
    final results = await Future.wait<List<Map<String, dynamic>>>([
      _loadList('config/entity_registry/list'),
      _loadList('config/device_registry/list'),
      _loadList('config/area_registry/list'),
      // floor_registry 在旧版 HA 中不存在，允许失败。
      _loadList('config/floor_registry/list', optional: true),
    ]);

    return RegistrySnapshot(
      entities: results[0],
      devices: results[1],
      areas: results[2],
      floors: results[3],
    );
  }

  Future<List<Map<String, dynamic>>> _loadList(
    String command, {
    bool optional = false,
  }) async {
    try {
      final response = await _ws.sendCommand(command);
      final result = response['result'];
      if (result is! List) return const <Map<String, dynamic>>[];
      return result
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList(growable: false);
    } on HaException {
      if (optional) return const <Map<String, dynamic>>[];
      rethrow;
    }
  }
}
