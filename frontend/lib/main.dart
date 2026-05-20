import 'package:achievements/app/app.dart';
import 'package:achievements/platform/windows/windows_app_init.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initWindowsApp();
  runApp(const ProviderScope(child: AchievementsApp()));
}
