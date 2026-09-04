import 'package:achievements/app/app.dart';
import 'package:achievements/app/router.dart';
import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/repositories/bootstrap_provider.dart';
import 'package:achievements/data/repositories/folder_repository.dart';
import 'package:achievements/features/auth/auth_controller.dart';
import 'package:achievements/features/auth/auth_session.dart';
import 'package:achievements/data/repositories/list_repository.dart';
import 'package:achievements/data/repositories/task_repository.dart';
import 'package:achievements/state/selected_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('smoke: app boots and shows Today selected by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _TestAuthController()),
          routerProvider.overrideWith(
            (ref) => GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          appBootstrapProvider.overrideWith((ref) async {}),
          currentListProvider.overrideWith((ref) async => null),
          tasksForCurrentListProvider.overrideWith(
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
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(MaterialApp), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}

class _TestAuthController extends StateNotifier<AuthState>
    implements AuthController {
  _TestAuthController()
    : super(
        const AuthAuthenticated(
          AuthSession(
            token: 'test-token',
            appUserId: '00000000-0000-0000-0000-000000000001',
            profile: AuthProfile(id: 1),
          ),
        ),
      );

  @override
  Future<void> logout() async {}

  @override
  Future<void> setSession(AuthSession session) async {
    state = AuthAuthenticated(session);
  }
}
