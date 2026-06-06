import 'package:achievements/core/app_info.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'update_checker.g.dart';

/// 一条「发现新版本」信息。
class UpdateInfo {
  const UpdateInfo({required this.version, required this.url, this.notes});

  /// 最新版本号(已去掉 v 前缀),如 `0.2.0`。
  final String version;

  /// Release 页面地址(供用户前往下载)。
  final String url;

  /// Release 标题 / 说明(可空)。
  final String? notes;
}

/// 通过 GitHub Releases API 检查是否有新版本。复用已有 dio,无新增依赖。
class UpdateChecker {
  const UpdateChecker();

  /// 有更新返回 [UpdateInfo];已是最新 / 网络或解析失败时返回 null(静默,不打扰)。
  Future<UpdateInfo?> check() async {
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
          headers: const {'Accept': 'application/vnd.github+json'},
        ),
      );
      final resp = await dio.getUri<Map<String, dynamic>>(
        Uri.parse(kGithubReleasesApi),
      );
      final data = resp.data;
      if (data == null) return null;
      final tag = (data['tag_name'] as String?)?.trim();
      if (tag == null || tag.isEmpty) return null;
      final latest = tag.startsWith('v') ? tag.substring(1) : tag;
      if (!isNewer(latest, kAppVersion)) return null;
      return UpdateInfo(
        version: latest,
        url: (data['html_url'] as String?) ?? kGithubUrl,
        notes: data['name'] as String?,
      );
    } on Object {
      return null;
    }
  }

  /// [a] 是否比 [b] 新(语义版本 X.Y.Z 逐段数值比较)。
  static bool isNewer(String a, String b) {
    final pa = _parts(a);
    final pb = _parts(b);
    for (var i = 0; i < 3; i++) {
      if (pa[i] != pb[i]) return pa[i] > pb[i];
    }
    return false;
  }

  /// 解析为 [major, minor, patch];忽略 `+build` / `-pre` 后缀,缺位补 0。
  static List<int> _parts(String v) {
    final nums = v
        .split('.')
        .map((s) => int.tryParse(s.split(RegExp('[+-]')).first) ?? 0)
        .toList();
    while (nums.length < 3) {
      nums.add(0);
    }
    return nums;
  }
}

@riverpod
UpdateChecker updateChecker(Ref ref) => const UpdateChecker();

/// 启动时自动检查一次。失败 / 无更新为 null;有更新为 [UpdateInfo]。
@riverpod
Future<UpdateInfo?> updateCheck(Ref ref) =>
    ref.watch(updateCheckerProvider).check();
