import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ha_smart_client/core/errors/ha_exception.dart';
import 'package:ha_smart_client/core/ha_api/ha_auth.dart';
import 'package:ha_smart_client/core/models/ha_entity.dart';
import 'package:http/http.dart' as http;

/// HA REST API 封装：全量状态、服务器配置、服务调用（设备控制）。
class HaRestClient {
  HaRestClient({
    required this.baseUrl,
    required this.token,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String token;
  final http.Client _client;

  // 大响应（如 /api/states 可含上千实体、数百 KB）经反向代理/内网穿透时
  // 可能较慢，给足超时并配合 fetchStates 的自动重试。
  static const Duration _timeout = Duration(seconds: 60);

  Map<String, String> get _headers => <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// GET /api/states —— 一次性拉取所有实体状态。
  /// 大响应在弱网/反代下偶发超时或连接重置，最多重试 3 次（含首次）。
  Future<List<HaEntity>> fetchStates() async {
    dynamic decoded = null;
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        decoded = await _send(
          () => _client.get(_uri('/api/states'), headers: _headers),
        );
        lastError = null;
        break;
      } on HaAuthException {
        // 令牌问题不重试。
        rethrow;
      } on HaException catch (e) {
        lastError = e;
        if (attempt < 2) {
          await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
        }
      }
    }
    if (lastError != null) throw lastError!;
    if (decoded is! List) {
      throw const HaApiException('实体状态响应格式不正确');
    }
    return decoded
        .whereType<Map>()
        .map((m) => HaEntity.fromStateJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  /// GET /api/config —— 服务器信息（自动重连后刷新）。
  Future<HaServerInfo> fetchConfig() async {
    final decoded = await _send(() => _client.get(_uri('/api/config'), headers: _headers));
    if (decoded is! Map<String, dynamic>) {
      throw const HaApiException('服务器配置响应格式不正确');
    }
    return HaServerInfo.fromConfigJson(decoded);
  }

  /// POST /api/services/`domain`/`service` —— 所有设备控制的统一入口。
  /// 返回受影响实体的最新状态（HA 新版会返回 state 列表）。
  Future<List<HaEntity>> callService({
    required String domain,
    required String service,
    Map<String, dynamic>? data,
    String? entityId,
  }) async {
    final body = <String, dynamic>{...?data};
    if (entityId != null) body['entity_id'] = entityId;

    final decoded = await _send(
      () => _client.post(
        _uri('/api/services/$domain/$service'),
        headers: _headers,
        body: jsonEncode(body),
      ),
    );

    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((m) => HaEntity.fromStateJson(Map<String, dynamic>.from(m)))
          .toList(growable: false);
    }
    return const <HaEntity>[];
  }

  Future<dynamic> _send(Future<http.Response> Function() action) async {
    late final http.Response response;
    try {
      response = await action().timeout(_timeout);
    } on HaException {
      rethrow;
    } on TimeoutException {
      throw const HaNetworkException('请求超时，请检查网络或服务器负载');
    } on SocketException {
      throw const HaNetworkException('无法连接服务器，请检查网络');
    } on http.ClientException catch (e) {
      throw HaNetworkException('网络请求失败：${e.message}', cause: e);
    } catch (e) {
      throw HaNetworkException('请求失败：$e', cause: e);
    }
    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const HaAuthException('令牌无效或已过期，请重新登录');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = response.reasonPhrase ?? '请求失败';
      if (response.body.isNotEmpty) {
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['message'] is String) {
            message = body['message'] as String;
          }
        } catch (_) {
          message = response.body.length > 120
              ? response.body.substring(0, 120)
              : response.body;
        }
      }
      throw HaApiException(message, code: response.statusCode.toString());
    }
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } catch (_) {
      throw const HaApiException('服务器响应不是合法 JSON');
    }
  }

  void dispose() => _client.close();
}
