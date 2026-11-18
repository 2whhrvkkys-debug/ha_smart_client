import 'package:flutter/material.dart';
import 'package:ha_smart_client/core/models/ha_entity.dart';
import 'package:ha_smart_client/core/utils/ha_format.dart';
import 'package:ha_smart_client/core/utils/ha_icons.dart';
import 'package:ha_smart_client/state/ha_provider.dart';
import 'package:provider/provider.dart';

/// 统一处理控制指令失败提示，避免每张卡片重复样板代码。
Future<void> runHaAction(
  BuildContext context,
  Future<void> Function() action, {
  String prefix = '操作失败',
}) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$prefix：$e')),
      );
    }
  }
}

/// 所有实体卡片的统一外壳：图标徽章 + 名称 + 状态 + 收藏星标 + 自定义内容区。
class EntityCardShell extends StatelessWidget {
  const EntityCardShell({
    required this.entity,
    required this.child,
    this.subtitle,
    this.onTap,
    super.key,
  });

  final HaEntity entity;
  final Widget child;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final favorite = context.select<HaProvider, bool>(
      (h) => h.isFavorite(entity.entityId),
    );
    final ha = context.read<HaProvider>();

    final tint = entity.isUnavailable
        ? theme.colorScheme.error
        : (entity.isOn ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: tint.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(HaIcons.forEntity(entity), size: 22, color: tint),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          entity.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle ?? HaFormat.stateLabel(entity),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: entity.isUnavailable
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (entity.isUnavailable)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        HaIcons.offline,
                        size: 16,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                    icon: Icon(
                      favorite ? HaIcons.favorite : HaIcons.favoriteOutline,
                      size: 18,
                      color: favorite
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                    ),
                    tooltip: favorite ? '取消收藏' : '收藏',
                    onPressed: () => ha.toggleFavorite(entity.entityId),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// 拖动时只更新本地值，松手后才提交服务调用，避免刷屏请求。
class HaSlider extends StatefulWidget {
  const HaSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onSubmitted,
    this.divisions,
    this.labelBuilder,
    super.key,
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onSubmitted;
  final int? divisions;
  final String Function(double value)? labelBuilder;

  @override
  State<HaSlider> createState() => _HaSliderState();
}

class _HaSliderState extends State<HaSlider> {
  late double _value = widget.value;

  @override
  void didUpdateWidget(covariant HaSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) _value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Slider(
      value: _value.clamp(widget.min, widget.max).toDouble(),
      min: widget.min,
      max: widget.max,
      divisions: widget.divisions,
      label: widget.labelBuilder?.call(_value),
      onChanged: (value) => setState(() => _value = value),
      onChangeEnd: widget.onSubmitted,
    );
  }
}
