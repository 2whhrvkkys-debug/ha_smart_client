import 'package:flutter/material.dart'
    show Alignment, Color, IconData, Icons, LinearGradient;

/// 壁纸预设：用纯渐变实现，零图片资源依赖（assets 目录为空）。
///
/// 每张壁纸都有 id / 名称 / 渐变配色 / 代表图标，用户可在「设置 → 壁纸」中切换，
/// 选择会经由 HaProvider → SecureStorage 持久化，重启后自动恢复。
class WallpaperPreset {
  const WallpaperPreset({
    required this.id,
    required this.name,
    required this.colors,
    required this.icon,
  });

  final String id;
  final String name;
  final List<Color> colors;
  final IconData icon;

  /// 上深下浅的纵向渐变，与 SmartThings 主界面的观感一致。
  LinearGradient get gradient => LinearGradient(
        colors: colors,
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
}

class AppWallpapers {
  const AppWallpapers._();

  static const String defaultId = 'blush';

  static const List<WallpaperPreset> presets = <WallpaperPreset>[
    WallpaperPreset(
      id: 'blush',
      name: '樱花粉',
      colors: <Color>[Color(0xFFEBA9BC), Color(0xFFFBDDE4)],
      icon: Icons.favorite_outline,
    ),
    WallpaperPreset(
      id: 'ocean',
      name: '海盐蓝',
      colors: <Color>[Color(0xFF8EC5E8), Color(0xFFE3F3FB)],
      icon: Icons.waves_outlined,
    ),
    WallpaperPreset(
      id: 'lavender',
      name: '薰衣草',
      colors: <Color>[Color(0xFFB6A6E6), Color(0xFFEDE7FB)],
      icon: Icons.auto_awesome_outlined,
    ),
    WallpaperPreset(
      id: 'mint',
      name: '薄荷绿',
      colors: <Color>[Color(0xFF9AD8BC), Color(0xFFE6F7EF)],
      icon: Icons.eco_outlined,
    ),
    WallpaperPreset(
      id: 'peach',
      name: '蜜桃橙',
      colors: <Color>[Color(0xFFF5BD97), Color(0xFFFDF0E6)],
      icon: Icons.wb_sunny_outlined,
    ),
    WallpaperPreset(
      id: 'slate',
      name: '石墨灰',
      colors: <Color>[Color(0xFFB7BEC9), Color(0xFFE8EBF0)],
      icon: Icons.brightness_auto_outlined,
    ),
    WallpaperPreset(
      id: 'midnight',
      name: '深夜蓝',
      colors: <Color>[Color(0xFF2E3B63), Color(0xFF66739C)],
      icon: Icons.nightlight_outlined,
    ),
  ];

  /// 按 id 查找壁纸，未知 id 回退到默认（樱花粉）。
  static WallpaperPreset byId(String? id) {
    for (final preset in presets) {
      if (preset.id == id) return preset;
    }
    return presets.first;
  }
}
