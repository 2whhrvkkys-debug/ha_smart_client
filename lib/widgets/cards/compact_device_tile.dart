import 'package:flutter/material.dart';
import 'package:ha_smart_client/core/errors/ha_exception.dart';
import 'package:ha_smart_client/core/models/ha_control.dart';
import 'package:ha_smart_client/core/models/ha_entity.dart';
import 'package:ha_smart_client/core/utils/ha_format.dart';
import 'package:ha_smart_client/core/utils/ha_icons.dart';
import 'package:ha_smart_client/state/ha_provider.dart';
import 'package:ha_smart_client/widgets/cards/entity_card.dart';
import 'package:provider/provider.dart';

/// SmartThings 风格紧凑设备卡片：两列网格中的一块「磁铁」。
///
/// 外观：浅色圆角板，左侧设备名 + 状态，右侧圆角图标徽章。
/// 交互：点整卡弹出完整控制面板（复用 [EntityCard]，不丢失亮度/模式等高级控制）；
/// 点右侧图标徽章则对可控实体直接一键开关，符合 SmartThings 的手感。
class CompactDeviceTile extends StatelessWidget {
  const CompactDeviceTile({required this.entity, super.key});

  final HaEntity entity;

  bool get _isToggle => entity.capability.type == HaControlType.toggle;
  bool get _isScene => entity.capability.type == HaControlType.scene;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final enabled = !entity.isUnavailable;
    final active = entity.isOn && enabled;

    final cardBg = isDark
        ? Colors.black.withOpacity(0.32)
        : Colors.white.withOpacity(0.82);
    final nameColor = isDark ? Colors.white : const Color(0xFF2C2430);
    final stateColor = isDark
        ? Colors.white.withOpacity(0.68)
        : const Color(0xFF8C8290);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _showDetail(context),
        child: Container(
          height: 82,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.16 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      entity.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: nameColor,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _stateText(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: stateColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                height: 44,
                child: (_isToggle || _isScene) && enabled
                    ? IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.expand(),
                        tooltip: _isScene ? '执行场景' : (active ? '关闭' : '开启'),
                        onPressed: () => _quickAction(context),
                        icon: Container(
                          decoration: BoxDecoration(
                            color: active
                                ? theme.colorScheme.primaryContainer
                                : (isDark
                                    ? Colors.white.withOpacity(0.10)
                                    : Colors.black.withOpacity(0.05)),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            HaIcons.forEntity(entity),
                            size: 22,
                            color: active
                                ? theme.colorScheme.onPrimaryContainer
                                : (isDark ? Colors.white : const Color(0xFF6E6472)),
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.10)
                              : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          HaIcons.forEntity(entity),
                          size: 22,
                          color: isDark ? Colors.white : const Color(0xFF6E6472),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _stateText() {
    if (entity.isUnavailable) return '不可用';
    if (entity.isUnknown) return '未知';
    if (_isToggle) return entity.isOn ? '开' : '关';
    if (_isScene) return '点击执行';
    if (entity.domain == 'sensor') return HaFormat.sensorValue(entity);
    if (entity.domain == 'binary_sensor') return entity.isOn ? '触发' : '正常';
    return HaFormat.stateLabel(entity);
  }

  Future<void> _quickAction(BuildContext context) async {
    final ha = context.read<HaProvider>();
    try {
      if (_isScene) {
        await ha.activate(entity);
      } else if (_isToggle) {
        await (entity.isOn ? ha.turnOff(entity) : ha.turnOn(entity));
      }
    } on HaException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('操作失败：${e.message}')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('操作失败：$e')));
      }
    }
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                entity.displayName,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              EntityCard(entity: entity),
            ],
          ),
        ),
      ),
    );
  }
}
