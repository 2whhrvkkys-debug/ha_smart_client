import 'package:ha_smart_client/core/models/ha_entity.dart';

/// 展示层格式化工具：状态文案、单位、域名、诊断实体识别。
class HaFormat {
  const HaFormat._();

  /// 诊断/配置类实体不进入主设备网格，聚合到「设备详情」展示。
  static bool isDiagnostic({
    required String entityId,
    String? entityCategory,
  }) {
    if (entityCategory == 'diagnostic' || entityCategory == 'config') return true;
    final objectId = entityId.split('.').last.toLowerCase();
    const keywords = <String>[
      'last_seen',
      'linkquality',
      'link_quality',
      'signal_strength',
      'rssi',
      'lqi',
      'uptime',
      'ip_address',
      'battery',
      'battery_level',
      'battery_voltage',
      'device_temperature',
    ];
    return keywords.any(objectId.contains);
  }

  /// 把下划线 ID 转为人类可读名称。
  static String humanize(String id) {
    final words = id.replaceAll(RegExp(r'[._]+'), ' ').trim();
    if (words.isEmpty) return id;
    return words
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  static String domainName(String domain) {
    const names = <String, String>{
      'light': '灯光',
      'switch': '开关',
      'cover': '窗帘 / 卷帘',
      'climate': '空调 / 温控',
      'lock': '门锁',
      'media_player': '影音',
      'scene': '场景',
      'script': '脚本',
      'sensor': '传感器',
      'binary_sensor': '传感器',
      'fan': '风扇',
      'button': '按钮',
      'vacuum': '扫地机',
      'camera': '摄像头',
      'number': '数值',
      'select': '选项',
      'input_boolean': '开关',
      'automation': '自动化',
      'person': '人员',
      'device_tracker': '定位',
      'weather': '天气',
      'sun': '太阳',
    };
    return names[domain] ?? HaFormat.humanize(domain);
  }

  /// sensor / binary_sensor 的主展示值（含单位）。
  static String sensorValue(HaEntity e) {
    final unit = (e.attributes['unit_of_measurement'] as String?) ?? '';
    final value = e.state;
    if (value == 'unavailable') return '不可用';
    if (value == 'unknown') return '未知';
    if (unit.isEmpty) return value;
    return '$value $unit';
  }

  /// 任意实体的一行状态摘要，用于列表副标题。
  static String stateLabel(HaEntity e) {
    final s = e.state.toLowerCase();
    if (s == 'unavailable') return '不可用';
    if (s == 'unknown') return '未知';

    switch (e.domain) {
      case 'light':
      case 'switch':
      case 'input_boolean':
      case 'fan':
        return s == 'on' ? '已开启' : '已关闭';
      case 'cover':
        return switch (s) {
          'open' => '已打开',
          'opening' => '打开中…',
          'closed' => '已关闭',
          'closing' => '关闭中…',
          _ => HaFormat.humanize(s),
        };
      case 'lock':
        return switch (s) {
          'locked' => '已上锁',
          'unlocking' => '解锁中…',
          'unlocked' => '已解锁',
          'locking' => '上锁中…',
          _ => HaFormat.humanize(s),
        };
      case 'climate':
        final target = e.attributes['temperature'];
        final current = e.attributes['current_temperature'];
        if (current is num) return '当前 ${_num(current)}°  目标 ${target is num ? _num(target) : '--'}°';
        if (target is num) return '目标 ${_num(target)}°';
        return HaFormat.humanize(s);
      case 'media_player':
        return switch (s) {
          'playing' => '正在播放',
          'paused' => '已暂停',
          'idle' => '待机',
          'buffering' => '缓冲中…',
          'on' => '已开启',
          'off' => '已关闭',
          _ => HaFormat.humanize(s),
        };
      case 'scene':
        return '一键触发';
      case 'script':
        return '点击执行';
      case 'sensor':
      case 'binary_sensor':
        return sensorValue(e);
      case 'vacuum':
        return switch (s) {
          'cleaning' => '清扫中',
          'docked' => '待机中',
          'returning' => '回充中',
          _ => HaFormat.humanize(s),
        };
      default:
        return HaFormat.humanize(s);
    }
  }

  /// 相对时间："刚刚 / 3 分钟前 / 2 小时前"。
  static String relativeTime(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time.toLocal());
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    return '${diff.inDays} 天前';
  }

  static String _num(num value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }
}
