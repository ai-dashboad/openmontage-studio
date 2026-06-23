import 'package:flutter/material.dart';

/// Design tokens for the OpenMontage Studio desktop UI.
///
/// A deep slate base with a single bright accent used for active state and the
/// approval action, so the shell feels continuous with the videos it produces.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF0F172A);
  static const Color surface = Color(0xFF1E293B);
  static const Color surfaceHigh = Color(0xFF334155);
  static const Color border = Color(0xFF2A3A52);

  static const Color accentCyan = Color(0xFF22D3EE);
  static const Color accentPurple = Color(0xFFA78BFA);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentGreen = Color(0xFF34D399);

  static const Color textPrimary = Color(0xFFE2E8F0);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textFaint = Color(0xFF64748B);

  /// Stage / scene status colors.
  static const Color statusDone = accentGreen;
  static const Color statusAwaiting = accentAmber;
  static const Color statusPending = Color(0xFF475569);
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.accentCyan,
      onPrimary: AppColors.background,
      secondary: AppColors.accentPurple,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      outline: AppColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'SF Pro Text',
      dividerColor: AppColors.border,
      textTheme: const TextTheme(
        titleMedium: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(color: AppColors.textPrimary),
        bodySmall: TextStyle(color: AppColors.textMuted),
        labelSmall: TextStyle(color: AppColors.textFaint, letterSpacing: 0.4),
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
        textStyle: TextStyle(color: AppColors.textPrimary, fontSize: 12),
      ),
    );
  }

  /// Monospace style for data-heavy labels (timings, seeds, costs).
  static const TextStyle mono = TextStyle(
    fontFamily: 'Menlo',
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
