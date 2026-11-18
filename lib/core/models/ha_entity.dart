import 'package:flutter/foundation.dart';
import 'package:ha_smart_client/core/models/ha_control.dart';

/// HA 实体：一份 state + 合并后的 registry 元数据。
/// 控制能力由 domain / supported_features 实时推导，便于后续新增 domain 时零改动卡片。
@immutable
class HaEntity {
  const HaEntity({
    required this.entityId,
    required this.state,
    required this.attributes,
    this.lastChanged,
    this.lastUpdated,
    this.context,
    this.deviceId,
    this.areaId,
    this.label,
    this.originalName,
    this.friendlyName,
    this.hiddenBy,
    this.disabledBy,
    this.entityCategory,
    this.platform,
    this.icon,
  });

  static const Object _unset = Object();

  final String entityId;
  final String state;
  final Map<String, dynamic> attributes;
  final DateTime? lastChanged;
  final DateTime? lastUpdated;
  final Map<String, dynamic>? context;

  // ---- registry 元数据（来自 entity registry）----
  final String? deviceId;
  final String? areaId;
  final String? label;
  final String? originalName;
  final String? friendlyName;
  final String? hiddenBy;
  final String? disabledBy;
  final String? entityCategory;
  final String? platform;
  final String? icon;

  factory HaEntity.fromStateJson(Map<String, dynamic> json) {
    final rawAttrs = json['attributes'];
    return HaEntity(
      entityId: (json['entity_id'] as String?) ?? '',
      state: (json['state'] as String?) ?? 'unknown',
      attributes: rawAttrs is Map
          ? Map<String, dynamic>.from(rawAttrs)
          : <String, dynamic>{},
      lastChanged: _parseDate(json['last_changed']),
      lastUpdated: _parseDate(json['last_updated']),
      context: json['context'] is Map
          ? Map<String, dynamic>.from(json['context'] as Map)
          : null,
    );
  }

  /// 把 entity registry 信息合并进实体（localStorage 的实体注册表）。
  HaEntity mergeRegistry(Map<String, dynamic> reg) {
    final labels = reg['labels'];
    final firstLabel = labels is List && labels.isNotEmpty
        ? labels.first.toString()
        : null;
    final regName = reg['name'] as String?;

    return copyWith(
      deviceId: (reg['device_id'] as String?) ?? deviceId,
      areaId: (reg['area_id'] as String?) ?? areaId,
      label: firstLabel ?? label,
      friendlyName: regName ?? friendlyName,
      originalName: (reg['original_name'] as String?) ?? originalName,
      // 新版 HA 用 hidden_by（integration/user），旧版用 hidden 布尔值。
      hiddenBy: reg.containsKey('hidden_by')
          ? reg['hidden_by'] as String?
          : (reg['hidden'] == true ? 'legacy' : hiddenBy),
      disabledBy: reg.containsKey('disabled_by') ? reg['disabled_by'] as String? : disabledBy,
      entityCategory:
          (reg['entity_category'] as String?) ?? entityCategory,
      platform: (reg['platform'] as String?) ?? platform,
      icon: (reg['icon'] as String?) ?? icon,
    );
  }

  /// WebSocket state_changed 增量更新：只替换 state / attributes / 时间戳。
  HaEntity copyWithState({
    required String state,
    required Map<String, dynamic> attributes,
    DateTime? lastChanged,
    DateTime? lastUpdated,
  }) {
    return copyWith(
      state: state,
      attributes: attributes,
      lastChanged: lastChanged,
      lastUpdated: lastUpdated,
    );
  }

  HaEntity copyWith({
    String? state,
    Map<String, dynamic>? attributes,
    Object? lastChanged = _unset,
    Object? lastUpdated = _unset,
    Object? deviceId = _unset,
    Object? areaId = _unset,
    Object? label = _unset,
    Object? originalName = _unset,
    Object? friendlyName = _unset,
    Object? hiddenBy = _unset,
    Object? disabledBy = _unset,
    Object? entityCategory = _unset,
    Object? platform = _unset,
    Object? icon = _unset,
  }) {
    return HaEntity(
      entityId: entityId,
      state: state ?? this.state,
      attributes: attributes ?? this.attributes,
      lastChanged: identical(lastChanged, _unset)
          ? this.lastChanged
          : lastChanged as DateTime?,
      lastUpdated: identical(lastUpdated, _unset)
          ? this.lastUpdated
          : lastUpdated as DateTime?,
      context: context,
      deviceId: _resolve(deviceId, this.deviceId),
      areaId: _resolve(areaId, this.areaId),
      label: _resolve(label, this.label),
      originalName: _resolve(originalName, this.originalName),
      friendlyName: _resolve(friendlyName, this.friendlyName),
      hiddenBy: _resolve(hiddenBy, this.hiddenBy),
      disabledBy: _resolve(disabledBy, this.disabledBy),
      entityCategory: _resolve(entityCategory, this.entityCategory),
      platform: _resolve(platform, this.platform),
      icon: _resolve(icon, this.icon),
    );
  }

  // ---- 派生属性 ----

  String get domain => entityId.contains('.')
      ? entityId.substring(0, entityId.indexOf('.'))
      : entityId;

  String get objectId => entityId.contains('.')
      ? entityId.substring(entityId.indexOf('.') + 1)
      : entityId;

  /// 显示名优先级：用户标签 > registry 名称 > state 友好名 > objectId。
  String get displayName {
    if (label != null && label!.isNotEmpty) return label!;
    if (friendlyName != null && friendlyName!.isNotEmpty) return friendlyName!;
    final attrName = attributes['friendly_name'];
    if (attrName is String && attrName.isNotEmpty) return attrName;
    return _humanize(objectId);
  }

  String? get unit => attributes['unit_of_measurement'] as String?;

  String get deviceClass => (attributes['device_class'] as String?) ?? '';

  bool get isUnavailable => state == 'unavailable';

  bool get isUnknown => state == 'unknown';

  /// 统一「开/关」语义：不同 domain 的开启状态不一致。
  bool get isOn {
    return switch (domain) {
      'cover' => state == 'open' || state == 'opening',
      'lock' => state == 'unlocked',
      'media_player' => state == 'playing' || state == 'on',
      'vacuum' => state == 'cleaning',
      'person' || 'device_tracker' => state == 'home',
      _ => state == 'on',
    };
  }

  /// 是否展示给用户：过滤 hidden / disabled，但保留 unavailable（离线设备需可见）。
  bool get isVisible => hiddenBy == null && disabledBy == null;

  /// 按 domain 推导控制能力。新增 domain 只需在此扩展。
  HaControlCapability get capability {
    final f = ((attributes['supported_features'] as num?) ?? 0).toInt();

    List<String> listOf(String key) {
      final value = attributes[key];
      if (value is List) return value.whereType<String>().toList(growable: false);
      return const <String>[];
    }

    switch (domain) {
      case 'light':
        final features = <String>{};
        if (f & 1 != 0) features.add(HaFeatures.brightness);
        if (f & 2 != 0) features.add(HaFeatures.colorTemp);
        if (f & 4 != 0) features.add(HaFeatures.effect);
        if (f & 8 != 0) features.add(HaFeatures.rgb);
        return HaControlCapability(type: HaControlType.toggle, features: features);

      case 'switch':
      case 'input_boolean':
      case 'fan':
        return const HaControlCapability(type: HaControlType.toggle);

      case 'cover':
        final features = <String>{};
        if (f & 1 != 0) features.add(HaFeatures.open);
        if (f & 2 != 0) features.add(HaFeatures.close);
        if (f & 4 != 0) features.add(HaFeatures.stop);
        if (f & 8 != 0) features.add(HaFeatures.position);
        if (f & 16 != 0) features.add(HaFeatures.tilt);
        return HaControlCapability(type: HaControlType.cover, features: features);

      case 'climate':
        final features = <String>{};
        if (f & 1 != 0) features.add(HaFeatures.targetTemperature);
        if (f & 4 != 0) features.add(HaFeatures.fanMode);
        if (f & 8 != 0) features.add(HaFeatures.presetMode);
        if (f & 16 != 0) features.add(HaFeatures.swingMode);
        return HaControlCapability(
          type: HaControlType.climate,
          features: features,
          hvacModes: listOf('hvac_modes'),
          presetModes: listOf('preset_modes'),
          fanModes: listOf('fan_modes'),
          swingModes: listOf('swing_modes'),
          minTemp: (attributes['min_temp'] as num?)?.toDouble(),
          maxTemp: (attributes['max_temp'] as num?)?.toDouble(),
          tempStep: (attributes['target_temp_step'] as num?)?.toDouble() ?? 0.5,
        );

      case 'lock':
        return const HaControlCapability(type: HaControlType.lock);

      case 'media_player':
        final features = <String>{};
        if (f & 1 != 0) features.add(HaFeatures.pause);
        if (f & 4 != 0) features.add(HaFeatures.volume);
        if (f & 8 != 0) features.add(HaFeatures.mute);
        if (f & 16 != 0) features.add(HaFeatures.previousTrack);
        if (f & 32 != 0) features.add(HaFeatures.nextTrack);
        if (f & 1024 != 0) features.add(HaFeatures.selectSource);
        return HaControlCapability(
          type: HaControlType.media,
          features: features,
          presetModes: listOf('source_list'),
        );

      // 场景 / 脚本 / 按钮 / 自动化：均为「执行一次」语义。
      case 'scene':
      case 'script':
      case 'button':
      case 'automation':
        return const HaControlCapability(type: HaControlType.scene);

      default:
        // sensor / binary_sensor / person / device_tracker 等一律只读。
        return HaControlCapability.none;
    }
  }

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  static String? _resolve(Object? value, String? fallback) =>
      identical(value, _unset) ? fallback : value as String?;

  static String _humanize(String id) {
    return id
        .replaceAll(RegExp(r'[._]+'), ' ')
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  @override
  String toString() => 'HaEntity($entityId: $state)';
}
