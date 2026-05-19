// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$tagRepositoryHash() => r'c82035b8ef9c4c35bcf87cda56e280ce96c8c4ce';

/// See also [tagRepository].
@ProviderFor(tagRepository)
final tagRepositoryProvider = Provider<TagRepository>.internal(
  tagRepository,
  name: r'tagRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$tagRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TagRepositoryRef = ProviderRef<TagRepository>;
String _$allTagsHash() => r'f221b1f55db9511a8a204fd042048953b67d3a88';

/// See also [allTags].
@ProviderFor(allTags)
final allTagsProvider = AutoDisposeStreamProvider<List<Tag>>.internal(
  allTags,
  name: r'allTagsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$allTagsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AllTagsRef = AutoDisposeStreamProviderRef<List<Tag>>;
String _$tagsForTaskHash() => r'6c30409df84f418d6605b48e55b074d1492d1b34';

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

/// 监听某任务当前关联的标签列表。
///
/// Copied from [tagsForTask].
@ProviderFor(tagsForTask)
const tagsForTaskProvider = TagsForTaskFamily();

/// 监听某任务当前关联的标签列表。
///
/// Copied from [tagsForTask].
class TagsForTaskFamily extends Family<AsyncValue<List<Tag>>> {
  /// 监听某任务当前关联的标签列表。
  ///
  /// Copied from [tagsForTask].
  const TagsForTaskFamily();

  /// 监听某任务当前关联的标签列表。
  ///
  /// Copied from [tagsForTask].
  TagsForTaskProvider call(String taskId) {
    return TagsForTaskProvider(taskId);
  }

  @override
  TagsForTaskProvider getProviderOverride(
    covariant TagsForTaskProvider provider,
  ) {
    return call(provider.taskId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'tagsForTaskProvider';
}

/// 监听某任务当前关联的标签列表。
///
/// Copied from [tagsForTask].
class TagsForTaskProvider extends AutoDisposeStreamProvider<List<Tag>> {
  /// 监听某任务当前关联的标签列表。
  ///
  /// Copied from [tagsForTask].
  TagsForTaskProvider(String taskId)
    : this._internal(
        (ref) => tagsForTask(ref as TagsForTaskRef, taskId),
        from: tagsForTaskProvider,
        name: r'tagsForTaskProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$tagsForTaskHash,
        dependencies: TagsForTaskFamily._dependencies,
        allTransitiveDependencies: TagsForTaskFamily._allTransitiveDependencies,
        taskId: taskId,
      );

  TagsForTaskProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.taskId,
  }) : super.internal();

  final String taskId;

  @override
  Override overrideWith(
    Stream<List<Tag>> Function(TagsForTaskRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TagsForTaskProvider._internal(
        (ref) => create(ref as TagsForTaskRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        taskId: taskId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<Tag>> createElement() {
    return _TagsForTaskProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TagsForTaskProvider && other.taskId == taskId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, taskId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TagsForTaskRef on AutoDisposeStreamProviderRef<List<Tag>> {
  /// The parameter `taskId` of this provider.
  String get taskId;
}

class _TagsForTaskProviderElement
    extends AutoDisposeStreamProviderElement<List<Tag>>
    with TagsForTaskRef {
  _TagsForTaskProviderElement(super.provider);

  @override
  String get taskId => (origin as TagsForTaskProvider).taskId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
