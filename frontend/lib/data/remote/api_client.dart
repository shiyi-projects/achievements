import 'dart:async';

import 'package:achievements/core/app_info.dart';
import 'package:achievements/features/auth/auth_controller.dart';
import 'package:achievements/features/auth/auth_session.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'api_client.g.dart';

/// Backend base URL。
///
/// 默认指向生产部署 (宝塔 VPS + Caddy/Nginx 反代 → 后端 8084)。
/// 本地联调时用 dart-define 覆盖:
///   --dart-define=API_BASE_URL=http://localhost:8084
///   --dart-define=API_BASE_URL=http://10.0.2.2:8084  (Android 模拟器访问宿主机)
const String _kDefaultBaseUrl = 'https://achive.11xy.cn';

const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: _kDefaultBaseUrl,
);

@Riverpod(keepAlive: true)
Dio authApiClient(Ref ref) {
  return Dio(_baseOptions());
}

/// 全局认证后 Dio 客户端。
@Riverpod(keepAlive: true)
Dio apiClient(Ref ref) {
  final dio = Dio(_baseOptions());
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final session = ref.read(currentAuthSessionProvider);
        if (session != null) {
          options.headers['Authorization'] = 'Bearer ${session.token}';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final authState = ref.read(authControllerProvider);
        if (error.response?.statusCode == 401 && authState is! AuthSwitching) {
          unawaited(ref.read(authControllerProvider.notifier).logout());
        }
        handler.next(error);
      },
    ),
  );
  return dio;
}

BaseOptions _baseOptions() {
  return BaseOptions(
    baseUrl: kApiBaseUrl,
    connectTimeout: const Duration(seconds: 8),
    sendTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    contentType: 'application/json',
    // 同步协议的版本门槛靠它判定:清单树取代文件夹后,旧客户端推上来的
    // mutation 已无法解释,服务端据此回 426 让用户去升级,而不是让旧端把
    // 请求一遍遍重试成死信。
    headers: const {'X-Client-Version': kAppVersion},
  );
}
