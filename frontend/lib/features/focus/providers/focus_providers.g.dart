// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'focus_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$todayFocusPlansHash() => r'a863ef82b2a1857ee968a1aa0c87c13a7c71da6f';

/// 今日专注计划列表。
///
/// Copied from [todayFocusPlans].
@ProviderFor(todayFocusPlans)
final todayFocusPlansProvider =
    AutoDisposeStreamProvider<List<FocusPlan>>.internal(
  todayFocusPlans,
  name: r'todayFocusPlansProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$todayFocusPlansHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TodayFocusPlansRef = AutoDisposeStreamProviderRef<List<FocusPlan>>;
String _$overdueFocusPlansHash() => r'fb67d8db47e75274098289501c9d63f575c9ac61';

/// 过期未完成计划（近 7 天）。
///
/// Copied from [overdueFocusPlans].
@ProviderFor(overdueFocusPlans)
final overdueFocusPlansProvider =
    AutoDisposeStreamProvider<List<FocusPlan>>.internal(
  overdueFocusPlans,
  name: r'overdueFocusPlansProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$overdueFocusPlansHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OverdueFocusPlansRef = AutoDisposeStreamProviderRef<List<FocusPlan>>;
String _$focusTimerHash() => r'5eaf9d1904b3ff604f3fffa2565c869586e84205';

/// See also [FocusTimer].
@ProviderFor(FocusTimer)
final focusTimerProvider =
    NotifierProvider<FocusTimer, FocusTimerState>.internal(
  FocusTimer.new,
  name: r'focusTimerProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$focusTimerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$FocusTimer = Notifier<FocusTimerState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
