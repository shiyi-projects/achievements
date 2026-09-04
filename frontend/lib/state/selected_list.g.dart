// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'selected_list.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$currentListHash() => r'24474ed4b748008ac835d5adf899a32f73d5b4d4';

/// 已解析的当前清单。
///
/// 直接从清单流里取,而不是按 id 单独查库:清单被删除 / 移动后本 provider
/// 会立刻重算。选中的清单不存在或已进回收站时回退到 Today —— 否则主视图会
/// 继续渲染一个已删除的清单,新建的任务还会落进去。
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
String _$selectedListIdHash() => r'2549263769af58213b94af558a0dd87d5448e1bc';

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
