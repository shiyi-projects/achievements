// 全局常量。

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// 旧版 Phase 0/1 占位用户 ID。仅用于 legacy 数据迁移,正常写路径禁止使用。
const String kLegacyLocalUserId = '6e6b88b6-762a-45c5-a9e8-c66c09365f87';

const String kSystemListNamespace = '4c57f2ec-6db5-5c34-a7b0-6f6c2a8c5d2f';

const Map<String, String> kLegacySystemListIds = {
  'inbox': '01900000-0000-7000-8000-000000000001',
  'today': '01900000-0000-7000-8000-000000000002',
  'important': '01900000-0000-7000-8000-000000000003',
  'planned': '01900000-0000-7000-8000-000000000004',
  'all': '01900000-0000-7000-8000-000000000005',
  'completed': '01900000-0000-7000-8000-000000000006',
  'trash': '01900000-0000-7000-8000-000000000007',
};

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
/// 系统清单 ID 通过 [systemListIdForUser] 按 appUserId + kind 确定性生成,
/// 与后端 ``app/core/system_lists.py`` 保持一致。
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

String systemListIdForUser(String userId, SystemListKind kind) {
  return _uuidV5(kSystemListNamespace, '$userId:${kind.value}');
}

/// 返回任务清单的 UI 显示名:系统清单走 [SystemListKind.displayName]
/// 中文翻译;用户自定义清单原样返回 `list.name`。
String displayNameOfList({required String fallback, String? systemKind}) {
  final kind = SystemListKind.fromValue(systemKind);
  return kind?.displayName ?? fallback;
}

String _uuidV5(String namespace, String name) {
  final ns = _uuidBytes(namespace);
  final input = Uint8List(ns.length + utf8.encode(name).length)
    ..setRange(0, ns.length, ns)
    ..setRange(
      ns.length,
      ns.length + utf8.encode(name).length,
      utf8.encode(name),
    );
  final digest = sha1.convert(input).bytes.toList();
  digest[6] = (digest[6] & 0x0f) | 0x50;
  digest[8] = (digest[8] & 0x3f) | 0x80;
  return _formatUuid(digest.sublist(0, 16));
}

Uint8List _uuidBytes(String uuid) {
  final hex = uuid.replaceAll('-', '');
  final bytes = Uint8List(16);
  for (var i = 0; i < 16; i++) {
    bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

String _formatUuid(List<int> bytes) {
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
