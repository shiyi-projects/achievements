// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'achievement_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$achievementStatusHash() => r'251ffe1c515d6bb9dc087ab5e2d380e9c772db03';

/// Maps achievement code → whether it is unlocked locally.
///
/// Copied from [achievementStatus].
@ProviderFor(achievementStatus)
final achievementStatusProvider =
    AutoDisposeFutureProvider<Map<String, bool>>.internal(
      achievementStatus,
      name: r'achievementStatusProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$achievementStatusHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AchievementStatusRef = AutoDisposeFutureProviderRef<Map<String, bool>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
