import 'package:achievements/core/constants.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/models/list_tree.dart';
import 'package:flutter_test/flutter_test.dart';

TaskList _list(
  String id, {
  String? parentId,
  int sortOrder = 0,
  bool isSystem = false,
  String? systemKind,
}) {
  final now = DateTime(2026);
  return TaskList(
    id: id,
    userId: 'u-1',
    parentId: parentId,
    name: id,
    sortOrder: sortOrder,
    isSystem: isSystem,
    systemKind: systemKind,
    createdAt: now,
    updatedAt: now,
    version: 1,
  );
}

void main() {
  group('buildListTree', () {
    test('按 parentId 组装层级,同级按 sortOrder 排序', () {
      final tree = buildListTree([
        _list('b', sortOrder: 1),
        _list('a', sortOrder: 0),
        _list('a2', parentId: 'a', sortOrder: 1),
        _list('a1', parentId: 'a', sortOrder: 0),
      ]);

      expect(tree.map((n) => n.list.id), ['a', 'b']);
      expect(tree.first.children.map((n) => n.list.id), ['a1', 'a2']);
      expect(tree.first.depth, 1);
      expect(tree.first.children.first.depth, 2);
    });

    test('系统清单不进树', () {
      final tree = buildListTree([
        _list('today', isSystem: true, systemKind: 'today'),
        _list('work'),
      ]);
      expect(tree.map((n) => n.list.id), ['work']);
    });

    test('父节点缺失的清单上浮为顶层,而不是从侧栏消失', () {
      final tree = buildListTree([_list('orphan', parentId: 'gone')]);
      expect(tree.map((n) => n.list.id), ['orphan']);
      expect(tree.single.depth, 1);
    });

    test('成环数据不会导致无限递归', () {
      final tree = buildListTree([
        _list('a', parentId: 'b'),
        _list('b', parentId: 'a'),
      ]);
      // 两条都挂在对方下,谁也不是顶层 —— 只要不挂死、不重复展开即可。
      expect(tree, isEmpty);
    });
  });

  group('flattenTree', () {
    final lists = [
      _list('a'),
      _list('a1', parentId: 'a'),
      _list('b', sortOrder: 1),
    ];

    test('折叠时不展开子节点', () {
      final rows = flattenTree(buildListTree(lists), <String>{});
      expect(rows.map((r) => r.list.id), ['a', 'b']);
      expect(rows.first.hasChildren, isTrue);
    });

    test('展开后带出子节点,并标出同级坐标', () {
      final rows = flattenTree(buildListTree(lists), {'a'});
      expect(rows.map((r) => r.list.id), ['a', 'a1', 'b']);

      final child = rows[1];
      expect(child.depth, 2);
      expect(child.parentId, 'a');
      expect(child.siblingIndex, 0);

      final second = rows[2];
      expect(second.parentId, isNull);
      expect(second.siblingIndex, 1);
    });
  });

  group('checkAttach', () {
    test('挂到顶层永远允许', () {
      final all = [_list('a')];
      expect(checkAttach(moving: all.first, parentId: null, all: all), isNull);
    });

    test('挂到自己或自己的后代 → cycle', () {
      final all = [_list('a'), _list('a1', parentId: 'a')];
      expect(
        checkAttach(moving: all[0], parentId: 'a', all: all),
        ListAttachError.cycle,
      );
      expect(
        checkAttach(moving: all[0], parentId: 'a1', all: all),
        ListAttachError.cycle,
      );
    });

    test('系统清单既不能移动也不能当父节点', () {
      final all = [
        _list('today', isSystem: true, systemKind: 'today'),
        _list('work'),
      ];
      expect(
        checkAttach(moving: all[0], parentId: null, all: all),
        ListAttachError.systemList,
      );
      expect(
        checkAttach(moving: all[1], parentId: 'today', all: all),
        ListAttachError.systemList,
      );
    });

    test('父深度 + 子树高度超过上限 → tooDeep', () {
      final all = [
        _list('a'),
        _list('a1', parentId: 'a'),
        _list('a2', parentId: 'a1'), // a 子树已占满 kMaxListDepth
        _list('x'),
        _list('x1', parentId: 'x'), // x 自带一层,高度 2
        _list('leaf'), // 高度 1
      ];
      // 单节点挂到第 2 层之下 → 正好 3 层,允许。
      expect(checkAttach(moving: all[5], parentId: 'a1', all: all), isNull);
      // 同一个单节点挂到第 3 层之下 → 4 层,拒绝。
      expect(
        checkAttach(moving: all[5], parentId: 'a2', all: all),
        ListAttachError.tooDeep,
      );
      // 带一层子清单的 x 挂到第 2 层之下也会变成 4 层,拒绝。
      expect(
        checkAttach(moving: all[3], parentId: 'a1', all: all),
        ListAttachError.tooDeep,
      );
      expect(kMaxListDepth, 3);
    });
  });

  group('subtreeIdsOf', () {
    test('含自身与全部后代', () {
      final all = [
        _list('a'),
        _list('a1', parentId: 'a'),
        _list('a1a', parentId: 'a1'),
        _list('b'),
      ];
      expect(subtreeIdsOf('a', all), ['a', 'a1', 'a1a']);
      expect(subtreeIdsOf('b', all), ['b']);
    });
  });
}
