import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'expanded_folders.g.dart';

/// 已展开的文件夹 ID 集合。
///
/// Phase 1 仅内存态(应用关闭即重置);后续可持久化到 SharedPreferences。
@Riverpod(keepAlive: true)
class ExpandedFolders extends _$ExpandedFolders {
  @override
  Set<String> build() => <String>{};

  void toggle(String folderId) {
    final next = {...state};
    if (!next.add(folderId)) next.remove(folderId);
    state = next;
  }
}
