// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : theme_provider.dart
// Rôle          : Gestionnaire réactif Riverpod de l'état du thème (Clair / Sombre).
//                 Diffuse instantanément les modifications de mode visuel à
//                 travers l'arbre de widgets.
// Module        : Core / Thèmes & Gestion d'état
// Dépendances   : Flutter Material, flutter_riverpod
// Sécurité/RLS  : Public / UI
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider global pour le mode du thème (Clair ou Sombre).
///
/// Diffuse les changements de thème à toute l'application via Riverpod.
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

/// [ThemeModeNotifier]
///
/// Gestionnaire d'état mutable du mode de thème actuel ([ThemeMode]).
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  /// Démarre l'application par défaut en thème clair ([ThemeMode.light]).
  ThemeModeNotifier() : super(ThemeMode.light);

  // Fonction pour forcer un thème spécifique (clair, sombre ou système)
  void setThemeMode(ThemeMode mode) {
    state = mode;
  }

  // Fonction utilitaire souvent appelée depuis un bouton "switch" 
  // pour basculer facilement entre le mode sombre et le mode clair
  void toggleDarkMode(bool isDark) {
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  // Getter pratique pour vérifier si le mode sombre est actuellement actif
  bool get isDark => state == ThemeMode.dark;
}
