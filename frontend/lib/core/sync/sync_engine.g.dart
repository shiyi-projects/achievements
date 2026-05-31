// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_engine.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$syncEngineHash() => r'080ef9850e023d9314d62ffa936e68fcd89b1e0a';

/// See also [syncEngine].
@ProviderFor(syncEngine)
final syncEngineProvider = Provider<SyncEngine>.internal(
  syncEngine,
  name: r'syncEngineProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$syncEngineHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SyncEngineRef = ProviderRef<SyncEngine>;
String _$syncStatusControllerHash() =>
    r'9b497e7dd046afbf9c6b793ea4bde1ac02ff0cb9';

/// 全局 SyncStatus(后续状态指示器 watch 此 provider)。
///
/// Copied from [SyncStatusController].
@ProviderFor(SyncStatusController)
final syncStatusControllerProvider =
    NotifierProvider<SyncStatusController, SyncStatus>.internal(
      SyncStatusController.new,
      name: r'syncStatusControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$syncStatusControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SyncStatusController = Notifier<SyncStatus>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
