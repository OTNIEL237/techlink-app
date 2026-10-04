import 'package:flutter/material.dart';

/// Couleurs statiques de la marque (ne changent jamais)
class AppColors {
  // Couleurs principales (identiques en clair/sombre)
  static const Color primary = Color(0xFF7C3AED);
  static const Color primaryDark = Color(0xFF6D28D9);
  static const Color primaryLight = Color(0xFFF5F3FF);

  // Accents
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFDC2626);

  // Spécifiques
  static const Color technicianColor = Color(0xFF0891B2);
  static const Color clientColor = Color(0xFF7C3AED);
  static const Color adminColor = Color(0xFF111827);
  static const Color mtnColor = Color(0xFFFFCC00);
  static const Color orangeColor = Color(0xFFFF6600);

  // ── Mode Clair (Blanc professionnel) ──
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);

  // ── Mode Sombre (VS Code Dark Professionnel #1E1E1E) ──
  static const Color darkBackground = Color(0xFF1E1E1E);
  static const Color darkSurface = Color(0xFF252526);
  static const Color darkCard = Color(0xFF252526);
  static const Color darkBorder = Color(0xFF333333);
  static const Color darkTextPrimary = Color(0xFFE2E8F0);
  static const Color darkTextSecondary = Color(0xFF858585);
}

/// Extension de thème personnalisée — permet d'accéder aux couleurs
/// dynamiques via `Theme.of(context).extension<TechLinkColors>()!`
class TechLinkColors extends ThemeExtension<TechLinkColors> {
  final Color background;
  final Color surface;
  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color primaryLight;
  final Color searchBarFill;

  const TechLinkColors({
    required this.background,
    required this.surface,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.primaryLight,
    required this.searchBarFill,
  });

  // Mode Clair
  static const light = TechLinkColors(
    background: AppColors.background,
    surface: AppColors.surface,
    card: AppColors.surface,
    border: AppColors.border,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    primaryLight: AppColors.primaryLight,
    searchBarFill: AppColors.surface,
  );

  // Mode Sombre
  static const dark = TechLinkColors(
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    card: AppColors.darkCard,
    border: AppColors.darkBorder,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    primaryLight: Color(0xFF2D1B69),
    searchBarFill: AppColors.darkSurface,
  );

  @override
  TechLinkColors copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? primaryLight,
    Color? searchBarFill,
  }) {
    return TechLinkColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      primaryLight: primaryLight ?? this.primaryLight,
      searchBarFill: searchBarFill ?? this.searchBarFill,
    );
  }

  @override
  TechLinkColors lerp(TechLinkColors? other, double t) {
    if (other is! TechLinkColors) return this;
    return TechLinkColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      searchBarFill: Color.lerp(searchBarFill, other.searchBarFill, t)!,
    );
  }
}