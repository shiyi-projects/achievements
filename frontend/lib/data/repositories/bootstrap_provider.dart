import 'package:achievements/data/repositories/list_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bootstrap_provider.g.dart';

/// 应用启动期一次性初始化:
///   - 种入系统清单(幂等,已存在则跳过)
///
/// AchievementsApp 在渲染前 watch 此 Future,完成后再放行 router。
@Riverpod(keepAlive: true)
Future<void> appBootstrap(Ref ref) async {
  await ref.read(listRepositoryProvider).ensureSystemLists();
}
