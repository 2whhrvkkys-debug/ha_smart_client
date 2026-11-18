/// HA 客户端统一异常类型，UI 层根据不同异常给出差异化提示。
sealed class HaException implements Exception {
  const HaException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// URL / Token 格式错误、认证失败（401/403）。
class HaAuthException extends HaException {
  const HaAuthException(super.message, {super.cause});
}

/// REST 请求失败（网络不可达、超时、5xx 等）。
class HaNetworkException extends HaException {
  const HaNetworkException(super.message, {super.cause});
}

/// HA 返回的错误响应（body 中的 message 字段）。
class HaApiException extends HaException {
  const HaApiException(super.message, {this.code, super.cause});

  final String? code;
}

/// WebSocket 握手 / 协议错误。
class HaWebSocketException extends HaException {
  const HaWebSocketException(super.message, {super.cause});
}

/// 服务调用失败（控制设备时）。
class HaServiceException extends HaException {
  const HaServiceException(super.message, {super.cause});
}
