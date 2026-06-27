import 'package:flutter/material.dart';

/// Design tokens for the OpenMontage Studio desktop UI.
///
/// "Open Montage" palette: a near-black base with layered panels and a single
/// indigo accent for active state and primary actions. Token values come from
/// the Open Montage design (Claude Design project); the legacy names are kept as
/// aliases onto the new palette so the whole shell recolors without churn.
class AppColors {
  AppColors._();

  // --- Open Montage palette ---
  static const Color app = Color(0xFF0E0E14); // --app
  static const Color panel1 = Color(0xFF16161E); // --p1
  static const Color panel2 = Color(0xFF1D1D27); // --p2
  static const Color panel3 = Color(0xFF26262F); // --p3
  static const Color borderSoft = Color(0xFF2A2A36); // --bd
  static const Color borderStrong = Color(0xFF3A3A48); // --bd2
  static const Color accent = Color(0xFF6366F1); // --ac (indigo)
  static const Color accent2 = Color(0xFF8B8DF3); // --ac2

  static const Color textPrimary = Color(0xFFECECF0); // --tx
  static const Color textMuted = Color(0xFF9696A8); // --mut
  static const Color textFaint = Color(0xFF646476); // --dim

  /// Semantic status colors (kept distinct from the indigo accent).
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentGreen = Color(0xFF34D399);

  // --- Legacy aliases (mapped onto the Open Montage palette) ---
  static const Color background = app;
  static const Color surface = panel1;
  static const Color surfaceHigh = panel3;
  static const Color border = borderSoft;

  /// The primary accent is now indigo. These aliases keep existing call sites
  /// working while the screens are migrated to the new token names.
  static const Color accentCyan = accent;
  static const Color accentPurple = accent2;

  static const Color statusDone = accentGreen;
  static const Color statusAwaiting = accentAmber;
  static const Color statusPending = Color(0xFF475569);
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: Colors.white,
      secondary: AppColors.accent2,
      surface: AppColors.panel1,
      onSurface: AppColors.textPrimary,
      outline: AppColors.borderSoft,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.app,
      fontFamily: 'Geist',
      dividerColor: AppColors.borderSoft,
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
          color: AppColors.panel3,
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
        textStyle: TextStyle(color: AppColors.textPrimary, fontSize: 12),
      ),
    );
  }

  /// Display/heading style — Space Grotesk in the design.
  static const TextStyle heading = TextStyle(
    fontFamily: 'Space Grotesk',
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
  );

  /// Monospace style for data-heavy labels (timings, formats, seeds). Falls
  /// back to a system monospace until the JetBrains Mono asset is bundled.
  static const TextStyle mono = TextStyle(
    fontFamily: 'JetBrains Mono',
    fontFamilyFallback: ['Menlo', 'Consolas', 'monospace'],
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
