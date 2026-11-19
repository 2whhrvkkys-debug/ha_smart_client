import 'package:ha_smart_client/core/ha_api/ha_registry.dart';
import 'package:ha_smart_client/core/models/ha_area.dart';
import 'package:ha_smart_client/core/models/ha_device.dart';
import 'package:ha_smart_client/core/models/ha_entity.dart';
import 'package:ha_smart_client/core/utils/ha_format.dart';

/// 聚合结果：Home / Rooms / Devices 三页共享同一份结构化数据。
class AggregatedHome {
  const AggregatedHome({
    required this.entities,
    required this.diagnosticEntities,
    required this.devices,
    required this.devicesById,
    required this.floors,
    required this.areasById,
    required this.entitiesByArea,
    required this.entitiesByDevice,
    required this.problemEntities,
    required this.sensors,
  });

  factory AggregatedHome.empty() => AggregatedHome(
        entities: const <String, HaEntity>{},
        diagnosticEntities: const <String, HaEntity>{},
        devices: const <HaDevice>[],
        devicesById: const <String, HaDevice>{},
        floors: const <HaFloor>[],
        areasById: const <String, HaArea>{},
        entitiesByArea: const <String, List<HaEntity>>{},
        entitiesByDevice: const <String, List<HaEntity>>{},
        problemEntities: const <HaEntity>[],
        sensors: const <HaEntity>[],
      );

  /// 主网格可见实体（不含诊断实体）。
  final Map<String, HaEntity> entities;
  final Map<String, HaEntity> diagnosticEntities;
  final List<HaDevice> devices;
  final Map<String, HaDevice> devicesById;
  final List<HaFloor> floors;
  final Map<String, HaArea> areasById;
  final Map<String, List<HaEntity>> entitiesByArea;
  final Map<String, List<HaEntity>> entitiesByDevice;
  final List<HaEntity> problemEntities;
  final List<HaEntity> sensors;

  List<HaEntity> get allEntities => entities.values.toList(growable: false);

  List<HaEntity> entitiesForArea(String areaId) =>
      entitiesByArea[areaId] ?? const <HaEntity>[];

  List<HaEntity> diagnosticsForDevice(String? deviceId) {
    if (deviceId == null) return const <HaEntity>[];
    return diagnosticEntities.values
        .where((e) => e.deviceId == deviceId)
        .toList(growable: false);
  }
}

/// 实体 → 设备 → 房间 → 楼层 的聚合算法（纯函数，易测试）。
class EntityAggregator {
  const EntityAggregator();

  /// 没有 area_id 的实体归入此虚拟房间。
  static const String unassignedAreaId = '__unassigned_area__';

  AggregatedHome aggregate({
    required List<HaEntity> states,
    required RegistrySnapshot registry,
    Set<String> userHiddenIds = const <String>{},
    /// 「3D 概览」实体白名单：非空时只聚合这些实体。
    /// 为空表示尚未加载/桥接不可用，此时不过滤（兼容所有实体模式）。
    Set<String>? allowedEntityIds,
  }) {
    final hasWhitelist = allowedEntityIds != null && allowedEntityIds.isNotEmpty;
    // ---------- 1. 建立 registry 索引 ----------
    final entityReg = <String, Map<String, dynamic>>{};
    for (final reg in registry.entities) {
      final id = reg['entity_id'] as String?;
      if (id != null && id.isNotEmpty) entityReg[id] = reg;
    }

    final deviceReg = <String, HaDevice>{};
    for (final reg in registry.devices) {
      final device = HaDevice.fromRegistryJson(reg);
      if (device.id.isNotEmpty) deviceReg[device.id] = device;
    }

    final floorNames = <String, String>{};
    final floorLevels = <String, int>{};
    for (final floor in registry.floors) {
      final id = floor['floor_id'] as String?;
      if (id == null || id.isEmpty) continue;
      floorNames[id] = (floor['name'] as String?) ?? '楼层';
      floorLevels[id] = (floor['level'] as num?)?.toInt() ?? 0;
    }

    final areaReg = <String, HaArea>{};
    for (final reg in registry.areas) {
      final area = HaArea.fromRegistryJson(
        reg,
        floorName: floorNames[reg['floor_id']],
        level: floorLevels[reg['floor_id']],
      );
      if (area.id.isNotEmpty) areaReg[area.id] = area;
    }

    // ---------- 2. 实体过滤与归位 ----------
    final visible = <String, HaEntity>{};
    final diagnostics = <String, HaEntity>{};
    final byArea = <String, List<HaEntity>>{};
    final byDevice = <String, List<HaEntity>>{};
    final problems = <HaEntity>[];
    final sensors = <HaEntity>[];

    for (final raw in states) {
      if (raw.entityId.isEmpty) continue;

      // 「3D 概览」桥接：只保留该仪表盘绑定的实体。
      if (hasWhitelist && !allowedEntityIds.contains(raw.entityId)) continue;

      // state 与 registry 元数据合并（WS 增量更新不会带 registry 信息）。
      final reg = entityReg[raw.entityId];
      var entity = reg == null ? raw : raw.mergeRegistry(reg);

      // 过滤规则：hidden / disabled / 用户主动隐藏。
      if (!entity.isVisible) continue;
      if (userHiddenIds.contains(entity.entityId)) continue;

      // 区域归属优先级：实体 area_id > 设备 area_id > 未分配。
      var areaId = entity.areaId;
      if (areaId == null || areaId.isEmpty) {
        areaId = entity.deviceId == null
            ? null
            : deviceReg[entity.deviceId]?.areaId;
      }
      if (areaId == null || !areaReg.containsKey(areaId)) {
        areaId = unassignedAreaId;
      }
      entity = entity.copyWith(areaId: areaId);

      // 诊断 / 配置类实体聚合到设备详情，不进入主网格。
      if (HaFormat.isDiagnostic(
        entityId: entity.entityId,
        entityCategory: entity.entityCategory,
      )) {
        diagnostics[entity.entityId] = entity;
        continue;
      }

      visible[entity.entityId] = entity;
      (byArea[areaId] ??= <HaEntity>[]).add(entity);

      final deviceId = entity.deviceId;
      if (deviceId != null && deviceId.isNotEmpty) {
        (byDevice[deviceId] ??= <HaEntity>[]).add(entity);
      }

      if (_isProblem(entity)) problems.add(entity);
      if (entity.domain == 'sensor' || entity.domain == 'binary_sensor') {
        sensors.add(entity);
      }
    }

    // ---------- 3. 设备：只保留拥有可见实体的设备 ----------
    final devices = <HaDevice>[];
    final devicesById = <String, HaDevice>{};

    for (final entry in deviceReg.entries) {
      final device = entry.value;
      final entities = byDevice[device.id];
      if (entities == null || entities.isEmpty) continue;

      final enriched = HaDevice(
        id: device.id,
        name: device.name,
        areaId: device.areaId ?? entities.first.areaId,
        manufacturer: device.manufacturer,
        model: device.model,
        swVersion: device.swVersion,
        hwVersion: device.hwVersion,
        icon: device.icon,
        viaDeviceId: device.viaDeviceId,
        entityIds: entities.map((e) => e.entityId).toList(growable: false),
      );
      devices.add(enriched);
      devicesById[device.id] = enriched;
    }

    // 兜底：registry 缺失但实体带 device_id 时生成占位设备。
    for (final entry in byDevice.entries) {
      if (devicesById.containsKey(entry.key)) continue;
      final placeholder = HaDevice(
        id: entry.key,
        name: entry.value.first.friendlyName ?? entry.value.first.originalName,
        areaId: entry.value.first.areaId,
        entityIds: entry.value.map((e) => e.entityId).toList(growable: false),
      );
      devices.add(placeholder);
      devicesById[entry.key] = placeholder;
    }

    // ---------- 4. 楼层 → 房间 ----------
    final floors = _buildFloors(areaReg, byArea, floorNames, floorLevels);

    return AggregatedHome(
      entities: Map<String, HaEntity>.unmodifiable(visible),
      diagnosticEntities: Map<String, HaEntity>.unmodifiable(diagnostics),
      devices: List<HaDevice>.unmodifiable(devices),
      devicesById: Map<String, HaDevice>.unmodifiable(devicesById),
      floors: List<HaFloor>.unmodifiable(floors),
      areasById: Map<String, HaArea>.unmodifiable(areaReg),
      entitiesByArea: Map<String, List<HaEntity>>.unmodifiable(
        byArea.map((key, value) => MapEntry(key, List<HaEntity>.unmodifiable(value))),
      ),
      entitiesByDevice: Map<String, List<HaEntity>>.unmodifiable(
        byDevice.map((key, value) => MapEntry(key, List<HaEntity>.unmodifiable(value))),
      ),
      problemEntities: List<HaEntity>.unmodifiable(problems),
      sensors: List<HaEntity>.unmodifiable(sensors),
    );
  }

  List<HaFloor> _buildFloors(
    Map<String, HaArea> areas,
    Map<String, List<HaEntity>> byArea,
    Map<String, String> floorNames,
    Map<String, int> floorLevels,
  ) {
    final grouped = <String, List<HaArea>>{};

    for (final area in areas.values) {
      final key = area.floorId ?? HaFloor.unassignedId;
      (grouped[key] ??= <HaArea>[]).add(area);
    }

    // 有未分配实体时，确保存在「未分配楼层 → 未分配区域」分组。
    if (byArea.containsKey(unassignedAreaId)) {
      final bucket = grouped.putIfAbsent(
        HaFloor.unassignedId,
        () => <HaArea>[],
      );
      if (!bucket.any((a) => a.id == unassignedAreaId)) {
        bucket.add(
          const HaArea(
            id: unassignedAreaId,
            name: '未分配区域',
            floorName: '未分配楼层',
          ),
        );
      }
    }

    final keys = grouped.keys.toList()
      ..sort((a, b) {
        final levelA = a == HaFloor.unassignedId
            ? 9999
            : (floorLevels[a] ?? 0);
        final levelB = b == HaFloor.unassignedId
            ? 9999
            : (floorLevels[b] ?? 0);
        return levelA.compareTo(levelB);
      });

    return keys
        .map(
          (key) => HaFloor(
            id: key,
            name: key == HaFloor.unassignedId
                ? '未分配楼层'
                : (floorNames[key] ?? '楼层'),
            level: key == HaFloor.unassignedId ? 9999 : (floorLevels[key] ?? 0),
            areas: List<HaArea>.unmodifiable(grouped[key]!),
          ),
        )
        .toList(growable: false);
  }

  /// 离线设备或处于告警状态的传感器视为「异常」，首页展示提醒。
  bool _isProblem(HaEntity entity) {
    if (entity.isUnavailable) return true;

    const alertClasses = <String>{
      'problem',
      'safety',
      'smoke',
      'gas',
      'moisture',
    };
    if (alertClasses.contains(entity.deviceClass)) {
      return entity.isOn || entity.state == 'problem';
    }
    return false;
  }
}
