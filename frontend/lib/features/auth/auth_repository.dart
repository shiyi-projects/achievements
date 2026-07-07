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
