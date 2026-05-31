// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bootstrap_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appBootstrapHash() => r'f9a68f416839b53730a68a13305ba8e0f6266d26';

/// 应用启动期一次性初始化:
///   1. 种入系统清单(幂等)
///   2. 初始化 NotificationService(时区 + Android 通道)并尝试申请权限
///   3. 启动 ReminderScheduler:watch 待提醒任务流并 reconcile 本地排程
///   4. **首次同步门**:本设备没标记 firstSyncDone 时,强制 pull 成功才放行;
///      失败抛 [FirstSyncFailedException] 让 UI 显示错误屏(重试/离线)
///   5. 启动 SyncCoordinator 触发监听(outbox debounce + connectivity 边沿)
///   6. 异步 kick 一次 full sync(pull → push),失败不阻塞,SyncStatus 上报
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
