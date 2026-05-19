import 'package:achievements/core/constants.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/list_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'selected_list.g.dart';

/// 当前 Sidebar 选中的清单 ID。
///
/// `null` 时主视图默认渲染 Today(系统清单)。
@Riverpod(keepAlive: true)
class SelectedListId extends _$SelectedListId {
  @override
  String? build() => null;

  // ignore: use_setters_to_change_properties — Riverpod 推荐用 method
  void select(String id) => state = id;
}

/// 已解析的当前清单(从 [SelectedListId] 拉真实 [TaskList] 行)。
///
/// 若 [SelectedListId] 为 null,回退到 SystemListKind.today。
@Riverpod(keepAlive: true)
Future<TaskList?> currentList(Ref ref) async {
  final id = ref.watch(selectedListIdProvider);
  final repo = ref.watch(listRepositoryProvider);
  if (id == null) {
    return repo.findBySystemKind(SystemListKind.today);
  }
  return repo.findById(id);
}
