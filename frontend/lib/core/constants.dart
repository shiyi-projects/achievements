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

  /// 系统清单的中文显示名。DB 里 seed 的英文名(Inbox / Today / …) 是
  /// 同步协议的稳定标识,UI 这一层统一走此 getter 做翻译。
  String get displayName => switch (this) {
    SystemListKind.inbox => '收件箱',
    SystemListKind.today => '今天',
    SystemListKind.important => '重要',
    SystemListKind.planned => '计划',
    SystemListKind.all => '全部任务',
    SystemListKind.completed => '已完成',
    SystemListKind.trash => '回收站',
  };

  static SystemListKind? fromValue(String? value) {
    if (value == null) return null;
    for (final kind in SystemListKind.values) {
      if (kind.value == value) return kind;
    }
    return null;
  }
}

/// 返回任务清单的 UI 显示名:系统清单走 [SystemListKind.displayName]
/// 中文翻译;用户自定义清单原样返回 `list.name`。
String displayNameOfList({required String fallback, String? systemKind}) {
  final kind = SystemListKind.fromValue(systemKind);
  return kind?.displayName ?? fallback;
}
