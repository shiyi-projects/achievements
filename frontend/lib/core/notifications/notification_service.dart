import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

part 'notification_service.g.dart';

/// Android 通知通道 ID(用于 flutter_local_notifications.show* 时定位渠道)。
const String _kRemindersChannelId = 'achievements_reminders';
const String _kRemindersChannelName = 'Task reminders';
const String _kRemindersChannelDescription = '到点提醒你完成任务';

class NotificationService {
  NotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // 初始化时区数据 + 同步设备本地时区(zonedSchedule 必备)
    tz_data.initializeTimeZones();
    final localName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localName));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const windowsInit = WindowsInitializationSettings(
      appName: 'Achievements',
      appUserModelId: 'com.shiyi.achievements',
      // GUID 由项目唯一,生成一次即可(占位 GUID,实际安装包应在工具链生成)
      guid: 'a3cabe55-bc4c-4a3d-9e87-2e7d4b1d0001',
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      windows: windowsInit,
    );
    await _plugin.initialize(initSettings);

    // Android 通知通道(8.0+ 必备)
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _kRemindersChannelId,
          _kRemindersChannelName,
          description: _kRemindersChannelDescription,
          importance: Importance.high,
        ),
      );
    }

    _initialized = true;
  }

  /// 申请通知权限(Android 13+ / Windows 桌面均会弹一次)。
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await android?.requestNotificationsPermission() ?? false;
      final exact = await android?.requestExactAlarmsPermission() ?? false;
      return granted && exact;
    }
    return true;
  }

  /// 在 [when] 触发一条通知。同一 [id] 多次调用会覆盖之前的排程。
  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    String? body,
    String? payload,
  }) async {
    final fireAt = tz.TZDateTime.from(when, tz.local);
    if (fireAt.isBefore(tz.TZDateTime.now(tz.local))) {
      // 已过期 → 不排程(避免立即弹老提醒)
      return;
    }
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      fireAt,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _kRemindersChannelId,
          _kRemindersChannelName,
          channelDescription: _kRemindersChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        windows: WindowsNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  Future<void> cancelAll() => _plugin.cancelAll();
}

@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) {
  final service = NotificationService(FlutterLocalNotificationsPlugin());
  return service;
}
