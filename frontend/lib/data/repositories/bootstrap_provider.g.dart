// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bootstrap_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appBootstrapHash() => r'e155ff87ab25b1903a7ad7e1277d7590d78c3087';

/// 应用启动期一次性初始化:
///   1. 种入系统清单(幂等)
///   2. 初始化 NotificationService(时区 + Android 通道)并尝试申请权限
///   3. 启动 ReminderScheduler:watch 待提醒任务流并 reconcile 本地排程
///   4. SyncEngine 首次 pull:从服务端拉增量并合并到本地 Drift
///      (失败不阻塞,SyncStatusController 上报状态)
///
/// AchievementsApp 在渲染前 watch 此 Future,完成后再放行 router。
///
/// Copied from [appBootstrap].
@ProviderFor(appBootstrap)
final appBootstrapProvider = FutureProvider<void>.internal(
  appBootstrap,
  name: r'appBootstrapProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$appBootstrapHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AppBootstrapRef = FutureProviderRef<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
