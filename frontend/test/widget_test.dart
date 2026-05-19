import 'package:achievements/app/app.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/bootstrap_provider.dart';
import 'package:achievements/data/repositories/folder_repository.dart';
import 'package:achievements/data/repositories/list_repository.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('smoke: app boots to Today page with empty data', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appBootstrapProvider.overrideWith((ref) async {}),
          todayTasksProvider.overrideWith(
            (ref) => Stream<List<Task>>.value([]),
          ),
          allListsProvider.overrideWith(
            (ref) => Stream<List<TaskList>>.value([]),
          ),
          allFoldersProvider.overrideWith(
            (ref) => Stream<List<Folder>>.value([]),
          ),
        ],
        child: const AchievementsApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
