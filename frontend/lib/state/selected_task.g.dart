// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'selected_task.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$currentTaskHash() => r'e89c01c4c204cd1a98cf51846dd893a036618485';

/// 解析为真实 [Task] 行的响应式流;选中 ID 为 null 时发射 null。
///
/// 用 [TaskRepository.watchById] 而非一次性 `getById`,确保任意字段
/// (星标 / 完成态 / 日期等)在 DB 更新后实时反映到详情面板。
///
/// Copied from [currentTask].
@ProviderFor(currentTask)
final currentTaskProvider = AutoDisposeStreamProvider<Task?>.internal(
  currentTask,
  name: r'currentTaskProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentTaskHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentTaskRef = AutoDisposeStreamProviderRef<Task?>;
String _$parentTaskHash() => r'5de94310c4e5185c7ac254e1e8225cedd493ec2c';

/// 当前任务的父任务（面包屑导航用），同样响应式监听。
///
/// Copied from [parentTask].
@ProviderFor(parentTask)
final parentTaskProvider = AutoDisposeStreamProvider<Task?>.internal(
  parentTask,
  name: r'parentTaskProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$parentTaskHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ParentTaskRef = AutoDisposeStreamProviderRef<Task?>;
String _$selectedTaskIdHash() => r'ef6ba962267ce25c31995c20205cbc5ce58922a6';

/// 当前打开的任务详情 ID。
///
/// - 桌面 ≥1024:Shell 据此渲染第三列详情面板
/// - 移动:Shell `ref.listen` 此 provider,变化时 showModalBottomSheet
///
/// 关闭详情时调用 [SelectedTaskId.clear]。
///
/// Copied from [SelectedTaskId].
@ProviderFor(SelectedTaskId)
final selectedTaskIdProvider =
    NotifierProvider<SelectedTaskId, String?>.internal(
      SelectedTaskId.new,
      name: r'selectedTaskIdProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$selectedTaskIdHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SelectedTaskId = Notifier<String?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
