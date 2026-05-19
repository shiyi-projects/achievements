// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stats_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$statsOverviewHash() => r'e7512870fd888f021a21573828da42874e01557a';

/// See also [statsOverview].
@ProviderFor(statsOverview)
final statsOverviewProvider = AutoDisposeFutureProvider<
    ({
      int totalCompleted,
      int todayCompleted,
      int streakDays,
      int totalFocusMinutes
    })>.internal(
  statsOverview,
  name: r'statsOverviewProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$statsOverviewHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef StatsOverviewRef = AutoDisposeFutureProviderRef<
    ({
      int totalCompleted,
      int todayCompleted,
      int streakDays,
      int totalFocusMinutes
    })>;
String _$statsHeatmapHash() => r'44b48124036c7d48b56a371fbc6ae9032104f5c3';

/// See also [statsHeatmap].
@ProviderFor(statsHeatmap)
final statsHeatmapProvider =
    AutoDisposeFutureProvider<Map<String, int>>.internal(
  statsHeatmap,
  name: r'statsHeatmapProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$statsHeatmapHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef StatsHeatmapRef = AutoDisposeFutureProviderRef<Map<String, int>>;
String _$statsFocusHash() => r'f167f3e3420df6ab2056a938abcd519cdf532da9';

/// See also [statsFocus].
@ProviderFor(statsFocus)
final statsFocusProvider = AutoDisposeFutureProvider<
    List<({String date, int sessions, int minutes})>>.internal(
  statsFocus,
  name: r'statsFocusProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$statsFocusHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef StatsFocusRef = AutoDisposeFutureProviderRef<
    List<({String date, int sessions, int minutes})>>;
String _$statsTrendsHash() => r'473df4b2e83f1ffc73ad81cdb42cddecdd98f0e5';

/// See also [statsTrends].
@ProviderFor(statsTrends)
final statsTrendsProvider = AutoDisposeFutureProvider<
    List<({String date, int completed, int created})>>.internal(
  statsTrends,
  name: r'statsTrendsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$statsTrendsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef StatsTrendsRef = AutoDisposeFutureProviderRef<
    List<({String date, int completed, int created})>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
