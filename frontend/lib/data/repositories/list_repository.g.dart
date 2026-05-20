// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$listRepositoryHash() => r'c073d4a0e8de49373bbf294c4c9a7db6c3db7645';

/// See also [listRepository].
@ProviderFor(listRepository)
final listRepositoryProvider = Provider<ListRepository>.internal(
  listRepository,
  name: r'listRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$listRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ListRepositoryRef = ProviderRef<ListRepository>;
String _$allListsHash() => r'29baf4dc3f53fe984d0b7770e289db85df403f8d';

/// 监听所有清单(Sidebar 用)。
///
/// Copied from [allLists].
@ProviderFor(allLists)
final allListsProvider = AutoDisposeStreamProvider<List<TaskList>>.internal(
  allLists,
  name: r'allListsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$allListsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AllListsRef = AutoDisposeStreamProviderRef<List<TaskList>>;
String _$inboxListHash() => r'79a00bb9345c4c1b7245fb2489f0b96a43ca6cde';

/// 默认 Inbox 清单(系统种子)。Smart filter 视图下的快速创建落到这里。
///
/// Copied from [inboxList].
@ProviderFor(inboxList)
final inboxListProvider = FutureProvider<TaskList?>.internal(
  inboxList,
  name: r'inboxListProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$inboxListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef InboxListRef = FutureProviderRef<TaskList?>;
String _$movableListsHash() => r'0454a0481547ac68a573d48e0577354d54d2f414';

/// 任务可被移动到的目标清单:Inbox + 全部用户自定义清单。其他系统清单
/// (today/important/planned 等)是智能过滤,不存储任务,无法作为目标。
///
/// Copied from [movableLists].
@ProviderFor(movableLists)
final movableListsProvider = Provider<List<TaskList>>.internal(
  movableLists,
  name: r'movableListsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$movableListsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MovableListsRef = ProviderRef<List<TaskList>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
