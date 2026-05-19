import 'package:flutter/material.dart';

/// Material 3 主题种子色。后续接入设置页后,把种子色改成由用户设置驱动。
const Color _kSeedColor = Color(0xFF5B49E8);

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: _kSeedColor);
  return _baseTheme(scheme);
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: _kSeedColor,
    brightness: Brightness.dark,
  );
  return _baseTheme(scheme);
}

ThemeData _baseTheme(ColorScheme scheme) {
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}
