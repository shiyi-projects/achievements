import 'dart:convert';

/// 从 SCC client token 读出 `exp`(不验签)。
///
/// 客户端读 `exp` 只为决定「要不要提前续期」,签名与真实有效性一律由服务端
/// 离线验签裁定,所以这里刻意不校验签名——客户端也没有共享密钥。
/// 无法解析(格式非 JWT / 缺 `exp`)时返回 null,调用方按「不确定」处理。
DateTime? readTokenExpiry(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is! Map<String, dynamic>) return null;
    final exp = payload['exp'];
    if (exp is! int) return null;
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
  } catch (_) {
    return null;
  }
}

/// token 是否已经进入续期窗口(剩余寿命不足 [window])。
///
/// SCC 的建议策略是「剩余不足 48 小时就换新的」;线上 TTL 只有 8h 时该阈值
/// 等价于每次启动都续期,TTL 调长到 7 天后又自动退化成低频续期——同一套判断
/// 对两种配置都成立,故不随服务端 TTL 变化。
/// `exp` 读不出来时返回 true:宁可多续一次(失败会静默沿用旧 token),
/// 也好过因为解析不了而放着 token 过期。
bool shouldRenew(String token, {Duration window = const Duration(hours: 48)}) {
  final expiry = readTokenExpiry(token);
  if (expiry == null) return true;
  return expiry.difference(DateTime.now().toUtc()) < window;
}

/// token 是否已经过期——过期后 SCC 的续期端点也只会回 401,只能重新扫码。
bool isTokenExpired(String token) {
  final expiry = readTokenExpiry(token);
  if (expiry == null) return false;
  return !expiry.isAfter(DateTime.now().toUtc());
}
