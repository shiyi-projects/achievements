// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'selected_list.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$currentListHash() => r'2dadc51aaa4cacc4070f0d1916273088b0dfea1a';

/// 已解析的当前清单(从 [SelectedListId] 拉真实 [TaskList] 行)。
///
/// 若 [SelectedListId] 为 null,回退到 SystemListKind.today。
///
/// Copied from [currentList].
@ProviderFor(currentList)
final currentListProvider = FutureProvider<TaskList?>.internal(
  currentList,
  name: r'currentListProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentListRef = FutureProviderRef<TaskList?>;
String _$selectedListIdHash() => r'b4537635e436348218a3a312be77dee29213abb7';

/// 当前 Sidebar 选中的清单 ID。
///
/// `null` 时主视图默认渲染 Today(系统清单)。
///
/// Copied from [SelectedListId].
@ProviderFor(SelectedListId)
final selectedListIdProvider =
    NotifierProvider<SelectedListId, String?>.internal(
      SelectedListId.new,
      name: r'selectedListIdProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$selectedListIdHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SelectedListId = Notifier<String?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
