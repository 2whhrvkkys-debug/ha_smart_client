import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ha_smart_client/core/errors/ha_exception.dart';
import 'package:ha_smart_client/core/grouping/entity_aggregator.dart';
import 'package:ha_smart_client/core/ha_api/ha_auth.dart';
import 'package:ha_smart_client/core/ha_api/ha_registry.dart';
import 'package:ha_smart_client/core/ha_api/ha_rest_client.dart';
import 'package:ha_smart_client/core/ha_api/ha_ws_client.dart';
import 'package:ha_smart_client/core/models/ha_entity.dart';
import 'package:ha_smart_client/core/storage/secure_storage.dart';

/// 应用级连接状态。
enum HaConnectionState { unconfigured, connecting, connected, disconnected, error }

/// 全局单一数据源：连接、实体缓存、聚合结果、控制指令、用户偏好。
/// UI 只依赖本类暴露的 getter，不直接访问 REST / WS。
class HaProvider extends ChangeNotifier {
  HaProvider({required SecureStorage storage}) : _storage = storage;

  final SecureStorage _storage;

  HaConnectionState _connection = HaConnectionState.unconfigured;
  HaWsStatus _wsStatus = HaWsStatus.disconnected;
  ThemeMode _themeMode = ThemeMode.system;
  HaServerInfo? _serverInfo;
  String? _lastError;
  String? _baseUrl;
  String? _token;

  HaRestClient? _rest;
  HaWsClient? _ws;
  RegistrySnapshot? _registrySnapshot;

  List<HaEntity> _rawStates = <HaEntity>[];
  AggregatedHome _home = AggregatedHome.empty();
  Set<String> _favorites = <String>{};
  Set<String> _hiddenIds = <String>{};

  bool _isRefreshing = false;
  DateTime? _lastSync;
  Timer? _rebuildTimer;

  // ---------- 对外只读状态 ----------

  HaConnectionState get connection => _connection;
  HaWsStatus get wsStatus => _wsStatus;
  bool get isWsConnected => _wsStatus == HaWsStatus.connected;
  ThemeMode get themeMode => _themeMode;
  HaServerInfo? get serverInfo => _serverInfo;
  String? get lastError => _lastError;
  String? get baseUrl => _baseUrl;
  AggregatedHome get home => _home;

  /// 原始实体（含诊断与被用户隐藏的），供设置页管理隐藏项。
  List<HaEntity> get allRawEntities => List<HaEntity>.unmodifiable(_rawStates);

  bool get isRefreshing => _isRefreshing;
  DateTime? get lastSync => _lastSync;
  bool get isConfigured => _baseUrl != null && _token != null;

  // ---------- 生命周期 ----------

  /// App 启动：恢复主题、收藏、隐藏列表与上次连接。
  Future<void> bootstrap() async {
    _themeMode = _decodeTheme(await _storage.readThemeMode());
    _favorites = await _storage.readFavorites();
    _hiddenIds = await _storage.readHidden();
    notifyListeners();

    final config = await _storage.readConfig();
    if (config == null) return;
    await connect(
      url: config.baseUrl,
      token: config.token,
      persist: false,
    );
  }

  /// 校验凭证 → 拉取全量实体 → 启动 WebSocket 实时订阅。
  Future<void> connect({
    required String url,
    required String token,
    bool persist = true,
  }) async {
    _connection = HaConnectionState.connecting;
    _lastError = null;
    notifyListeners();

    try {
      final normalized = HaAuth.normalizeUrl(url);
      final info = await const HaAuth().verify(
        baseUrl: normalized,
        token: token,
      );

      _ws?.disconnect();
      _rest?.dispose();

      _baseUrl = normalized;
      _token = token;
      _serverInfo = info;
      if (persist) {
        await _storage.saveConfig(
          HaConnectionConfig(baseUrl: normalized, token: token),
        );
      }

      _rest = HaRestClient(baseUrl: normalized, token: token);
      _rawStates = await _rest!.fetchStates();
      _rebuild();

      _ws = HaWsClient(
        baseUrl: normalized,
        token: token,
        onEntityUpdated: _onEntityUpdated,
        onEntityRemoved: _onEntityRemoved,
        onStatusChanged: _onWsStatus,
        onError: _onWsError,
      );
      // 不等待 WS 握手完成：REST 数据已可用，先让用户看到界面。
      unawaited(_ws!.connect());

      _connection = HaConnectionState.connected;
      _lastSync = DateTime.now();
      notifyListeners();
    } on HaAuthException catch (e) {
      // 凭证失效：清除本地配置，回到登录页。
      await _storage.clearConfig();
      _baseUrl = null;
      _token = null;
      _connection = HaConnectionState.unconfigured;
      _lastError = e.message;
      notifyListeners();
    } on HaException catch (e) {
      // 网络类错误：保留配置，进入主界面并显示重连横幅。
      _connection = HaConnectionState.disconnected;
      _lastError = e.message;
      notifyListeners();
    }
  }

  /// 用户取消连接中的等待。
  void cancelConnect() {
    _ws?.disconnect();
    _ws = null;
    _rest?.dispose();
    _rest = null;
    _connection =
        _baseUrl == null ? HaConnectionState.unconfigured : HaConnectionState.disconnected;
    _lastError = null;
    notifyListeners();
  }

  /// 下拉刷新 / 重连：重新拉取全量状态与注册表。
  Future<void> refresh() async {
    final rest = _rest;
    if (rest == null || _isRefreshing) return;

    _isRefreshing = true;
    notifyListeners();
    try {
      _rawStates = await rest.fetchStates();
      await _loadRegistry();
      _lastSync = DateTime.now();
      _lastError = null;
      _rebuild();
    } on HaException catch (e) {
      _lastError = e.message;
      notifyListeners();
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  /// 退出登录：清空凭证与缓存。
  Future<void> logout() async {
    _rebuildTimer?.cancel();
    _ws?.disconnect();
    _ws = null;
    _rest?.dispose();
    _rest = null;
    await _storage.clearConfig();

    _rawStates = <HaEntity>[];
    _home = AggregatedHome.empty();
    _registrySnapshot = null;
    _serverInfo = null;
    _baseUrl = null;
    _token = null;
    _connection = HaConnectionState.unconfigured;
    _wsStatus = HaWsStatus.disconnected;
    _lastError = null;
    notifyListeners();
  }

  // ---------- WebSocket 回调 ----------

  void _onEntityUpdated(HaEntity incoming) {
    final index = _rawStates.indexWhere((e) => e.entityId == incoming.entityId);
    if (index < 0) {
      _rawStates.add(incoming);
    } else {
      // WS 的 new_state 不含 registry 元数据，必须保留旧实体的聚合信息。
      final old = _rawStates[index];
      _rawStates[index] = old.copyWithState(
        state: incoming.state,
        attributes: incoming.attributes,
        lastChanged: incoming.lastChanged,
        lastUpdated: incoming.lastUpdated,
      );
    }
    _scheduleRebuild();
  }

  void _onEntityRemoved(String entityId) {
    _rawStates.removeWhere((e) => e.entityId == entityId);
    _scheduleRebuild();
  }

  void _onWsStatus(HaWsStatus status) {
    _wsStatus = status;
    // 每次连上（含重连）都刷新注册表，保证新增设备/区域可见。
    if (status == HaWsStatus.connected) unawaited(_loadRegistry());
    notifyListeners();
  }

  void _onWsError(Object error) {
    _lastError = error is HaException
        ? error.message
        : '实时连接异常：$error';
    notifyListeners();
  }

  Future<void> _loadRegistry() async {
    final ws = _ws;
    if (ws == null || !ws.isConnected) return;
    try {
      _registrySnapshot = await HaRegistry(ws).load();
      _rebuild();
    } on HaException catch (e) {
      _lastError = '读取设备注册表失败：${e.message}';
      notifyListeners();
    }
  }

  /// 高频 state_changed 合并到 80ms 后一次性通知，避免列表抖动。
  void _scheduleRebuild() {
    _rebuildTimer ??= Timer(const Duration(milliseconds: 80), () {
      _rebuildTimer = null;
      _rebuild();
    });
  }

  void _rebuild() {
    _home = const EntityAggregator().aggregate(
      states: _rawStates,
      registry:
          _registrySnapshot ??
          const RegistrySnapshot(
            entities: <Map<String, dynamic>>[],
            devices: <Map<String, dynamic>>[],
            areas: <Map<String, dynamic>>[],
            floors: <Map<String, dynamic>>[],
          ),
      userHiddenIds: _hiddenIds,
    );
    notifyListeners();
  }

  // ---------- 控制指令（卡片只需调用这些方法） ----------

  Future<void> toggle(HaEntity e) =>
      _service(e.domain, e.isOn ? 'turn_off' : 'turn_on', entityId: e.entityId);

  Future<void> turnOn(HaEntity e) =>
      _service(e.domain, 'turn_on', entityId: e.entityId);

  Future<void> turnOff(HaEntity e) =>
      _service(e.domain, 'turn_off', entityId: e.entityId);

  /// 场景 / 脚本 / 按钮 / 自动化：一键执行。
  Future<void> activate(HaEntity e) {
    final service = switch (e.domain) {
      'button' => 'press',
      'automation' => 'trigger',
      _ => 'turn_on',
    };
    return _service(e.domain, service, entityId: e.entityId);
  }

  // 灯光
  Future<void> setBrightness(HaEntity e, int percent) => _service(
        'light',
        'turn_on',
        entityId: e.entityId,
        data: <String, dynamic>{'brightness_pct': percent},
      );

  Future<void> setColorTemp(HaEntity e, int kelvin) => _service(
        'light',
        'turn_on',
        entityId: e.entityId,
        data: <String, dynamic>{'kelvin': kelvin},
      );

  Future<void> setRgbColor(HaEntity e, int r, int g, int b) => _service(
        'light',
        'turn_on',
        entityId: e.entityId,
        data: <String, dynamic>{'rgb_color': <int>[r, g, b]},
      );

  // 窗帘 / 卷帘
  Future<void> openCover(HaEntity e) =>
      _service('cover', 'open_cover', entityId: e.entityId);

  Future<void> closeCover(HaEntity e) =>
      _service('cover', 'close_cover', entityId: e.entityId);

  Future<void> stopCover(HaEntity e) =>
      _service('cover', 'stop_cover', entityId: e.entityId);

  Future<void> setCoverPosition(HaEntity e, int position) => _service(
        'cover',
        'set_cover_position',
        entityId: e.entityId,
        data: <String, dynamic>{'position': position},
      );

  // 空调 / 温控
  Future<void> setClimateTemperature(HaEntity e, double temperature) => _service(
        'climate',
        'set_temperature',
        entityId: e.entityId,
        data: <String, dynamic>{'temperature': temperature},
      );

  Future<void> setHvacMode(HaEntity e, String mode) => _service(
        'climate',
        'set_hvac_mode',
        entityId: e.entityId,
        data: <String, dynamic>{'hvac_mode': mode},
      );

  Future<void> setPresetMode(HaEntity e, String preset) => _service(
        'climate',
        'set_preset_mode',
        entityId: e.entityId,
        data: <String, dynamic>{'preset_mode': preset},
      );

  Future<void> setFanMode(HaEntity e, String mode) => _service(
        'climate',
        'set_fan_mode',
        entityId: e.entityId,
        data: <String, dynamic>{'fan_mode': mode},
      );

  // 门锁
  Future<void> lock(HaEntity e) =>
      _service('lock', 'lock', entityId: e.entityId);

  Future<void> unlock(HaEntity e) =>
      _service('lock', 'unlock', entityId: e.entityId);

  // 影音
  Future<void> mediaPlay(HaEntity e) =>
      _service('media_player', 'media_play', entityId: e.entityId);

  Future<void> mediaPause(HaEntity e) =>
      _service('media_player', 'media_pause', entityId: e.entityId);

  Future<void> mediaNext(HaEntity e) =>
      _service('media_player', 'media_next_track', entityId: e.entityId);

  Future<void> mediaPrevious(HaEntity e) =>
      _service('media_player', 'media_previous_track', entityId: e.entityId);

  Future<void> setVolume(HaEntity e, double level) => _service(
        'media_player',
        'volume_set',
        entityId: e.entityId,
        data: <String, dynamic>{'volume_level': level},
      );

  Future<void> setSource(HaEntity e, String source) => _service(
        'media_player',
        'select_source',
        entityId: e.entityId,
        data: <String, dynamic>{'source': source},
      );

  /// 统一服务调用：成功后把返回的 state 合并进缓存。
  Future<void> _service(
    String domain,
    String service, {
    String? entityId,
    Map<String, dynamic>? data,
  }) async {
    final rest = _rest;
    if (rest == null) {
      _lastError = '尚未连接到 Home Assistant';
      notifyListeners();
      throw const HaNetworkException('尚未连接到 Home Assistant');
    }

    try {
      final updated = await rest.callService(
        domain: domain,
        service: service,
        entityId: entityId,
        data: data,
      );
      _applyStates(updated);
    } on HaException catch (e) {
      _lastError = e.message;
      notifyListeners();
      rethrow;
    }
  }

  void _applyStates(List<HaEntity> updated) {
    if (updated.isEmpty) return;
    final map = <String, HaEntity>{
      for (final entity in _rawStates) entity.entityId: entity,
    };
    for (final entity in updated) {
      final old = map[entity.entityId];
      map[entity.entityId] = old == null
          ? entity
          : old.copyWithState(
              state: entity.state,
              attributes: entity.attributes,
              lastChanged: entity.lastChanged,
              lastUpdated: entity.lastUpdated,
            );
    }
    _rawStates = map.values.toList();
    _rebuild();
  }

  // ---------- 用户偏好 ----------

  bool isFavorite(String entityId) => _favorites.contains(entityId);

  void toggleFavorite(String entityId) {
    final next = Set<String>.from(_favorites);
    if (!next.remove(entityId)) next.add(entityId);
    _favorites = next;
    unawaited(_storage.saveFavorites(next));
    notifyListeners();
  }

  void setEntityHidden(String entityId, bool hidden) {
    final next = Set<String>.from(_hiddenIds);
    if (hidden) {
      next.add(entityId);
    } else {
      next.remove(entityId);
    }
    _hiddenIds = next;
    unawaited(_storage.saveHidden(next));
    _rebuild();
  }

  bool isHidden(String entityId) => _hiddenIds.contains(entityId);

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    unawaited(_storage.saveThemeMode(mode.name));
    notifyListeners();
  }

  static ThemeMode _decodeTheme(String? raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  @override
  void dispose() {
    _rebuildTimer?.cancel();
    _ws?.disconnect();
    _rest?.dispose();
    super.dispose();
  }
}
