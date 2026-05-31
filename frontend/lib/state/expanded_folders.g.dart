// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expanded_folders.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$expandedFoldersHash() => r'2015bdd8db976af652a3b54d33eabd2712b222de';

/// 已展开的文件夹 ID 集合。
///
/// Phase 1 仅内存态(应用关闭即重置);后续可持久化到 SharedPreferences。
///
/// Copied from [ExpandedFolders].
@ProviderFor(ExpandedFolders)
final expandedFoldersProvider =
    NotifierProvider<ExpandedFolders, Set<String>>.internal(
      ExpandedFolders.new,
      name: r'expandedFoldersProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$expandedFoldersHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ExpandedFolders = Notifier<Set<String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
