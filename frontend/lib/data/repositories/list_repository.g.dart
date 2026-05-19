// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'list_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$listRepositoryHash() => r'70a4308d29b4155c540a0b77435d5a4b31760d52';

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
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$allListsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AllListsRef = AutoDisposeStreamProviderRef<List<TaskList>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
