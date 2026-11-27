import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(
    Brightness.light,
    background: AppColors.backgroundLight,
    surface: AppColors.surfaceLight,
    text: AppColors.textPrimaryLight,
  );

  static ThemeData get dark => _build(
    Brightness.dark,
    background: AppColors.backgroundDark,
    surface: AppColors.surfaceDark,
    text: AppColors.textPrimaryDark,
  );

  static ThemeData _build(
    Brightness brightness, {
    required Color background,
    required Color surface,
    required Color text,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      surface: surface,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: ThemeData(brightness: brightness).textTheme
          .apply(bodyColor: text, displayColor: text),
    );
  }
}
