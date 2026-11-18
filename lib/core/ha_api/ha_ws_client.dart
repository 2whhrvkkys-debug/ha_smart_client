import 'dart:async';
import 'dart:convert';

import 'package:ha_smart_client/core/errors/ha_exception.dart';
import 'package:ha_smart_client/core/models/ha_entity.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket 连接状态，驱动 UI 的顶部横幅与重连动画。
enum HaWsStatus { disconnected, connecting, connected, reconnecting, error }

/// HA WebSocket 客户端。
/// 流程：连接 → auth_required → auth → auth_ok → subscribe_events(state_changed)
/// 特性：请求-响应命令、指数退避重连、心跳、实体增量更新。
class HaWsClient {
  HaWsClient({
    required this.baseUrl,
    required this.token,
    this.onEntityUpdated,
    this.onEntityRemoved,
    this.onStatusChanged,
    this.onError,
  });

  final String baseUrl;
  final String token;

  /// 收到实体状态变化（增量），由上层更新缓存并刷新 UI。
  final void Function(HaEntity entity)? onEntityUpdated;

  /// 实体被删除时回调。
  final void Function(String entityId)? onEntityRemoved;

  final void Function(HaWsStatus status)? onStatusChanged;
  final void Function(Object error)? onError;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;

  final Map<int, Completer<Map<String, dynamic>>> _pending =
      <int, Completer<Map<String, dynamic>>>{};

  int _nextId = 1;
  int? _stateSubscriptionId;
  int _retry = 0;
  bool _wantsConnection = false;
  bool _fatal = false;
  HaWsStatus _status = HaWsStatus.disconnected;

  HaWsStatus get status => _status;
  bool get isConnected => _status == HaWsStatus.connected;

  /// 根据 HTTP baseUrl 推导 ws(s) 地址，兼容反代子路径。
  String get wsUrl {
    final uri = Uri.parse(baseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final base = uri.path.endsWith('/')
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;
    return uri
        .replace(scheme: scheme, path: '$base/api/websocket', query: '', fragment: '')
        .toString();
  }

  Future<void> connect() async {
    _wantsConnection = true;
    _fatal = false;
    _retry = 0;
    await _open();
  }

  Future<void> _open() async {
    if (!_wantsConnection) return;
    _setStatus(_retry == 0 ? HaWsStatus.connecting : HaWsStatus.reconnecting);

    try {
      final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await channel.ready;
      if (!_wantsConnection) {
        channel.sink.close();
        return;
      }
      _channel = channel;
      _subscription = channel.stream.listen(
        _handleMessage,
        onError: (Object error, StackTrace stack) => _handleTransportError(error),
        onDone: _handleDone,
        cancelOnError: true,
      );
    } catch (e) {
      _handleTransportError(e);
    }
  }

  /// 通用 HA WebSocket 命令（registry 拉取即基于此）。
  Future<Map<String, dynamic>> sendCommand(
    String type, [
    Map<String, dynamic>? params,
  ]) {
    final id = _nextId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _send(<String, dynamic>{'id': id, 'type': type, ...?params});

    return completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        _pending.remove(id);
        throw HaWebSocketException('命令超时：$type');
      },
    );
  }

  void _handleMessage(dynamic raw) {
    if (raw is! String) return;
    Map<String, dynamic> msg;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      msg = Map<String, dynamic>.from(decoded);
    } catch (e) {
      onError?.call(e);
      return;
    }

    switch (msg['type']) {
      case 'auth_required':
        _send(<String, dynamic>{
          'type': 'auth',
          'access_token': token,
        });
      case 'auth_invalid':
        _fatal = true;
        _wantsConnection = false;
        _setStatus(HaWsStatus.error);
        onError?.call(const HaAuthException('WebSocket 认证失败，请检查 Token'));
        _closeChannel();
      case 'auth_ok':
        _retry = 0;
        _setStatus(HaWsStatus.connected);
        _startHeartbeat();
        _subscribeStateChanges();
      case 'result':
        _handleResult(msg);
      case 'event':
        _handleEvent(msg);
      case 'pong':
        break;
      default:
        break;
    }
  }

  void _handleResult(Map<String, dynamic> msg) {
    final id = (msg['id'] as num?)?.toInt();
    if (id == null) return;

    if (id == _stateSubscriptionId && msg['success'] != true) {
      final reason = (msg['error'] as Map?)?['message'] as String? ?? '未知错误';
      onError?.call(HaWebSocketException('订阅 state_changed 失败：$reason'));
    }

    final completer = _pending.remove(id);
    if (completer == null || completer.isCompleted) return;

    if (msg['success'] == true) {
      completer.complete(msg);
    } else {
      final reason =
          (msg['error'] as Map?)?['message'] as String? ?? '命令执行失败';
      completer.completeError(HaApiException(reason));
    }
  }

  void _handleEvent(Map<String, dynamic> msg) {
    final event = msg['event'];
    if (event is! Map) return;
    if (event['event_type'] != 'state_changed') return;

    final data = event['data'];
    if (data is! Map) return;

    final newState = data['new_state'];
    if (newState is Map) {
      onEntityUpdated?.call(
        HaEntity.fromStateJson(Map<String, dynamic>.from(newState)),
      );
    } else {
      // new_state 为 null 表示实体被删除。
      final entityId = data['entity_id'] as String?;
      if (entityId != null) onEntityRemoved?.call(entityId);
    }
  }

  Future<void> _subscribeStateChanges() async {
    try {
      final result = await sendCommand(
        'subscribe_events',
        <String, dynamic>{'event_type': 'state_changed'},
      );
      _stateSubscriptionId = (result['id'] as num?)?.toInt();
    } catch (e) {
      onError?.call(e);
    }
  }

  void _startHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _send(<String, dynamic>{'type': 'ping', 'id': _nextId++}),
    );
  }

  void _send(Map<String, dynamic> message) {
    final sink = _channel?.sink;
    if (sink == null) return;
    try {
      sink.add(jsonEncode(message));
    } catch (e) {
      onError?.call(e);
    }
  }

  void _handleTransportError(Object error) {
    onError?.call(error);
    _scheduleReconnect();
  }

  void _handleDone() => _scheduleReconnect();

  void _scheduleReconnect() {
    _cleanupConnection();
    if (_fatal || !_wantsConnection) {
      _setStatus(_fatal ? HaWsStatus.error : HaWsStatus.disconnected);
      return;
    }
    _setStatus(HaWsStatus.reconnecting);

    // 指数退避 1,2,4,8,16,32 秒，避免 HA 重启期间疯狂重连。
    final delay = Duration(seconds: 1 << (_retry > 5 ? 5 : _retry));
    _retry++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _open);
  }

  void _cleanupConnection() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _stateSubscriptionId = null;

    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(const HaWebSocketException('连接已断开'));
      }
    }
    _pending.clear();
  }

  void _closeChannel() {
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      try {
        channel.sink.close();
      } catch (_) {
        // 关闭失败无需处理：重连调度仍会清理状态。
      }
    }
  }

  void _setStatus(HaWsStatus status) {
    if (_status == status) return;
    _status = status;
    onStatusChanged?.call(status);
  }

  /// 主动断开（退出登录 / 切换服务器），不再重连。
  void disconnect() {
    _wantsConnection = false;
    _fatal = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cleanupConnection();
    _closeChannel();
    _setStatus(HaWsStatus.disconnected);
  }
}
