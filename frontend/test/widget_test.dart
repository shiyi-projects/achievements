import 'package:achievements/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('smoke: app boots to Today page', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: AchievementsApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
