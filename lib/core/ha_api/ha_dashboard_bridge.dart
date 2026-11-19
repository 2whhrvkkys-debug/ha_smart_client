import 'package:flutter/foundation.dart';
import 'package:ha_smart_client/core/errors/ha_exception.dart';
import 'package:ha_smart_client/core/ha_api/ha_ws_client.dart';

/// 「3D 概览」桥接：把 HA 中名为「3D 概览」的仪表盘所绑定的实体
/// 作为 App 的实体白名单。这样 App 只展示这一个仪表盘里的设备，
/// 而不是 HA 里成百上千个全部实体；用户在 HA 里改这个仪表盘，App
/// 下次连接/刷新会自动跟随。
///
/// 解析覆盖常见的 Lovelace 结构：cards / sections / views / horizontal-stack
/// 等容器，以及 button-card / tile / f3d-card(bindings) 等实体字段。
class OverviewBridge {
  const OverviewBridge(this._ws);

  /// 目标仪表盘的 url_path。与用户 HA 中「3D 概览」一致。
  static const String dashboardUrlPath = '3d-overview';

  /// 无法从 HA 读取仪表盘时的兜底实体（构建时从该仪表盘提取）。
  /// 保证即使 `lovelace/config` 因权限/版本原因失败，App 仍能显示这批设备。
  static const Set<String> fallbackEntityIds = <String>{
    'climate.maxi_cn_2170267256_pdkw00_s_2_air_conditioner',
    'climate.maxi_cn_2170267260_pdkw00_s_2_air_conditioner',
    'climate.maxi_cn_2170267264_pdkw00_s_2_air_conditioner',
    'climate.maxi_cn_2170267272_pdkw00_s_2_air_conditioner',
    'cover.ke_ting_chuang_lian_dian_ji',
    'fan.chu_fang_pai_qi_shan_pai_qi_shan_kai_guan',
    'fan.dian_pu_cxw_400_z5aswi',
    'fan.ke_ting_mi_jia_xun_huan_shan',
    'fan.mi_jia_luo_di_shan',
    'light.can_ting_zhi_neng_kai_guan_d1_can_ting',
    'light.can_ting_zhi_neng_kai_guan_d1_can_ting_2',
    'light.chu_fang_lemeshse_wen_deng_chu_fang_she_deng',
    'light.chu_wu_jian_tong_deng_t3',
    'light.er_zi_zhi_neng_kai_guan_d1_er_zi',
    'light.er_zi_zhi_neng_kai_guan_d1_er_zi_2',
    'light.er_zi_zhi_neng_kai_guan_d1_er_zi_3',
    'light.gong_wei_zhi_neng_yu_ba_yu_ba_zhao_ming',
    'light.guo_dao_she_deng_t2',
    'light.guo_dao_she_deng_t3',
    'light.ke_ting_magic_switch_s1e_3f6a_switch_1',
    'light.ke_ting_magic_switch_s1e_3f6a_switch_2',
    'light.ke_ting_magic_switch_s1e_3f6a_switch_3',
    'light.lemesh_cn_793069493_wy0d02_s_2_light',
    'light.lemesh_cn_888146807_wy0d02_s_2_light',
    'light.lemesh_cn_888155786_wy0d02_s_2_light',
    'light.lemesh_cn_888239723_wy0d02_s_2_light',
    'light.lemesh_cn_888242708_wy0d02_s_2_light',
    'light.mijia_cn_group_1957837499183292417_group3_s_2_light',
    'light.mijia_cn_group_1963588738814717952_group3_s_2_light',
    'light.xuan_guan_zhi_neng_kai_guan_d1_xuan_guan_4',
    'light.xuan_guan_zhi_neng_kai_guan_d1_xuan_guan_5',
    'light.yang_guang_zhao_ming_ling_rui_zhi_neng_deng_pao_diao_guang_diao_se_ban_yang_guang_zhao_ming_ling_rui_zhi_neng_deng_pao_diao_guang_diao_se_ban',
    'light.you_yan_ji_zhao_ming',
    'light.zhu_wei_zhu_wei_deng_dai',
    'light.zhu_wo_zhi_neng_kai_guan_d1_zhu_wo',
    'light.zhu_wo_zhi_neng_kai_guan_d1_zhu_wo_2',
    'lock.desmanlock_500260723872505856_lock',
    'lock.gong_wei_dian_re_shui_qi_kai_guan_kai_guan',
    'media_player.hua_wei_aiyin_xiang_2e_speaker',
    'media_player.ke_ting_tcl_75q10g_pro',
    'scene.chi_jia',
    'scene.hui_jia',
    'sensor.cleargras_cn_blt_3_qctu58644800_dk1_relative_humidity_p_2_2',
    'sensor.cleargras_cn_blt_3_qctu58644800_dk1_temperature_p_2_1',
    'sensor.hey_cn_671422394_h100_electric_power_p_3_6',
    'switch.topwit_cn_2142848705_rzw76_blow_p_4_7',
    'switch.topwit_cn_2142848705_rzw76_ventilation_p_4_8',
    'vacuum.ke_ting_zhui_mi_s10_pro_ultra_ji_jie_bi_ban_zhui_mi_sao_di_ji',
    'valve.chu_fang_fa_men_kong_zhi_qi_zuan_shi_fa_men_kong_zhi_qi_mesh2_0_fa_men_kai_guan',
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
