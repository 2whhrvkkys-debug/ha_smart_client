import 'package:flutter/material.dart' show IconData, Icons;
import 'package:ha_smart_client/core/models/ha_entity.dart';

/// 图标统一映射层。
/// 优先级：registry 自带 mdi: 图标 → device_class → domain → 兜底图标。
///
/// 实现说明：早期版本使用 material_design_icons_flutter（mdi），但该包最后更新于
/// 2023 年，其内部 `class _MdiIconData extends IconData` 在 Dart 3.14（Flutter 3.50）
/// 中因 IconData 变为 final/@RecordUse 而无法编译。为保证“零外部图标依赖 + 长期可维护”，
/// 这里改用 Flutter 内置的 Material Icons，并保留 [HaIcons] 的全部对外 API 不变，
/// 业务代码与卡片组件无需任何改动。若日后要换成真正的 mdi，只需替换本文件的图标来源。
class HaIcons {
  const HaIcons._();

  // 底部导航与通用 UI 图标（Icons.* 均为编译期常量）
  static const IconData navHome = Icons.home;
  static const IconData navDevices = Icons.grid_view;
  static const IconData navRooms = Icons.layers;
  static const IconData navScenes = Icons.star;
  static const IconData navSettings = Icons.settings;
  static const IconData favorite = Icons.star;
  static const IconData favoriteOutline = Icons.star_border;
  static const IconData warning = Icons.error_outline;
  static const IconData offline = Icons.cloud_off;
  static const IconData refresh = Icons.refresh;
  static const IconData logout = Icons.logout;
  static const IconData key = Icons.key;
  static const IconData hidden = Icons.visibility_off;
  static const IconData add = Icons.add;
  static const IconData back = Icons.arrow_back;
  static const IconData chevronRight = Icons.chevron_right;
  static const IconData check = Icons.check;
  static const IconData info = Icons.info_outline;
  static const IconData battery = Icons.battery_full;
  static const IconData code = Icons.code;

  /// 实体卡片图标。
  static IconData forEntity(HaEntity entity) {
    final registered = entity.icon;
    if (registered != null && registered.startsWith('mdi:')) {
      final parsed = fromMdiName(registered.substring(4));
      if (parsed != null) return parsed;
    }
    final byClass = byDeviceClass(entity.deviceClass);
    if (byClass != null) return byClass;
    return forDomain(entity.domain);
  }

  static IconData forDomain(String domain) {
    return switch (domain) {
      'light' => Icons.lightbulb,
      'switch' || 'input_boolean' => Icons.toggle_on,
      'cover' => Icons.blinds,
      'climate' => Icons.device_thermostat,
      'lock' => Icons.lock,
      'media_player' => Icons.speaker,
      'scene' => Icons.star,
      'script' || 'button' || 'automation' => Icons.code,
      'sensor' || 'binary_sensor' => Icons.sensors,
      'fan' => Icons.air,
      'vacuum' => Icons.cleaning_services,
      'camera' => Icons.camera_alt,
      'number' || 'select' => Icons.speed,
      'person' => Icons.person,
      'device_tracker' => Icons.place,
      'weather' => Icons.cloud,
      'sun' => Icons.wb_sunny,
      _ => Icons.help_outline,
    };
  }

  static IconData? byDeviceClass(String deviceClass) {
    return switch (deviceClass) {
      'temperature' => Icons.device_thermostat,
      'humidity' => Icons.water_drop,
      'illuminance' => Icons.wb_sunny,
      'power' || 'energy' || 'current' || 'voltage' => Icons.bolt,
      'battery' => Icons.battery_full,
      'motion' => Icons.directions_run,
      'door' || 'garage_door' => Icons.sensor_door,
      'window' => Icons.blinds,
      'opening' => Icons.door_sliding,
      'occupancy' || 'presence' => Icons.person,
      'plug' || 'outlet' => Icons.power,
      'signal_strength' => Icons.wifi,
      'timestamp' || 'date' => Icons.calendar_today,
      'problem' || 'safety' => Icons.error,
      'smoke' || 'gas' => Icons.local_fire_department,
      'moisture' => Icons.water_drop,
      'pressure' => Icons.speed,
      'wind_speed' => Icons.air,
      'sound' => Icons.volume_up,
      _ => null,
    };
  }

  /// 把 HA registry 中的 "mdi:xxx-yyy" 字符串映射到合适的 Material 图标。
  /// 未收录的名称返回 null，由 [forEntity] 回退到 domain 图标。
  static IconData? fromMdiName(String name) {
    return switch (name) {
      'lightbulb' => Icons.lightbulb,
      'lightbulb-outline' => Icons.lightbulb_outline,
      'ceiling-light' => Icons.lightbulb,
      'toggle-switch' => Icons.toggle_on,
      'power' => Icons.power,
      'window-open' => Icons.blinds,
      'blinds' => Icons.blinds,
      'curtains' => Icons.blinds,
      'thermostat' => Icons.device_thermostat,
      'thermometer' => Icons.device_thermostat,
      'lock' => Icons.lock,
      'lock-open' => Icons.lock_open,
      'speaker' => Icons.speaker,
      'television' => Icons.tv,
      'play' => Icons.play_arrow,
      'pause' => Icons.pause,
      'star' => Icons.star,
      'fan' => Icons.air,
      'robot' => Icons.smart_toy,
      'eye' => Icons.visibility,
      'motion-sensor' => Icons.sensors,
      'weather-sunny' => Icons.wb_sunny,
      'weather-cloudy' => Icons.cloud,
      'flash' => Icons.bolt,
      'water-percent' => Icons.water_drop,
      'battery' => Icons.battery_full,
      'wifi' => Icons.wifi,
      'home' => Icons.home,
      'alert-circle' => Icons.error,
      'cog' => Icons.settings,
      _ => null,
    };
  }
}
