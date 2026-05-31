import 'dart:convert';
import 'dart:io';

import 'package:achievements/features/auth/auth_session.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

class AuthRepository {
  AuthRepository({required Dio dio, FlutterSecureStorage? storage})
    : _dio = dio,
      _storage = storage ?? const FlutterSecureStorage();

  final Dio _dio;
  final FlutterSecureStorage _storage;

  static const _sessionKey = 'auth_session';
  static const _deviceIdKey = 'device_id';

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
    // Windows secure storage can leave stale values behind after app reinstall or
    // backend auth changes. Delete the known auth keys explicitly, then rewrite
    // nothing so startup cannot auto-restore a previous session.
    await _storage.delete(key: _deviceIdKey);
  }

  Future<String> deviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final prefix = _platformPrefix();
    final random = const Uuid().v4().replaceAll('-', '');
    final id = '$prefix-${random.substring(0, 24)}';
    await _storage.write(key: _deviceIdKey, value: id);
    return id;
  }

  Future<AuthRegisterResult> register() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/register',
      data: {'device_id': await deviceId(), 'platform': _platformName()},
    );
    final data = response.data ?? <String, dynamic>{};
    return AuthRegisterResult(
      anonToken: data['anon_token'] as String,
      expiresIn: data['expires_in'] as int,
    );
  }

  Future<QrCodeResult> qrcode(String anonToken) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/auth/qrcode',
      options: Options(headers: {'Authorization': 'Bearer $anonToken'}),
    );
    final data = response.data ?? <String, dynamic>{};
    return QrCodeResult(
      qrUrl: data['qr_url'] as String,
      expireSeconds: data['expire_seconds'] as int,
    );
  }

  Future<AuthSession?> status(String anonToken) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/auth/status',
      options: Options(headers: {'Authorization': 'Bearer $anonToken'}),
    );
    final data = response.data ?? <String, dynamic>{};
    if (data['status'] != 'authorized') return null;
    return AuthSession.fromJson(data);
  }

  String _platformPrefix() {
    if (Platform.isWindows) return 'win';
    if (Platform.isAndroid) return 'and';
    if (Platform.isIOS) return 'ios';
    return 'dev';
  }

  String _platformName() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'other';
  }
}

class AuthRegisterResult {
  const AuthRegisterResult({required this.anonToken, required this.expiresIn});

  final String anonToken;
  final int expiresIn;
}

class QrCodeResult {
  const QrCodeResult({required this.qrUrl, required this.expireSeconds});

  final String qrUrl;
  final int expireSeconds;
}
