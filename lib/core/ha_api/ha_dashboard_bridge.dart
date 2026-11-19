import 'package:ha_smart_client/core/errors/ha_exception.dart';
import 'package:ha_smart_client/core/ha_api/ha_ws_client.dart';

/// 「3D 未来家」桥接：把 HA 中名为「3D 未来家」的仪表盘（f3d 3D 户型模型）
/// 所绑定的实体作为 App 的实体白名单。这样 App 只展示这一个仪表盘里的设备，
/// 而不是 HA 里成百上千个全部实体；用户在 HA 里改这个仪表盘，App
/// 下次连接/刷新会自动跟随。
///
/// 解析覆盖常见的 Lovelace 结构：cards / sections / views / horizontal-stack
/// 等容器，以及 button-card / tile / f3d-card(bindings) 等实体字段。
class OverviewBridge {
  const OverviewBridge(this._ws);

  /// 目标仪表盘的 url_path。与用户 HA 中「3D 未来家」一致。
  static const String dashboardUrlPath = 'san-wei-hu-xing';

  /// 无法从 HA 读取仪表盘时的兜底实体（构建时从该仪表盘提取）。
  /// 保证即使 `lovelace/config` 因权限/版本原因失败，App 仍能显示这批设备。
  static const Set<String> fallbackEntityIds = <String>{
    'binary_sensor.can_ting_presence_sensor_fp2_presence_sensor_1',
    'binary_sensor.chu_fang_shui_jin_chuan_gan_qi',
    'binary_sensor.ke_ting_aqara_fp1e_ci_chu_you_ren',
    'binary_sensor.linp_cn_blt_3_1mf0g042s4k01_es2_occupancy_status_p_2_1078',
    'binary_sensor.linp_cn_blt_3_1oed2mh2k4g02_es5b_occupancy_status_p_2_1078',
    'binary_sensor.ru_hu_aqara_p100_ci_chu_you_ren',
    'binary_sensor.ru_hu_aqara_p100_men_2',
    'binary_sensor.zhu_wei_zhu_wei_men_chuang_chuan_gan_qi_men',
    'binary_sensor.zhu_wo_aqara_p1_ci_chu_you_ren',
    'climate.maxi_cn_2170267256_pdkw00',
    'climate.maxi_cn_2170267260_pdkw00',
    'climate.maxi_cn_2170267264_pdkw00',
    'climate.maxi_cn_2170267272_pdkw00',
    'climate.maxi_cn_2170269408_pdkw00',
    'climate.maxi_cn_2170269408_pdkw00_s_2_air_conditioner',
    'climate.maxi_cn_2170399100_pdkw00',
    'cover.ke_ting_chuang_lian_dian_ji',
    'fan.chu_fang_pai_qi_shan_pai_qi_shan_kai_guan',
    'fan.ke_ting_mi_jia_xun_huan_shan',
    'fan.mi_jia_luo_di_shan',
    'light.can_ting_zhi_neng_kai_guan_d1_can_ting_2',
    'light.chu_fang_pai_qi_shan_deng_dai_kai_guan',
    'light.chu_wu_jian_tong_deng_t3',
    'light.er_zi_zhi_neng_kai_guan_d1_er_zi',
    'light.er_zi_zhi_neng_kai_guan_d1_er_zi_2',
    'light.er_zi_zhi_neng_kai_guan_d1_er_zi_3',
    'light.guo_dao_she_deng_t2',
    'light.guo_dao_she_deng_t3',
    'light.ke_ting_magic_switch_s1e_3f6a_switch_1',
    'light.mijia_cn_group_1957837499183292417_group3_s_2_light',
    'light.mijia_cn_group_1963588738814717952_group3_s_2_light',
    'light.zhu_wo_zhi_neng_kai_guan_d1_zhu_wo_2',
    'lock.gong_wei_dian_re_shui_qi_kai_guan_kai_guan',
    'media_player.ke_ting_tcl_75q10g_pro',
    'media_player.ke_ting_xiao_ai_yin_xiang',
    'sensor.can_ting_presence_sensor_fp2_light_sensor_light_level',
    'switch.chu_fang_fa_men_kong_zhi_qi',
    'switch.chu_fang_you_yan_ji',
    'switch.chu_fang_zheng_kao_xiang',
    'vacuum.ke_ting_zhui_mi_s10_pro_ultra_ji_jie_bi_ban_zhui_mi_sao_di_ji',
  };

  final HaWsClient _ws;

  /// 返回白名单；读取失败返回 null（调用方回退到 [fallbackEntityIds]）。
  Future<Set<String>?> load() async {
    Map<String, dynamic> config;
    try {
      final response = await _ws.sendCommand(
        'lovelace/config',
        <String, dynamic>{'url_path': dashboardUrlPath},
      );
      final result = response['result'];
      if (result is! Map) return null;
      config = Map<String, dynamic>.from(result);
    } on HaException {
      return null;
    }

    final ids = _collect(config);
    // 只有解析到实体才替换兜底，避免空仪表盘把界面清空。
    return ids.isEmpty ? null : Set<String>.unmodifiable(ids);
  }

  static final RegExp _entityPattern = RegExp(r'^[a-z_]+\.[a-z0-9_]+$');

  /// 递归遍历 Lovelace 配置，收集所有合法的 entity_id。
  static Set<String> _collect(Object? node) {
    final found = <String>{};

    void addEntity(Object? value) {
      if (value is String && _entityPattern.hasMatch(value)) found.add(value);
    }

    void walk(Object? node) {
      if (node is Map) {
        for (final entry in node.entries) {
          final key = entry.key;
          final value = entry.value;

          // 直接实体字段。
          if (key == 'entity' || key == 'entity_id') {
            addEntity(value);
          }
          // 实体数组（含 {entity: xxx} 对象）。
          if (key == 'entities' || key == 'entity_ids') {
            if (value is List) {
              for (final item in value) {
                if (item is String) {
                  addEntity(item);
                } else if (item is Map) {
                  addEntity(item['entity']);
                  addEntity(item['entity_id']);
                }
              }
            }
          }
          // f3d-card / 3D 户型模型的绑定列表。
          if (key == 'bindings' && value is List) {
            for (final item in value) {
              if (item is Map) {
                addEntity(item['entity']);
                addEntity(item['entity_id']);
              }
            }
          }
          // service_data / data 里常带 entity_id，交给递归处理。
          walk(value);
        }
      } else if (node is List) {
        for (final item in node) {
          walk(item);
        }
      }
    }

    walk(node);
    return found;
  }
}
