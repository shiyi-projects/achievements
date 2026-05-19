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

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
