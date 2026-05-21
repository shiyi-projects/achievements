// 全局常量。

/// Phase 0/1 占位用户 ID,所有本地实体写入此 user_id。
/// 启用真实账号后替换为登录返回的 user_id。
///
/// **必须与后端 `.env*` 的 `LOCAL_USER_ID` 保持一致**,否则同步引擎会把云端数据
/// 当作另一个用户的,推/拉都对不上。改这个常量要同时改后端 env。
const String kLocalUserId = '6e6b88b6-762a-45c5-a9e8-c66c09365f87';

/// 任务优先级。落库 `tasks.priority` 列,0 / 1 / 2 / 3。
enum TaskPriority {
  none(0, 'None'),
  low(1, 'Low'),
  medium(2, 'Medium'),
  high(3, 'High');

  const TaskPriority(this.value, this.label);
  final int value;
  final String label;

  static TaskPriority fromValue(int value) {
    for (final p in TaskPriority.values) {
      if (p.value == value) return p;
    }
    return TaskPriority.none;
  }
}

/// 内置系统清单类别。
///
/// 这些清单会在首次启动时由 ListRepository.ensureSystemLists 写入,
/// `isSystem=true`,不可删除。Sidebar 据此渲染固定入口。
///
/// 每个 kind 绑定一个固定 UUID(``id``),与后端
/// ``app/core/system_lists.py:SYSTEM_LIST_IDS`` 保持一致。两端用同一主键
/// 落库,sync pull 通过 `insertOnConflictUpdate` 命中既有行,避免重复。
enum SystemListKind {
  inbox('inbox', '01900000-0000-7000-8000-000000000001'),
  today('today', '01900000-0000-7000-8000-000000000002'),
  important('important', '01900000-0000-7000-8000-000000000003'),
  planned('planned', '01900000-0000-7000-8000-000000000004'),
  all('all', '01900000-0000-7000-8000-000000000005'),
  completed('completed', '01900000-0000-7000-8000-000000000006'),
  trash('trash', '01900000-0000-7000-8000-000000000007');

  const SystemListKind(this.value, this.id);
  final String value;
  final String id;

  static SystemListKind? fromValue(String? value) {
    if (value == null) return null;
    for (final kind in SystemListKind.values) {
      if (kind.value == value) return kind;
    }
    return null;
  }
}
