import 'package:achievements/core/theme/app_colors.dart';
import 'package:achievements/core/theme/app_dimensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Material 3 主题配置。
///
/// 种子色: 科技蓝 (#0078D4)。
/// 后续接入设置页后,种子色由用户偏好驱动,可切换 [AppColors] 中的预设。
///
/// 组件主题覆盖全部按 ui_design_spec 落地:
///   - Card 16px 圆角
///   - FilledButton 20px 圆角
///   - InputDecoration 12px 圆角
///   - Dialog / BottomSheet 28px 圆角
///   - Checkbox 圆形
///   - AppBar 无阴影
///
/// 暗色模式单独调优:
///   - 表面色更暗以增加深度感
///   - 卡片与容器增加微弱边框提升层次
///   - 阴影改为高亮边框策略(暗色下阴影不可见)
///   - splash/highlight 更明亮以增强触觉反馈
ThemeData buildLightTheme([Color seedColor = AppColors.seedTechBlue]) {
  final scheme = ColorScheme.fromSeed(seedColor: seedColor);
  return _buildTheme(scheme);
}

ThemeData buildDarkTheme([Color seedColor = AppColors.seedTechBlue]) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.dark,
  );
  return _buildTheme(scheme);
}

/// 全局字体族：Windows 优先使用 "Microsoft YaHei UI"（微软雅黑 UI 变体）,
/// 该字体在各字重下渲染更均匀、字间距更紧凑,中英混排一致性好。
/// 回退列表覆盖 macOS (PingFang) / Linux (Noto Sans SC) / Android。
const _kFontFamily = 'Microsoft YaHei UI';
const _kFontFallback = [
  'Microsoft YaHei',
  'PingFang SC',
  'Noto Sans SC',
  'Segoe UI',
  'sans-serif',
];

ThemeData _buildTheme(ColorScheme scheme) {
  final isLight = scheme.brightness == Brightness.light;

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: _kFontFamily,
    fontFamilyFallback: _kFontFallback,
    visualDensity: VisualDensity.adaptivePlatformDensity,

    // ── 页面过渡统一为淡入上移 ──
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),

    // ── 字体 ──
    textTheme: _buildTextTheme(scheme),

    // ── AppBar ──
    appBarTheme: AppBarTheme(
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: scheme.onSurface,
        letterSpacing: 0,
      ),
    ),

    // ── Card ── 暗色模式增加微弱边框
    cardTheme: CardThemeData(
      elevation: isLight ? 0 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        side: isLight
            ? BorderSide.none
            : BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.15)),
      ),
      color: isLight ? scheme.surfaceContainerLow : scheme.surfaceContainer,
      margin: const EdgeInsets.symmetric(
        horizontal: Spacing.base,
        vertical: Spacing.xs,
      ),
    ),

    // ── FilledButton ──
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.button),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.xl,
          vertical: Spacing.md,
        ),
      ),
    ),

    // ── OutlinedButton ──
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.button),
        ),
      ),
    ),

    // ── TextButton ──
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.button),
        ),
      ),
    ),

    // ── Input ── 暗色加微弱边框
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isLight
          ? scheme.surfaceContainerHighest.withValues(alpha: 0.5)
          : scheme.surfaceContainerHigh.withValues(alpha: 0.6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.input),
        borderSide: isLight
            ? BorderSide.none
            : BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.input),
        borderSide: isLight
            ? BorderSide.none
            : BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.input),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Spacing.base,
        vertical: Spacing.md,
      ),
    ),

    // ── Dialog ──
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.sheet),
      ),
      elevation: isLight ? 3 : 6,
      backgroundColor: isLight ? scheme.surface : scheme.surfaceContainerHigh,
      surfaceTintColor: scheme.surfaceTint,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
        fontFamily: _kFontFamily,
        fontFamilyFallback: _kFontFallback,
      ),
      contentTextStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: scheme.onSurfaceVariant,
        height: 1.5,
        fontFamily: _kFontFamily,
        fontFamilyFallback: _kFontFallback,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        Spacing.xl,
        0,
        Spacing.xl,
        Spacing.lg,
      ),
    ),

    // ── BottomSheet ──
    bottomSheetTheme: BottomSheetThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
      showDragHandle: true,
      dragHandleColor: scheme.outlineVariant.withValues(alpha: 0.4),
      dragHandleSize: const Size(36, 4),
      elevation: isLight ? 2 : 8,
      surfaceTintColor: scheme.surfaceTint,
      backgroundColor: isLight ? scheme.surface : scheme.surfaceContainerHigh,
    ),

    // ── DatePicker ──
    datePickerTheme: DatePickerThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.sheet),
      ),
      headerBackgroundColor: scheme.primaryContainer,
      headerForegroundColor: scheme.onPrimaryContainer,
      surfaceTintColor: scheme.surfaceTint,
      dayStyle: TextStyle(
        fontSize: 14,
        fontFamily: _kFontFamily,
        fontFamilyFallback: _kFontFallback,
      ),
      todayBorder: BorderSide(color: scheme.primary, width: 1.5),
      todayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return scheme.onPrimary;
        return scheme.primary;
      }),
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return scheme.onPrimary;
        if (states.contains(WidgetState.disabled)) {
          return scheme.onSurface.withValues(alpha: 0.38);
        }
        return scheme.onSurface;
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return scheme.primary;
        return null;
      }),
      cancelButtonStyle: TextButton.styleFrom(
        foregroundColor: scheme.onSurfaceVariant,
      ),
      confirmButtonStyle: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.button),
        ),
      ),
    ),

    // ── TimePicker ──
    timePickerTheme: TimePickerThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.sheet),
      ),
      hourMinuteShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      dayPeriodShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.input),
      ),
      dayPeriodBorderSide: BorderSide(color: scheme.outline),
      hourMinuteColor: WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return scheme.primaryContainer;
        }
        return scheme.surfaceContainerHighest;
      }),
      hourMinuteTextColor: WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return scheme.onPrimaryContainer;
        }
        return scheme.onSurface;
      }),
      dialHandColor: scheme.primary,
      dialBackgroundColor: scheme.surfaceContainerHighest,
      dialTextColor: WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return scheme.onPrimary;
        return scheme.onSurface;
      }),
      cancelButtonStyle: TextButton.styleFrom(
        foregroundColor: scheme.onSurfaceVariant,
      ),
      confirmButtonStyle: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.button),
        ),
      ),
    ),

    // ── PopupMenu ──
    popupMenuTheme: PopupMenuThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      elevation: isLight ? 4 : 8,
      surfaceTintColor: scheme.surfaceTint,
      color: isLight ? scheme.surface : scheme.surfaceContainerHigh,
      textStyle: TextStyle(
        fontSize: 14,
        color: scheme.onSurface,
        fontFamily: _kFontFamily,
        fontFamilyFallback: _kFontFallback,
      ),
    ),

    // ── Checkbox ──
    checkboxTheme: CheckboxThemeData(
      shape: const CircleBorder(),
      side: BorderSide(color: scheme.outline, width: 2),
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return scheme.primary;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(scheme.onPrimary),
    ),

    // ── ListTile ──
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.input),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.base),
    ),

    // ── NavigationBar ── 暗色底部导航增加分隔线
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: scheme.secondaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      elevation: 0,
      backgroundColor: isLight ? scheme.surface : scheme.surfaceContainer,
    ),

    // ── Divider ──
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: isLight ? 0.5 : 0.3),
      thickness: 1,
      space: 1,
    ),

    // ── SegmentedButton ──
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.chip),
          ),
        ),
      ),
    ),

    // ── Chip ──
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
    ),

    // ── FAB ──
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      elevation: isLight ? 2 : 4,
      shape: const CircleBorder(),
    ),

    // ── Snackbar ──
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.input),
      ),
    ),

    // ── Tooltip — 暗色模式下更明亮 ──
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: isLight ? scheme.inverseSurface : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      textStyle: TextStyle(
        color: isLight ? scheme.onInverseSurface : scheme.onSurface,
        fontSize: 12,
      ),
    ),

    // ── 杂项 ── 暗色模式下 splash 更明亮
    splashColor: isLight
        ? scheme.primary.withValues(alpha: 0.08)
        : scheme.primary.withValues(alpha: 0.16),
    highlightColor: isLight
        ? scheme.primary.withValues(alpha: 0.05)
        : scheme.primary.withValues(alpha: 0.10),
  );
}

/// 按 ui_design_spec §3.1 构建字体比例尺。
TextTheme _buildTextTheme(ColorScheme scheme) {
  const base = TextTheme(
    displayLarge: TextStyle(
      fontSize: 57,
      fontWeight: FontWeight.w400,
      height: 64 / 57,
      letterSpacing: -0.25,
    ),
    displayMedium: TextStyle(
      fontSize: 45,
      fontWeight: FontWeight.w400,
      height: 52 / 45,
    ),
    displaySmall: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w400,
      height: 44 / 36,
    ),
    headlineLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      height: 40 / 32,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      height: 36 / 28,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      height: 32 / 24,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w500,
      height: 28 / 22,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 24 / 16,
      letterSpacing: 0.15,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 20 / 14,
      letterSpacing: 0.1,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 24 / 16,
      letterSpacing: 0.15,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 20 / 14,
      letterSpacing: 0.25,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 16 / 12,
      letterSpacing: 0.4,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 20 / 14,
      letterSpacing: 0.1,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 16 / 12,
      letterSpacing: 0.5,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      height: 16 / 11,
      letterSpacing: 0.5,
    ),
  );

  return base.apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
    fontFamily: _kFontFamily,
    fontFamilyFallback: _kFontFallback,
  );
}
