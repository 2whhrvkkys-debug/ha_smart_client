import 'package:flutter/foundation.dart';

/// 房间 / 区域，内置楼层归属（floor + room 一体建模）。
@immutable
class HaArea {
  const HaArea({
    required this.id,
    required this.name,
    this.floorId,
    this.floorName,
    this.icon,
    this.level,
  });

  final String id;
  final String name;
  final String? floorId;
  final String? floorName;
  final String? icon;
  final int? level;

  factory HaArea.fromRegistryJson(
    Map<String, dynamic> json, {
    String? floorName,
    int? level,
  }) {
    return HaArea(
      id: (json['area_id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '未命名房间',
      floorId: json['floor_id'] as String?,
      floorName: floorName,
      icon: json['icon'] as String?,
      level: level ?? (json['level'] as num?)?.toInt(),
    );
  }

  String get floorLabel => floorName ?? '未分配楼层';

  @override
  String toString() => 'HaArea($name @ $floorLabel)';
}

/// 楼层分组（聚合算法产物），用于 Rooms 页的楼层 → 房间树。
@immutable
class HaFloor {
  const HaFloor({
    required this.id,
    required this.name,
    required this.level,
    required this.areas,
  });

  /// 未分配楼层的虚拟分组 ID。
  static const String unassignedId = '__unassigned__';

  final String id;
  final String name;
  final int level;
  final List<HaArea> areas;

  bool get isUnassigned => id == unassignedId;
}
