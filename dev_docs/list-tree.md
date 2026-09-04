# 清单树(取代文件夹)

> 落地版本:v0.4.0 · 前端 Drift schema v12 · 后端 alembic `a1f4c7d92b30`

## 1. 为什么改

旧模型里「文件夹」是一个残废容器,三个「不能」:

1. **不能装任务**,只能装清单 —— 想在「工作」下记一件事,得先建一个「工作」清单,概念上重复一层;
2. **不能被打开** —— 点文件夹只有折叠 / 展开,没有「这个文件夹下的全部任务」的视图,分组只服务于折叠;
3. **不能嵌套**,而且只能待在顶层。

层级模型因此自相矛盾:`task` 有 `parent_id` 支持无限嵌套,`list` 有一层 `folder_id`,`folder` 完全扁平 —— 同一个应用里三套规则。侧栏排序断裂只是它的表征:文件夹与清单是两张表、两个 `sort_order` 命名空间,却要画在同一列里,于是「文件夹恒在上」成了写死的结构,`sort_order` 还要靠 `?? 99` 这种魔法值绕开系统清单占用的 0..6。

**结论:文件夹和清单本就是同一种东西的两种权限。** 合并成一棵自引用树,上述症状一次性消失。

## 2. 模型

```
task_lists (id, user_id, parent_id?, name, color, icon, sort_order,
            is_system, system_kind?, trashed_with?, deleted_at?, version, ...)
  └─ parent_id 自引用,null = 顶层
  └─ 任何清单都能直接装任务,也能装子清单
tasks.list_id → 任意清单(含有子清单的那些)
```

- **深度上限 3 层**(顶层记 1)。前端 `kMaxListDepth`、后端 `MAX_LIST_DEPTH`,两处必须一致。
- **系统清单**(Today / Inbox / …)恒为顶层、不参与用户排序、不能被移动、也不能作为父节点。它们是智能过滤入口,不进清单树。
- **排序**:同一 `parent_id` 下的用户清单 `sort_order` 连续编号 0..n。移动 / 重排在事务内整体重编号,只对变化的行 enqueue。
- **聚合视图**:选中一个清单 = 看它自己 + 全部后代清单的任务(`list_id IN 子树`)。侧栏徽标同口径。

## 3. 删除与还原

删清单是级联的:自身 + 全部后代清单 + 这些清单下的所有任务一起进回收站。

- 被**连带**删除的行记 `trashed_with = 发起删除的那个清单 id`;
- 发起删除的那条自己 `trashed_with = null` —— 它才是回收站里露出的那一条;
- 还原时把 `trashed_with` 指向它的清单与任务一并带回,因此**不会复活用户先前单独删掉的任务**(那些行的 `trashed_with` 是 null);
- 还原时若原父清单已不在,自动上浮到顶层,不留孤儿;
- 回收站的任务分区只列 `trashed_with IS NULL` 的任务,否则一个清单的内容会把回收站淹掉。

## 4. 校验(成环 / 过深)

规则只写一份:

- 前端 `data/models/list_tree.dart` 的 `checkAttach()` —— 拖放高亮与 `ListRepository` 的写入校验共用,避免「拖得进去、落下后被拒」;
- 后端 `app/core/list_tree.py` 的 `validate_parent()` —— sync apply 时兜底。客户端可以是任何版本,树的形状必须由服务端最终把关,否则一次错误的 `parent_id` 会同步到所有设备。

拒绝三类:父清单不存在 / 不属于该用户 / 是系统清单;父清单落在自己的子树里(成环);挂上去后整棵子树超过深度上限。

## 5. 迁移与兼容

**数据迁移**(前端 v11→v12 / 后端 `a1f4c7d92b30`,两侧同构):

1. `task_lists` 加 `parent_id`、`trashed_with`,`tasks` 加 `trashed_with`;
2. `folder_id` 平移到 `parent_id`;
3. `folders` 每行插成一条顶层清单,**沿用原 id**(否则各端同步主键错位);
4. 顶层用户清单重编号为连续序号,文件夹仍排在原根清单之前(与旧 UI 视觉一致);
5. 丢掉 `folder_id` 列,drop `folders`。

覆盖测试:`frontend/test/migration_v12_list_tree_test.dart` 按 v11 结构造库跑真迁移。

**旧客户端**:不做协议翻译层,直接强制升级。`/sync` 的两个端点校验 `X-Client-Version`,低于 `MIN_CLIENT_VERSION`(0.4.0)或缺失回 426;客户端识别后停止重试并提示升级,outbox 原样保留。

> ⚠️ 提高 `MIN_CLIENT_VERSION` 时,务必确认当前发布版本号 ≥ 该值,否则新客户端会被自己的服务端拒之门外。

## 6. 代码位置速查

| 关注点 | 位置 |
|---|---|
| 树结构 / 校验 / 扁平化(前端) | `frontend/lib/data/models/list_tree.dart` |
| 清单读写、级联删除、还原、重排 | `frontend/lib/data/repositories/list_repository.dart` |
| 侧栏行(拖拽 / 菜单 / 展开) | `frontend/lib/features/sidebar/widgets/list_tree_tile.dart` |
| 行间插入落点(排序) | 同上,`ListInsertionSlot` |
| 展开态持久化 | `frontend/lib/state/expanded_lists.dart` |
| 回收站清单分区 | `frontend/lib/features/list_view/list_page.dart` |
| 树约束(后端) | `backend/app/core/list_tree.py` |
| 版本门槛(后端) | `backend/app/core/client_version.py` |
