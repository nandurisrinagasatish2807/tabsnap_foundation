import 'package:flutter/material.dart';

// ─── Colors ───────────────────────────────────────────────────────────────────

class AppColors {
  AppColors._();

  // Brand
  static const primary = Color(0xFF1A1A2E);
  static const accent = Color(0xFFE8633A);
  static const accentAlt = Color(0xFFFF8C5A);

  // Semantic
  static const success = Color(0xFF2ECC8F);
  static const danger = Color(0xFFE24B4A);
  static const warning = Color(0xFFEF9F27);

  // Neutrals
  static const background = Color(0xFFF8F8F6);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF1EFE8);
  static const border = Color(0xFFE0DED6);
  static const textPrimary = Color(0xFF1A1A2E);
  static const textSecondary = Color(0xFF888780);
  static const textHint = Color(0xFFB4B2A9);
}

// ─── Avatar Colors ────────────────────────────────────────────────────────────

class AvatarColors {
  AvatarColors._();

  static const _colors = [
    Color(0xFF7F77DD),
    Color(0xFF1D9E75),
    Color(0xFFD85A30),
    Color(0xFFD4537E),
    Color(0xFF378ADD),
    Color(0xFF639922),
    Color(0xFFBA7517),
    Color(0xFFE24B4A),
  ];

  static Color get(int index) => _colors[index % _colors.length];

  static Color background(int index) => get(index).withValues(alpha: 0.12);
}

// ─── Typography ───────────────────────────────────────────────────────────────

class AppTextStyles {
  AppTextStyles._();

  static const displayLarge = TextStyle(
    fontFamily: 'Fraunces',
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  static const displayMedium = TextStyle(
    fontFamily: 'Fraunces',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const titleLarge = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const titleMedium = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const titleSmall = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const bodyLarge = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const bodyMedium = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const bodySmall = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static const labelMedium = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const moneyLarge = TextStyle(
    fontFamily: 'DMSans',
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
}

// ─── Spacing ──────────────────────────────────────────────────────────────────

class AppSpacing {
  AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

// ─── Border Radius ────────────────────────────────────────────────────────────

class AppRadius {
  AppRadius._();

  static const sm = BorderRadius.all(Radius.circular(8));
  static const md = BorderRadius.all(Radius.circular(12));
  static const lg = BorderRadius.all(Radius.circular(16));
  static const xl = BorderRadius.all(Radius.circular(24));
  static const pill = BorderRadius.all(Radius.circular(100));
}

// ─── Theme ────────────────────────────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        fontFamily: 'DMSans',
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.light(
          primary: AppColors.accent,
          secondary: AppColors.primary,
          surface: AppColors.surface,
          error: AppColors.danger,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: AppTextStyles.titleMedium,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
            textStyle: AppTextStyles.titleSmall,
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            minimumSize: const Size.fromHeight(52),
            side: const BorderSide(color: AppColors.border),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
            textStyle: AppTextStyles.titleSmall,
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceAlt,
          border: OutlineInputBorder(
            borderRadius: AppRadius.md,
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.md,
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.md,
            borderSide: BorderSide(color: AppColors.accent, width: 1.5),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
        ),
      );
}
// ─── Settlement Methods ───────────────────────────────────────────────────────

class SettlementMethods {
  SettlementMethods._();

  static const all = [
    'Venmo',
    'Zelle',
    'Cash',
    'PayPal',
    'Apple Pay',
    'Other',
  ];

  static const icons = {
    'Venmo': '💸',
    'Zelle': '🏦',
    'Cash': '💵',
    'PayPal': '🅿️',
    'Apple Pay': '📱',
    'Other': '✅',
  };
}
