import 'package:flutter/foundation.dart';

/// 控制能力类型：UI 卡片按此类型自动分发渲染。
enum HaControlType {
  toggle, // light / switch / input_boolean / fan
  cover, // 窗帘 / 卷帘（开、关、停、位置、倾角）
  climate, // 空调 / 温控（模式、目标温度、风速）
  lock, // 门锁（上锁 / 解锁）
  media, // 影音（播放、暂停、切歌、音量）
  scene, // 场景 / 脚本 / 按钮 / 自动化（一键执行）
  none, // 传感器等只读实体
}

/// HA supported_features 位掩码解析后的能力标记， UI 用 [supports] 判断。
class HaFeatures {
  const HaFeatures._();

  static const String brightness = 'brightness';
  static const String colorTemp = 'color_temp';
  static const String rgb = 'rgb';
  static const String effect = 'effect';
  static const String transition = 'transition';
  static const String open = 'open';
  static const String close = 'close';
  static const String stop = 'stop';
  static const String position = 'position';
  static const String tilt = 'tilt';
  static const String pause = 'pause';
  static const String volume = 'volume';
  static const String mute = 'mute';
  static const String previousTrack = 'previous_track';
  static const String nextTrack = 'next_track';
  static const String selectSource = 'select_source';
  static const String targetTemperature = 'target_temperature';
  static const String fanMode = 'fan_mode';
  static const String presetMode = 'preset_mode';
  static const String swingMode = 'swing_mode';
}

/// 由实体 domain + supported_features 推导出的控制能力描述。
@immutable
class HaControlCapability {
  const HaControlCapability({
    required this.type,
    this.features = const <String>{},
    this.hvacModes = const <String>[],
    this.presetModes = const <String>[],
    this.fanModes = const <String>[],
    this.swingModes = const <String>[],
    this.minTemp,
    this.maxTemp,
    this.tempStep,
  });

  final HaControlType type;
  final Set<String> features;
  final List<String> hvacModes;
  final List<String> presetModes;
  final List<String> fanModes;
  final List<String> swingModes;
  final double? minTemp;
  final double? maxTemp;
  final double? tempStep;

  static const HaControlCapability none = HaControlCapability(
    type: HaControlType.none,
  );

  bool get isReadOnly => type == HaControlType.none;
  bool supports(String feature) => features.contains(feature);
}
