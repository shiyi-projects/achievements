import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'keepalive_service.g.dart';

/// Android 保活相关的原生桥接(channel: achievements/keepalive)。
///
/// 提醒走系统 AlarmManager(exact alarm),app 被杀也能到点触发;本服务只负责两件
/// 「准时不被掐」的事:电池优化豁免 + 厂商自启动管理页跳转。非 Android 平台全为 no-op。
class KeepAliveService {
  const KeepAliveService();

  static const _channel = MethodChannel('achievements/keepalive');

  bool get _supported => Platform.isAndroid;

  /// 当前是否已被加入电池优化白名单(Doze 豁免)。非 Android 视为 true。
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!_supported) return true;
    try {
      return await _channel.invokeMethod<bool>(
            'isIgnoringBatteryOptimizations',
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  /// 弹系统对话框,请求把本应用加入电池优化白名单。
  Future<void> requestIgnoreBatteryOptimizations() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('requestIgnoreBatteryOptimizations');
    } on PlatformException {
      // 忽略:无法打开则保持现状,用户可去系统设置手动处理。
    }
  }

  /// 跳转厂商自启动管理页(失败回退应用详情页)。返回是否成功打开某个页面。
  Future<bool> openAutoStartSettings() async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>('openAutoStartSettings') ??
          false;
    } on PlatformException {
      return false;
    }
  }
}

@Riverpod(keepAlive: true)
KeepAliveService keepAliveService(Ref ref) => const KeepAliveService();
