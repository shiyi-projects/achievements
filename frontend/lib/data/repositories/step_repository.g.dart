// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'step_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$stepRepositoryHash() => r'bae358be0421a98d51ddc06354008c9c589ae020';

/// See also [stepRepository].
@ProviderFor(stepRepository)
final stepRepositoryProvider = Provider<StepRepository>.internal(
  stepRepository,
  name: r'stepRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$stepRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef StepRepositoryRef = ProviderRef<StepRepository>;
String _$stepsForTaskHash() => r'90fde94be2e1d7286e4c19bc5489f948ad1a8fa9';

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

/// See also [stepsForTask].
@ProviderFor(stepsForTask)
const stepsForTaskProvider = StepsForTaskFamily();

/// See also [stepsForTask].
class StepsForTaskFamily extends Family<AsyncValue<List<TaskStep>>> {
  /// See also [stepsForTask].
  const StepsForTaskFamily();

  /// See also [stepsForTask].
  StepsForTaskProvider call(String taskId) {
    return StepsForTaskProvider(taskId);
  }

  @override
  StepsForTaskProvider getProviderOverride(
    covariant StepsForTaskProvider provider,
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
  String? get name => r'stepsForTaskProvider';
}

/// See also [stepsForTask].
class StepsForTaskProvider extends AutoDisposeStreamProvider<List<TaskStep>> {
  /// See also [stepsForTask].
  StepsForTaskProvider(String taskId)
    : this._internal(
        (ref) => stepsForTask(ref as StepsForTaskRef, taskId),
        from: stepsForTaskProvider,
        name: r'stepsForTaskProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$stepsForTaskHash,
        dependencies: StepsForTaskFamily._dependencies,
        allTransitiveDependencies:
            StepsForTaskFamily._allTransitiveDependencies,
        taskId: taskId,
      );

  StepsForTaskProvider._internal(
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
    Stream<List<TaskStep>> Function(StepsForTaskRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: StepsForTaskProvider._internal(
        (ref) => create(ref as StepsForTaskRef),
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
  AutoDisposeStreamProviderElement<List<TaskStep>> createElement() {
    return _StepsForTaskProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is StepsForTaskProvider && other.taskId == taskId;
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
mixin StepsForTaskRef on AutoDisposeStreamProviderRef<List<TaskStep>> {
  /// The parameter `taskId` of this provider.
  String get taskId;
}

class _StepsForTaskProviderElement
    extends AutoDisposeStreamProviderElement<List<TaskStep>>
    with StepsForTaskRef {
  _StepsForTaskProviderElement(super.provider);

  @override
  String get taskId => (origin as StepsForTaskProvider).taskId;
}

String _$stepCountHash() => r'ec1ad8a1e04f81280827eac34ab4b8f0a95b901a';

/// 仅返回计数,供 TaskTile 轻量订阅,减少不必要的 rebuild。
///
/// Copied from [stepCount].
@ProviderFor(stepCount)
const stepCountProvider = StepCountFamily();

/// 仅返回计数,供 TaskTile 轻量订阅,减少不必要的 rebuild。
///
/// Copied from [stepCount].
class StepCountFamily extends Family<({int done, int total})> {
  /// 仅返回计数,供 TaskTile 轻量订阅,减少不必要的 rebuild。
  ///
  /// Copied from [stepCount].
  const StepCountFamily();

  /// 仅返回计数,供 TaskTile 轻量订阅,减少不必要的 rebuild。
  ///
  /// Copied from [stepCount].
  StepCountProvider call(String taskId) {
    return StepCountProvider(taskId);
  }

  @override
  StepCountProvider getProviderOverride(covariant StepCountProvider provider) {
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
  String? get name => r'stepCountProvider';
}

/// 仅返回计数,供 TaskTile 轻量订阅,减少不必要的 rebuild。
///
/// Copied from [stepCount].
class StepCountProvider extends AutoDisposeProvider<({int done, int total})> {
  /// 仅返回计数,供 TaskTile 轻量订阅,减少不必要的 rebuild。
  ///
  /// Copied from [stepCount].
  StepCountProvider(String taskId)
    : this._internal(
        (ref) => stepCount(ref as StepCountRef, taskId),
        from: stepCountProvider,
        name: r'stepCountProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$stepCountHash,
        dependencies: StepCountFamily._dependencies,
        allTransitiveDependencies: StepCountFamily._allTransitiveDependencies,
        taskId: taskId,
      );

  StepCountProvider._internal(
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
    ({int done, int total}) Function(StepCountRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: StepCountProvider._internal(
        (ref) => create(ref as StepCountRef),
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
  AutoDisposeProviderElement<({int done, int total})> createElement() {
    return _StepCountProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is StepCountProvider && other.taskId == taskId;
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
mixin StepCountRef on AutoDisposeProviderRef<({int done, int total})> {
  /// The parameter `taskId` of this provider.
  String get taskId;
}

class _StepCountProviderElement
    extends AutoDisposeProviderElement<({int done, int total})>
    with StepCountRef {
  _StepCountProviderElement(super.provider);

  @override
  String get taskId => (origin as StepCountProvider).taskId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
