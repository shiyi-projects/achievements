// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$taskRepositoryHash() => r'85e63b4826a3d6db7d188a8354c50d4d8b378f21';

/// See also [taskRepository].
@ProviderFor(taskRepository)
final taskRepositoryProvider = Provider<TaskRepository>.internal(
  taskRepository,
  name: r'taskRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$taskRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TaskRepositoryRef = ProviderRef<TaskRepository>;
String _$tasksForCurrentListHash() =>
    r'c6dfecf1005754fd50eb49bfec435a34d114c292';

/// 当前选中清单的任务流。
///
/// 用于 Today / ListPage 等主视图。当 [currentListProvider] 仍在 resolve 时
/// 先 yield 空列表占位。
///
/// Copied from [tasksForCurrentList].
@ProviderFor(tasksForCurrentList)
final tasksForCurrentListProvider =
    AutoDisposeStreamProvider<List<Task>>.internal(
      tasksForCurrentList,
      name: r'tasksForCurrentListProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$tasksForCurrentListHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TasksForCurrentListRef = AutoDisposeStreamProviderRef<List<Task>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
