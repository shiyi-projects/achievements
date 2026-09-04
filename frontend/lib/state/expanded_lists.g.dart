// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expanded_lists.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$expandedListsHash() => r'bba30866a36d9a5caf8dc908360c669892be164a';

/// 侧栏里已展开的清单 ID 集合(有子清单的那些)。
///
/// 持久化到本地 `app_preferences`,冷启动后保持上次的展开状态——清单一多,
/// 每次开机全部折叠会让侧栏不可用。不入 outbox:展开与否是本机视图偏好。
///
/// Copied from [ExpandedLists].
@ProviderFor(ExpandedLists)
final expandedListsProvider =
    NotifierProvider<ExpandedLists, Set<String>>.internal(
      ExpandedLists.new,
      name: r'expandedListsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$expandedListsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ExpandedLists = Notifier<Set<String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
