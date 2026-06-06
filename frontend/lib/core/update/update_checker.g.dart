// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_checker.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$updateCheckerHash() => r'ec3975f508a98616755da03c4b70c84c011b9277';

/// See also [updateChecker].
@ProviderFor(updateChecker)
final updateCheckerProvider = AutoDisposeProvider<UpdateChecker>.internal(
  updateChecker,
  name: r'updateCheckerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$updateCheckerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UpdateCheckerRef = AutoDisposeProviderRef<UpdateChecker>;
String _$updateCheckHash() => r'd083390ab1b4dfee343596941bd6b3715b2ca6e0';

/// 启动时自动检查一次。失败 / 无更新为 null;有更新为 [UpdateInfo]。
///
/// Copied from [updateCheck].
@ProviderFor(updateCheck)
final updateCheckProvider = AutoDisposeFutureProvider<UpdateInfo?>.internal(
  updateCheck,
  name: r'updateCheckProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$updateCheckHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UpdateCheckRef = AutoDisposeFutureProviderRef<UpdateInfo?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
