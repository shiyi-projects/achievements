import 'package:flutter/material.dart';

/// Phase 0 占位首页。Phase 1 会替换为真正的 Today 视图:
/// 欢迎语 / 日期 / 任务统计 / 任务列表 / 快速创建输入框等。
class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Today')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Achievements', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(
                'Phase 0 scaffold ready — Task #8 has wired theme + router + root app.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
