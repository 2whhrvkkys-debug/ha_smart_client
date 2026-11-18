import 'package:flutter/material.dart';
import 'package:ha_smart_client/core/models/ha_control.dart';
import 'package:ha_smart_client/core/models/ha_entity.dart';
import 'package:ha_smart_client/core/utils/ha_icons.dart';
import 'package:ha_smart_client/state/ha_provider.dart';
import 'package:ha_smart_client/widgets/cards/card_scaffold.dart';
import 'package:provider/provider.dart';

/// 影音卡片：播放控制、进度、音量与音源切换。
class MediaCard extends StatelessWidget {
  const MediaCard({required this.entity, super.key});

  final HaEntity entity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ha = context.read<HaProvider>();
    final cap = entity.capability;
    final attrs = entity.attributes;

    final title = (attrs['media_title'] as String?) ?? entity.displayName;
    final artist = (attrs['media_artist'] as String?) ?? '';
    final position = (attrs['media_position'] as num?)?.toDouble();
    final duration = (attrs['media_duration'] as num?)?.toDouble();
    final volume = (attrs['volume_level'] as num?)?.toDouble() ?? 0.0;
    final source = attrs['source'] as String?;
    final playing = entity.state == 'playing';
    final enabled = !entity.isUnavailable;

    return EntityCardShell(
      entity: entity,
      subtitle: artist.isEmpty ? title : '$title · $artist',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  HaIcons.forEntity(entity),
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      artist.isEmpty ? '暂无播放信息' : artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (duration != null && duration > 0) ...<Widget>[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ((position ?? 0) / duration).clamp(0.0, 1.0),
                minHeight: 4,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded),
                onPressed: enabled && cap.supports(HaFeatures.previousTrack)
                    ? () => runHaAction(context, () => ha.mediaPrevious(entity))
                    : null,
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: enabled
                    ? () => runHaAction(
                          context,
                          () => playing
                              ? ha.mediaPause(entity)
                              : ha.mediaPlay(entity),
                        )
                    : null,
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: theme.colorScheme.primary,
                  child: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: theme.colorScheme.onPrimary,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded),
                onPressed: enabled && cap.supports(HaFeatures.nextTrack)
                    ? () => runHaAction(context, () => ha.mediaNext(entity))
                    : null,
              ),
            ],
          ),
          if (cap.supports(HaFeatures.volume)) ...<Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.volume_down_outlined,
                    size: 18, color: theme.colorScheme.onSurfaceVariant),
                Expanded(
                  child: HaSlider(
                    value: volume * 100,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    onSubmitted: (value) => runHaAction(
                      context,
                      () => ha.setVolume(entity, value / 100),
                    ),
                  ),
                ),
                Icon(Icons.volume_up_outlined,
                    size: 18, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ],
          if (cap.supports(HaFeatures.selectSource) &&
              cap.presetModes.isNotEmpty) ...<Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: PopupMenuButton<String>(
                enabled: enabled,
                onSelected: (value) =>
                    runHaAction(context, () => ha.setSource(entity, value)),
                itemBuilder: (_) => cap.presetModes
                    .map(
                      (item) => PopupMenuItem<String>(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(growable: false),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.input_outlined,
                        size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      source ?? '切换音源',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
