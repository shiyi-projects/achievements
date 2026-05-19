// 全局常量。

/// Phase 0/1 占位用户 ID,所有本地实体写入此 user_id。
/// 启用真实账号后替换为登录返回的 user_id。
const String kLocalUserId = '00000000-0000-0000-0000-000000000001';

/// 内置系统清单类别。
///
/// 这些清单会在首次启动时由 ListRepository.ensureSystemLists 写入,
/// `isSystem=true`,不可删除。Sidebar 据此渲染固定入口。
enum SystemListKind {
  inbox('inbox'),
  today('today'),
  important('important'),
  planned('planned'),
  all('all'),
  completed('completed'),
  trash('trash');

  const SystemListKind(this.value);
  final String value;

  static SystemListKind? fromValue(String? value) {
    if (value == null) return null;
    for (final kind in SystemListKind.values) {
      if (kind.value == value) return kind;
    }
    return null;
  }
}
