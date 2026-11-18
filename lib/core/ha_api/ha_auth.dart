import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:ha_smart_client/core/errors/ha_exception.dart';
import 'package:http/http.dart' as http;

/// HA 服务器基本信息（来自 /api/config）。
@immutable
class HaServerInfo {
  const HaServerInfo({
    required this.locationName,
    required this.version,
    this.language,
    this.timeZone,
    this.temperatureUnit,
  });

  final String locationName;
  final String version;
  final String? language;
  final String? timeZone;
  final String? temperatureUnit;

  factory HaServerInfo.fromConfigJson(Map<String, dynamic> json) {
    final units = json['unit_system'];
    return HaServerInfo(
      locationName: (json['location_name'] as String?) ?? '我的家',
      version: (json['version'] as String?) ?? 'unknown',
      language: json['language'] as String?,
      timeZone: json['time_zone'] as String?,
      temperatureUnit: units is Map ? units['temperature'] as String? : null,
    );
  }
}

/// URL 规范化 + 凭证校验。
class HaAuth {
  const HaAuth({http.Client? client}) : _client = client;

  final http.Client? _client;

  /// 把用户输入整理为可用于 API 的 baseUrl：
  /// 1. 补 https://  2. 只保留 scheme://host[:port]，丢弃**全部**路径/查询/片段。
  ///
  /// 关键：从浏览器地址栏复制的 HA 地址常带前端路由（如 /lovelace/0、/ui/、
  /// /config、/history）。若把这些路径保留下来，App 拼出的
  /// `<base>/api/states` 会变成 `/lovelace/0/api/states`，HA 会把它当 SPA
  /// 前端路由处理并直接返回 index.html（约 10KB 的 HTML），而不是 JSON，
  /// 于是所有实体为空、报「服务器响应不是合法 JSON」。
  /// HA 的 REST / WebSocket API 一律挂在根路径，因此统一裁到 origin 最稳妥，
  /// 也能自动纠正旧版本已保存下来的带路径地址（重连时即生效）。
  static String normalizeUrl(String input) {
    var url = input.trim();
    if (url.isEmpty) {
      throw const HaAuthException('请输入 Home Assistant 地址');
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
      throw const HaAuthException('地址格式不正确，请检查后重试');
    }
    return uri.replace(path: '', query: '', fragment: '').toString();
  }

  /// 调用 GET /api/config 验证 Token 是否有效，同时拿到服务器信息。
  Future<HaServerInfo> verify({
    required String baseUrl,
    required String token,
  }) async {
    if (token.trim().isEmpty) {
      throw const HaAuthException('请输入 Long-Lived Access Token');
    }
    final normalized = normalizeUrl(baseUrl);
    final client = _client ?? http.Client();
    final ownsClient = _client == null;

    try {
      final reqUrl = Uri.parse('$normalized/api/config');
      final response = await client
          .get(
            reqUrl,
            headers: <String, String>{
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              // 要求不压缩，避免反代/穿透隧道下 gzip 解压失败。
              'Accept-Encoding': 'identity',
            },
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const HaAuthException('令牌无效或已过期，请重新生成 Long-Lived Token');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HaApiException(
          '服务器返回 ${response.statusCode}',
          code: response.statusCode.toString(),
        );
      }

      final decoded = _decodeJson(response.bodyBytes, reqUrl.toString());
      if (decoded is! Map<String, dynamic>) {
        throw const HaApiException('服务器响应格式不正确');
      }
      return HaServerInfo.fromConfigJson(decoded);
    } on HaException {
      rethrow;
    } on TimeoutException {
      throw const HaNetworkException('连接超时，请检查地址与网络');
    } on SocketException {
      throw const HaNetworkException('无法连接服务器，请检查地址与网络');
    } on http.ClientException catch (e) {
      throw HaNetworkException('网络请求失败：${e.message}', cause: e);
    } catch (e) {
      throw HaNetworkException('连接失败：$e', cause: e);
    } finally {
      if (ownsClient) client.close();
    }
  }

  static Object _decodeJson(List<int> bodyBytes, [String? url]) {
    if (bodyBytes.isEmpty) {
      throw const HaApiException('服务器响应为空');
    }
    // 逐层解压：穿透代理可能重复压缩，最多 3 层。
    List<int> data = bodyBytes;
    for (var i = 0; i < 3; i++) {
      if (data.length >= 2 && data[0] == 0x1f && data[1] == 0x8b) {
        try {
          data = gzip.decode(data);
        } catch (_) {
          break;
        }
      } else {
        break;
      }
    }
    String text;
    try {
      text = utf8.decode(data);
    } catch (_) {
      text = utf8.decode(data, allowMalformed: true);
    }
    if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
      text = text.substring(1);
    }
    text = text.trim();
    try {
      return jsonDecode(text) as Object;
    } catch (_) {
      final head = text.length > 120 ? text.substring(0, 120) : text;
      throw HaApiException(
        '登录响应非JSON[请求URL=$url][字节=${bodyBytes.length}]: $head',
      );
    }
  }
}
