import 'package:flutter/foundation.dart';

/// HA 设备：一个设备可聚合多个实体（如空调：温控 + 风速 + 当前温度传感器）。
@immutable
class HaDevice {
  const HaDevice({
    required this.id,
    required this.name,
    this.areaId,
    this.manufacturer,
    this.model,
    this.swVersion,
    this.hwVersion,
    this.icon,
    this.viaDeviceId,
    this.entityIds = const <String>[],
  });

  final String id;
  final String? name;
  final String? areaId;
  final String? manufacturer;
  final String? model;
  final String? swVersion;
  final String? hwVersion;
  final String? icon;
  final String? viaDeviceId;
  final List<String> entityIds;

  factory HaDevice.fromRegistryJson(Map<String, dynamic> json) {
    final rawEntities = json['entities'];
    return HaDevice(
      id: (json['id'] as String?) ?? '',
      name: json['name'] as String?,
      areaId: json['area_id'] as String?,
      manufacturer: json['manufacturer'] as String?,
      model: json['model'] as String?,
      swVersion: json['sw_version'] as String?,
      hwVersion: json['hw_version'] as String?,
      icon: json['icon'] as String?,
      viaDeviceId: json['via_device_id'] as String?,
      entityIds: rawEntities is List
          ? rawEntities.whereType<String>().toList(growable: false)
          : const <String>[],
    );
  }

  String get displayName {
    if (name != null && name!.isNotEmpty) return name!;
    if (model != null && model!.isNotEmpty) return model!;
    return '未命名设备';
  }

  String get subtitle {
    final parts = <String>[
      if (manufacturer != null && manufacturer!.isNotEmpty) manufacturer!,
      if (model != null && model!.isNotEmpty) model!,
    ];
    return parts.join(' · ');
  }
}
