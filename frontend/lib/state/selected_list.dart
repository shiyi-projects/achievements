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

  /// 回到默认视图(选中的清单被删除时)。
  void clear() => state = null;
}

/// 已解析的当前清单。
///
/// 直接从清单流里取,而不是按 id 单独查库:清单被删除 / 移动后本 provider
/// 会立刻重算。选中的清单不存在或已进回收站时回退到 Today —— 否则主视图会
/// 继续渲染一个已删除的清单,新建的任务还会落进去。
@Riverpod(keepAlive: true)
Future<TaskList?> currentList(Ref ref) async {
  final id = ref.watch(selectedListIdProvider);
  final all = await ref.watch(allListsProvider.future);
  if (id != null) {
    final found = all.where((l) => l.id == id).firstOrNull;
    if (found != null) return found;
  }
  return all
      .where((l) => l.systemKind == SystemListKind.today.value)
      .firstOrNull;
}
