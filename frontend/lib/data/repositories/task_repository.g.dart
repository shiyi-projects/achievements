// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$taskRepositoryHash() => r'5c236dcb8eb53e93726e5fda9e58504a97c78445';

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

/// 当前选中清单的任务流(主视图用)。
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
String _$subtasksOfHash() => r'1646128268c27ce5b07ca5a90e718314f97bf323';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// 监听某父任务的直接子任务。
///
/// Copied from [subtasksOf].
@ProviderFor(subtasksOf)
const subtasksOfProvider = SubtasksOfFamily();

/// 监听某父任务的直接子任务。
///
/// Copied from [subtasksOf].
class SubtasksOfFamily extends Family<AsyncValue<List<Task>>> {
  /// 监听某父任务的直接子任务。
  ///
  /// Copied from [subtasksOf].
  const SubtasksOfFamily();

  /// 监听某父任务的直接子任务。
  ///
  /// Copied from [subtasksOf].
  SubtasksOfProvider call(String parentId) {
    return SubtasksOfProvider(parentId);
  }

  @override
  SubtasksOfProvider getProviderOverride(
    covariant SubtasksOfProvider provider,
  ) {
    return call(provider.parentId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'subtasksOfProvider';
}

/// 监听某父任务的直接子任务。
///
/// Copied from [subtasksOf].
class SubtasksOfProvider extends AutoDisposeStreamProvider<List<Task>> {
  /// 监听某父任务的直接子任务。
  ///
  /// Copied from [subtasksOf].
  SubtasksOfProvider(String parentId)
    : this._internal(
        (ref) => subtasksOf(ref as SubtasksOfRef, parentId),
        from: subtasksOfProvider,
        name: r'subtasksOfProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$subtasksOfHash,
        dependencies: SubtasksOfFamily._dependencies,
        allTransitiveDependencies: SubtasksOfFamily._allTransitiveDependencies,
        parentId: parentId,
      );

  SubtasksOfProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.parentId,
  }) : super.internal();

  final String parentId;

  @override
  Override overrideWith(
    Stream<List<Task>> Function(SubtasksOfRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SubtasksOfProvider._internal(
        (ref) => create(ref as SubtasksOfRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        parentId: parentId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<Task>> createElement() {
    return _SubtasksOfProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SubtasksOfProvider && other.parentId == parentId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, parentId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SubtasksOfRef on AutoDisposeStreamProviderRef<List<Task>> {
  /// The parameter `parentId` of this provider.
  String get parentId;
}

class _SubtasksOfProviderElement
    extends AutoDisposeStreamProviderElement<List<Task>>
    with SubtasksOfRef {
  _SubtasksOfProviderElement(super.provider);

  @override
  String get parentId => (origin as SubtasksOfProvider).parentId;
}

String _$taskCountForListIdHash() =>
    r'85dabc6956c7b391895123502d8b35e956de969d';

/// 某清单的任务数量(Sidebar 徽标)。家族参数用 listId 字符串避免在
/// codegen 端引入 Drift 数据类的等值/哈希依赖。
///
/// Copied from [taskCountForListId].
@ProviderFor(taskCountForListId)
const taskCountForListIdProvider = TaskCountForListIdFamily();

/// 某清单的任务数量(Sidebar 徽标)。家族参数用 listId 字符串避免在
/// codegen 端引入 Drift 数据类的等值/哈希依赖。
///
/// Copied from [taskCountForListId].
class TaskCountForListIdFamily extends Family<AsyncValue<int>> {
  /// 某清单的任务数量(Sidebar 徽标)。家族参数用 listId 字符串避免在
  /// codegen 端引入 Drift 数据类的等值/哈希依赖。
  ///
  /// Copied from [taskCountForListId].
  const TaskCountForListIdFamily();

  /// 某清单的任务数量(Sidebar 徽标)。家族参数用 listId 字符串避免在
  /// codegen 端引入 Drift 数据类的等值/哈希依赖。
  ///
  /// Copied from [taskCountForListId].
  TaskCountForListIdProvider call(String listId) {
    return TaskCountForListIdProvider(listId);
  }

  @override
  TaskCountForListIdProvider getProviderOverride(
    covariant TaskCountForListIdProvider provider,
  ) {
    return call(provider.listId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'taskCountForListIdProvider';
}

/// 某清单的任务数量(Sidebar 徽标)。家族参数用 listId 字符串避免在
/// codegen 端引入 Drift 数据类的等值/哈希依赖。
///
/// Copied from [taskCountForListId].
class TaskCountForListIdProvider extends AutoDisposeStreamProvider<int> {
  /// 某清单的任务数量(Sidebar 徽标)。家族参数用 listId 字符串避免在
  /// codegen 端引入 Drift 数据类的等值/哈希依赖。
  ///
  /// Copied from [taskCountForListId].
  TaskCountForListIdProvider(String listId)
    : this._internal(
        (ref) => taskCountForListId(ref as TaskCountForListIdRef, listId),
        from: taskCountForListIdProvider,
        name: r'taskCountForListIdProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$taskCountForListIdHash,
        dependencies: TaskCountForListIdFamily._dependencies,
        allTransitiveDependencies:
            TaskCountForListIdFamily._allTransitiveDependencies,
        listId: listId,
      );

  TaskCountForListIdProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.listId,
  }) : super.internal();

  final String listId;

  @override
  Override overrideWith(
    Stream<int> Function(TaskCountForListIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TaskCountForListIdProvider._internal(
        (ref) => create(ref as TaskCountForListIdRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        listId: listId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<int> createElement() {
    return _TaskCountForListIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TaskCountForListIdProvider && other.listId == listId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, listId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TaskCountForListIdRef on AutoDisposeStreamProviderRef<int> {
  /// The parameter `listId` of this provider.
  String get listId;
}

class _TaskCountForListIdProviderElement
    extends AutoDisposeStreamProviderElement<int>
    with TaskCountForListIdRef {
  _TaskCountForListIdProviderElement(super.provider);

  @override
  String get listId => (origin as TaskCountForListIdProvider).listId;
}

String _$tasksForMonthHash() => r'404ec4968fcec8b0ec72abab9aa714371c8c2983';

/// 日历视图:指定月份内有 due_at 的任务流。[monthStart] 为当月 1 日 00:00。
///
/// Copied from [tasksForMonth].
@ProviderFor(tasksForMonth)
const tasksForMonthProvider = TasksForMonthFamily();

/// 日历视图:指定月份内有 due_at 的任务流。[monthStart] 为当月 1 日 00:00。
///
/// Copied from [tasksForMonth].
class TasksForMonthFamily extends Family<AsyncValue<List<Task>>> {
  /// 日历视图:指定月份内有 due_at 的任务流。[monthStart] 为当月 1 日 00:00。
  ///
  /// Copied from [tasksForMonth].
  const TasksForMonthFamily();

  /// 日历视图:指定月份内有 due_at 的任务流。[monthStart] 为当月 1 日 00:00。
  ///
  /// Copied from [tasksForMonth].
  TasksForMonthProvider call(DateTime monthStart) {
    return TasksForMonthProvider(monthStart);
  }

  @override
  TasksForMonthProvider getProviderOverride(
    covariant TasksForMonthProvider provider,
  ) {
    return call(provider.monthStart);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'tasksForMonthProvider';
}

/// 日历视图:指定月份内有 due_at 的任务流。[monthStart] 为当月 1 日 00:00。
///
/// Copied from [tasksForMonth].
class TasksForMonthProvider extends AutoDisposeStreamProvider<List<Task>> {
  /// 日历视图:指定月份内有 due_at 的任务流。[monthStart] 为当月 1 日 00:00。
  ///
  /// Copied from [tasksForMonth].
  TasksForMonthProvider(DateTime monthStart)
    : this._internal(
        (ref) => tasksForMonth(ref as TasksForMonthRef, monthStart),
        from: tasksForMonthProvider,
        name: r'tasksForMonthProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$tasksForMonthHash,
        dependencies: TasksForMonthFamily._dependencies,
        allTransitiveDependencies:
            TasksForMonthFamily._allTransitiveDependencies,
        monthStart: monthStart,
      );

  TasksForMonthProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.monthStart,
  }) : super.internal();

  final DateTime monthStart;

  @override
  Override overrideWith(
    Stream<List<Task>> Function(TasksForMonthRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TasksForMonthProvider._internal(
        (ref) => create(ref as TasksForMonthRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        monthStart: monthStart,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<Task>> createElement() {
    return _TasksForMonthProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TasksForMonthProvider && other.monthStart == monthStart;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, monthStart.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TasksForMonthRef on AutoDisposeStreamProviderRef<List<Task>> {
  /// The parameter `monthStart` of this provider.
  DateTime get monthStart;
}

class _TasksForMonthProviderElement
    extends AutoDisposeStreamProviderElement<List<Task>>
    with TasksForMonthRef {
  _TasksForMonthProviderElement(super.provider);

  @override
  DateTime get monthStart => (origin as TasksForMonthProvider).monthStart;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
