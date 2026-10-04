import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider global pour le mode du thème (Clair ou Sombre)
// Utilise Riverpod (StateNotifierProvider) pour écouter et diffuser les changements 
// de thème à travers toute l'application instantanément sans avoir à utiliser setState.
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

// Classe qui gère l'état actuel du thème
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  // Par défaut, l'application démarre en thème clair (ThemeMode.light)
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
