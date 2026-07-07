import 'dart:async';

import 'package:achievements/core/theme/app_icons.dart';
import 'package:achievements/features/auth/auth_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QrLoginPage extends ConsumerStatefulWidget {
  const QrLoginPage({super.key});

  @override
  ConsumerState<QrLoginPage> createState() => _QrLoginPageState();
}

class _QrLoginPageState extends ConsumerState<QrLoginPage> {
  Timer? _timer;
  Timer? _expiryTimer;
  String? _sceneId;
  String? _qrUrl;
  String? _error;
  bool _loading = true;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    _timer?.cancel();
    _expiryTimer?.cancel();
    setState(() {
      _loading = true;
      _error = null;
      _qrUrl = null;
      _expired = false;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      final qr = await repo.qrcode();
      if (!mounted) return;
      final uri = Uri.tryParse(qr.qrUrl);
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
        throw StateError('二维码地址无效: ${qr.qrUrl}');
      }
      setState(() {
        _sceneId = qr.sceneId;
        _qrUrl = qr.qrUrl;
        _loading = false;
      });
      _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
      // 二维码有效期由后端 expire_seconds 决定;到期后前端主动置为过期态并停止
      // 轮询,不必等后端在轮询时返回 401。
      if (qr.expireSeconds > 0) {
        _expiryTimer = Timer(Duration(seconds: qr.expireSeconds), _markExpired);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.response?.data?.toString() ?? e.message ?? '登录服务暂不可用';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _poll() async {
    final sceneId = _sceneId;
    if (sceneId == null) return;
    try {
      final session = await ref.read(authRepositoryProvider).status(sceneId);
      if (session == null) return;
      _timer?.cancel();
      await ref.read(authControllerProvider.notifier).setSession(session);
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 401) {
        _markExpired();
      }
    }
  }

  /// 标记二维码过期:停止轮询与到期计时,并让二维码区域显示「已过期」遮罩。
  void _markExpired() {
    _timer?.cancel();
    _expiryTimer?.cancel();
    if (!mounted) return;
    setState(() => _expired = true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AppIcons.svgIcon(AppIcons.appIcon, size: 64),
                ),
                const SizedBox(height: 16),
                Text(
                  '微信扫码登录',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '使用微信扫描二维码后，当前设备会绑定到你的 Achievements 账号。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                Container(
                  width: 260,
                  height: 260,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator()
                      : _qrUrl == null
                      ? Icon(
                          Icons.qr_code_2_rounded,
                          size: 96,
                          color: scheme.outline,
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.network(
                                _qrUrl!,
                                fit: BoxFit.contain,
                              ),
                            ),
                            if (_expired)
                              _ExpiredOverlay(
                                onRefresh: () => unawaited(_start()),
                              ),
                          ],
                        ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(color: scheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _loading ? null : () => unawaited(_start()),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('刷新二维码'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 二维码过期遮罩:盖在已失效的二维码上,点击任意处即可刷新。
class _ExpiredOverlay extends StatelessWidget {
  const _ExpiredOverlay({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onRefresh,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.refresh_rounded, size: 40, color: scheme.primary),
            const SizedBox(height: 8),
            Text(
              '二维码已过期',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '点击刷新后重新扫码',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
