import 'dart:convert';

import 'package:achievements/features/auth/auth_session.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthRepository {
  AuthRepository({required Dio dio, FlutterSecureStorage? storage})
    : _dio = dio,
      _storage = storage ?? const FlutterSecureStorage();

  final Dio _dio;
  final FlutterSecureStorage _storage;

  static const _sessionKey = 'auth_session';

  Future<AuthSession?> loadSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  Future<void> saveSession(AuthSession session) {
    return _storage.write(
      key: _sessionKey,
      value: jsonEncode(session.toJson()),
    );
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _sessionKey);
  }

  /// 取公众号扫码登录二维码(后端代理 SCC 生成)。
  Future<QrCodeResult> qrcode() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/auth/qrcode',
    );
    final data = response.data ?? <String, dynamic>{};
    return QrCodeResult(
      qrUrl: data['qr_url'] as String,
      sceneId: data['scene_id'] as String,
      expireSeconds: data['expire_seconds'] as int,
    );
  }

  /// 轮询扫码状态;`authorized` 时返回带 SCC token 的会话,否则返回 null。
  Future<AuthSession?> status(String sceneId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/auth/status',
      queryParameters: {'scene_id': sceneId},
    );
    final data = response.data ?? <String, dynamic>{};
    if (data['status'] != 'authorized') return null;
    return AuthSession.fromJson(data);
  }

  /// 滑动续期:用未过期的 token 换新的,身份与 appUserId 不变。
  ///
  /// 走的是不带鉴权拦截器的 dio,故手动带 Authorization——续期本身回 401 时
  /// 不该触发全局登出,交由调用方决定(见 AuthController.maybeRenewToken)。
  Future<String> renew(String token) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/renew',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final data = response.data ?? <String, dynamic>{};
    return data['token'] as String;
  }
}

class QrCodeResult {
  const QrCodeResult({
    required this.qrUrl,
    required this.sceneId,
    required this.expireSeconds,
  });

  final String qrUrl;
  final String sceneId;
  final int expireSeconds;
}
