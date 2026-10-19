import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimensions.dart';

/// Builds the light theme. A dark theme can be introduced later; keep the
/// token usage here so both themes would share component configuration.
ThemeData buildAppTheme() {
  const colorScheme = ColorScheme.light(
    primary: AppColors.emerald600,
    onPrimary: AppColors.onCta,
    secondary: AppColors.ink700,
    surface: AppColors.surface,
    onSurface: AppColors.ink900,
    error: AppColors.rose600,
    onError: Colors.white,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Inter',
    splashFactory: InkSparkle.splashFactory,
  );

  final textTheme = _buildTextTheme(base.textTheme);
  final inputBorder = _inputBorder(AppColors.border);

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: AppColors.ink900),
      titleTextStyle: textTheme.titleMedium,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: _inputBorder(AppColors.emerald600, width: 1.6),
      errorBorder: _inputBorder(AppColors.rose600),
      focusedErrorBorder: _inputBorder(AppColors.rose600, width: 1.6),
      hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.slate400),
      labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.ink600),
      helperStyle: textTheme.bodySmall?.copyWith(color: AppColors.slate500),
      errorStyle: textTheme.bodySmall?.copyWith(
        color: AppColors.rose600,
        height: 1.3,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.emerald600,
        foregroundColor: AppColors.onCta,
        disabledBackgroundColor: AppColors.slate200,
        disabledForegroundColor: AppColors.slate500,
        minimumSize: const Size.fromHeight(TouchTarget.minInteractive),
        textStyle: textTheme.titleSmall?.copyWith(
          color: AppColors.onCta,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink900,
        minimumSize: const Size.fromHeight(TouchTarget.minInteractive),
        side: const BorderSide(color: AppColors.border, width: 1.2),
        textStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.emerald600,
        textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink900,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: AppColors.surface,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.emerald50,
      labelStyle: textTheme.labelMedium?.copyWith(
        color: AppColors.emerald700,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.emerald600,
    ),
    dividerColor: AppColors.border,
  );
}

InputBorder _inputBorder(Color color, {double width = 1.2}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: color, width: width),
    );

/// Inter variable font: weight is carried through [fontVariations] so each
/// named style resolves to the correct weight axis value.
TextTheme _buildTextTheme(TextTheme base) {
  TextStyle style(TextStyle s, {double? wght, Color? color, double? size}) =>
      s.copyWith(
        color: color,
        fontSize: size ?? s.fontSize,
        fontVariations: [FontVariation('wght', wght ?? 400)],
      );

  return base
      .copyWith(
        displaySmall: style(
          base.displaySmall!,
          wght: 700,
          color: AppColors.ink900,
        ),
        headlineMedium: style(
          base.headlineMedium!,
          wght: 700,
          color: AppColors.ink900,
        ),
        headlineSmall: style(
          base.headlineSmall!,
          wght: 700,
          color: AppColors.ink900,
        ),
        titleLarge: style(base.titleLarge!, wght: 600, color: AppColors.ink900),
        titleMedium: style(
          base.titleMedium!,
          wght: 600,
          color: AppColors.ink900,
        ),
        titleSmall: style(base.titleSmall!, wght: 600, color: AppColors.ink900),
        bodyLarge: style(base.bodyLarge!, wght: 400, color: AppColors.ink700),
        bodyMedium: style(base.bodyMedium!, wght: 400, color: AppColors.ink700),
        bodySmall: style(base.bodySmall!, wght: 400, color: AppColors.ink600),
        labelLarge: style(base.labelLarge!, wght: 600, color: AppColors.ink900),
        labelMedium: style(
          base.labelMedium!,
          wght: 500,
          color: AppColors.ink600,
        ),
        labelSmall: style(
          base.labelSmall!,
          wght: 500,
          color: AppColors.slate500,
        ),
      )
      .apply(fontFamily: 'Inter');
}
