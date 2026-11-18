import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 保存的连接凭证。token 为 HA Long-Lived Access Token。
class HaConnectionConfig {
  const HaConnectionConfig({required this.baseUrl, required this.token});

  final String baseUrl;
  final String token;
}

/// 凭证与非敏感偏好统一走安全存储，避免引入额外依赖。
/// - Android：EncryptedSharedPreferences
/// - iOS：Keychain（first_unlock_this_device）
class SecureStorage {
  SecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _storage;

  static const _kBaseUrl = 'ha_base_url';
  static const _kToken = 'ha_token';
  static const _kThemeMode = 'theme_mode';
  static const _kFavorites = 'favorite_entities';
  static const _kHidden = 'hidden_entities';

  Future<HaConnectionConfig?> readConfig() async {
    final url = await _storage.read(key: _kBaseUrl);
    final token = await _storage.read(key: _kToken);
    if (url == null || url.isEmpty || token == null || token.isEmpty) {
      return null;
    }
    return HaConnectionConfig(baseUrl: url, token: token);
  }

  Future<void> saveConfig(HaConnectionConfig config) async {
    await Future.wait([
      _storage.write(key: _kBaseUrl, value: config.baseUrl),
      _storage.write(key: _kToken, value: config.token),
    ]);
  }

  Future<void> clearConfig() async {
    await Future.wait([
      _storage.delete(key: _kBaseUrl),
      _storage.delete(key: _kToken),
    ]);
  }

  /// 主题：'system' | 'light' | 'dark'
  Future<String?> readThemeMode() => _storage.read(key: _kThemeMode);

  Future<void> saveThemeMode(String value) =>
      _storage.write(key: _kThemeMode, value: value);

  Future<Set<String>> readFavorites() async {
    final raw = await _storage.read(key: _kFavorites);
    if (raw == null || raw.isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.whereType<String>().toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> saveFavorites(Set<String> ids) =>
      _storage.write(key: _kFavorites, value: jsonEncode(ids.toList()));

  /// 用户在「设置」中主动隐藏的实体 ID。
  Future<Set<String>> readHidden() async {
    final raw = await _storage.read(key: _kHidden);
    if (raw == null || raw.isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.whereType<String>().toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> saveHidden(Set<String> ids) =>
      _storage.write(key: _kHidden, value: jsonEncode(ids.toList()));
}
