import 'package:achievements/core/constants.dart';
import 'package:achievements/data/local/database.dart';

/// 挂靠 / 拖放被拒的原因。
enum ListAttachError {
  /// 目标是自身或自身的后代,会形成环。
  cycle,

  /// 挂上去会超过 [kMaxListDepth] 层。
  tooDeep,

  /// 系统清单既不能被移动,也不能作为父节点。
  systemList,
}

/// 清单树校验失败。
class ListAttachException implements Exception {
  const ListAttachException(this.reason);

  final ListAttachError reason;

  String get message => switch (reason) {
    ListAttachError.cycle => '不能把清单移动到它自己的子清单里',
    ListAttachError.tooDeep => '清单最多嵌套 $kMaxListDepth 层',
    ListAttachError.systemList => '系统清单不能移动或作为上级',
  };

  @override
  String toString() => 'ListAttachException($reason): $message';
}

/// 能否把 [moving] 挂到 [parentId] 之下。返回 null 表示可以。
///
/// UI 的拖放高亮与仓库的写入校验共用这一份规则——否则会出现「拖得进去、
/// 落下后被拒」的割裂。
ListAttachError? checkAttach({
  required TaskList moving,
  required String? parentId,
  required List<TaskList> all,
}) {
  if (moving.isSystem) return ListAttachError.systemList;
  if (parentId == null) return null;
  if (parentId == moving.id) return ListAttachError.cycle;
  final parent = all.where((l) => l.id == parentId).firstOrNull;
  if (parent == null || parent.isSystem) return ListAttachError.systemList;
  if (subtreeIdsOf(moving.id, all).contains(parentId)) {
    return ListAttachError.cycle;
  }
  if (depthOf(parentId, all) + heightOf(moving.id, all) > kMaxListDepth) {
    return ListAttachError.tooDeep;
  }
  return null;
}

/// 节点深度,顶层记 1。数据异常成环时以 [kMaxListDepth] + 1 截断,让校验走向
/// 「拒绝」而不是死循环。
int depthOf(String id, List<TaskList> all) {
  final byId = {for (final l in all) l.id: l};
  var depth = 1;
  var cursor = byId[id]?.parentId;
  while (cursor != null && depth <= kMaxListDepth) {
    depth++;
    cursor = byId[cursor]?.parentId;
  }
  return depth;
}

/// 子树高度:只有自身为 1,带一层子清单为 2,以此类推。
int heightOf(String id, List<TaskList> all) {
  var height = 1;
  for (final child in all.where((l) => l.parentId == id)) {
    final h = 1 + heightOf(child.id, all);
    if (h > height) height = h;
  }
  return height;
}

/// 清单树的一个节点。清单是自引用树,任何一级都能装任务。
class ListTreeNode {
  ListTreeNode({
    required this.list,
    required this.depth,
    required this.children,
  });

  final TaskList list;

  /// 顶层为 1。
  final int depth;

  final List<ListTreeNode> children;

  bool get hasChildren => children.isNotEmpty;
}

/// 侧栏渲染用的扁平项:树按展开状态压平成一维,depth 决定缩进。
///
/// [parentId] / [siblingIndex] 是拖放重排要用的坐标——把某项拖到这一行前面,
/// 等价于「挂到 parentId 下的第 siblingIndex 位」。
class ListTreeRow {
  const ListTreeRow({
    required this.list,
    required this.depth,
    required this.hasChildren,
    required this.parentId,
    required this.siblingIndex,
  });

  final TaskList list;
  final int depth;
  final bool hasChildren;
  final String? parentId;
  final int siblingIndex;
}

/// 把扁平的清单行组装成树。
///
/// 只处理用户清单——系统清单是智能过滤入口,不参与树与排序。父节点缺失
/// (指向已删清单等异常)的行上浮为顶层,不会因为挂在不存在的父节点上而
/// 从侧栏消失。
List<ListTreeNode> buildListTree(List<TaskList> lists) {
  final userLists = [
    for (final l in lists)
      if (!l.isSystem) l,
  ];
  final ids = {for (final l in userLists) l.id};
  final childrenOf = <String?, List<TaskList>>{};
  for (final list in userLists) {
    final parentId = list.parentId != null && ids.contains(list.parentId)
        ? list.parentId
        : null;
    childrenOf.putIfAbsent(parentId, () => []).add(list);
  }
  for (final bucket in childrenOf.values) {
    bucket.sort(_bySortOrder);
  }

  List<ListTreeNode> build(String? parentId, int depth, Set<String> seen) {
    final children = childrenOf[parentId] ?? const <TaskList>[];
    return [
      for (final child in children)
        // 数据异常成环时(理论上被写入侧的校验挡住)就此打住,不无限递归。
        if (seen.add(child.id))
          ListTreeNode(
            list: child,
            depth: depth,
            children: build(child.id, depth + 1, seen),
          ),
    ];
  }

  return build(null, 1, <String>{});
}

/// 按展开状态把树压平成侧栏可直接遍历的一维列表。
List<ListTreeRow> flattenTree(
  List<ListTreeNode> roots,
  Set<String> expandedIds,
) {
  final rows = <ListTreeRow>[];
  void walk(List<ListTreeNode> nodes, String? parentId) {
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      rows.add(
        ListTreeRow(
          list: node.list,
          depth: node.depth,
          hasChildren: node.hasChildren,
          parentId: parentId,
          siblingIndex: i,
        ),
      );
      if (node.hasChildren && expandedIds.contains(node.list.id)) {
        walk(node.children, node.list.id);
      }
    }
  }

  walk(roots, null);
  return rows;
}

/// [rootId] 及其全部后代清单的 id(含自身)。父清单的任务视图 / 计数是整棵
/// 子树的聚合,靠这个集合展开。
List<String> subtreeIdsOf(String rootId, List<TaskList> all) {
  final ids = <String>[rootId];
  var frontier = <String>{rootId};
  while (frontier.isNotEmpty) {
    final next = <String>{
      for (final l in all)
        if (l.parentId != null &&
            frontier.contains(l.parentId) &&
            !ids.contains(l.id))
          l.id,
    };
    ids.addAll(next);
    frontier = next;
  }
  return ids;
}

int _bySortOrder(TaskList a, TaskList b) {
  final bySort = a.sortOrder.compareTo(b.sortOrder);
  return bySort != 0 ? bySort : a.name.compareTo(b.name);
}
