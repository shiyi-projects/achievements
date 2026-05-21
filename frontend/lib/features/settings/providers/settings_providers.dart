import 'package:achievements/data/local/database.dart';
import 'package:achievements/data/local/database_provider.dart';
import 'package:achievements/features/settings/models/app_settings.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_providers.g.dart';

const _keyThemeMode = 'theme_mode';
const _keySeedColor = 'seed_color';
const _keyCloseAction = 'close_action';

@Riverpod(keepAlive: true)
class SettingsNotifier extends _$SettingsNotifier {
  @override
  Future<AppSettingsData> build() async {
    final db = ref.read(appDatabaseProvider);
    final rows = await db.select(db.appPreferences).get();
    final map = {for (final r in rows) r.key: r.value};
    return (
      themeMode: _parseThemeMode(map[_keyThemeMode]),
      seedColor: _parseSeedColor(map[_keySeedColor]),
      closeAction: CloseAction.fromValue(map[_keyCloseAction]),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _upsert(_keyThemeMode, _themeModeToString(mode));
    final current = state.valueOrNull ?? kDefaultSettings;
    state = AsyncData((
      themeMode: mode,
      seedColor: current.seedColor,
      closeAction: current.closeAction,
    ));
  }

  Future<void> setSeedColor(Color color) async {
    await _upsert(_keySeedColor, color.toARGB32().toString());
    final current = state.valueOrNull ?? kDefaultSettings;
    state = AsyncData((
      themeMode: current.themeMode,
      seedColor: color,
      closeAction: current.closeAction,
    ));
  }

  Future<void> setCloseAction(CloseAction action) async {
    await _upsert(_keyCloseAction, action.value);
    final current = state.valueOrNull ?? kDefaultSettings;
    state = AsyncData((
      themeMode: current.themeMode,
      seedColor: current.seedColor,
      closeAction: action,
    ));
  }

  Future<void> _upsert(String key, String value) async {
    final db = ref.read(appDatabaseProvider);
    await db.into(db.appPreferences).insertOnConflictUpdate(
      AppPreferencesCompanion(
        key: Value(key),
        value: Value(value),
      ),
    );
  }

  static ThemeMode _parseThemeMode(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static String _themeModeToString(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };

  static Color _parseSeedColor(String? value) {
    if (value == null) return kDefaultSettings.seedColor;
    final intVal = int.tryParse(value);
    return intVal != null ? Color(intVal) : kDefaultSettings.seedColor;
  }
}
