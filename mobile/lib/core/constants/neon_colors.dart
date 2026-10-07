// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : neon_colors.dart
// Rôle          : Palette de couleurs sombres et néon pour les effets
//                 visuels futuristes, glassmorphisme et accents lumineux.
// Module        : Core / Thèmes & Design System
// Dépendances   : Flutter Material
// Sécurité/RLS  : Public / UI
// =============================================================================

import 'package:flutter/material.dart';

/// [NeonColors]
///
/// Palette graphique spécialisée pour les contrastes sombres profonds
/// et les bordures électroluminescentes (effet 3D Glassmorphism).
class NeonColors {
  // ── FONDS NOIRS ET PROFONDS ──
  /// Fond d'écran ultra-sombre (violet/noir profond).
  static const Color background = Color(0xFF0B0B0F);
  /// Teinte légèrement surélevée pour les barres latérales ou de navigation.
  static const Color sidebar = Color(0xFF101015);
  /// Teinte des cartes et conteneurs glassmorphismes.
  static const Color card = Color(0xFF16161D);
  
  // ── ACCENTS LUMINEUX NÉON ──
  /// Magenta éclatant.
  static const Color neonMagenta = Color(0xFFFF00FF);
  /// Rose néon pour les états interactifs.
  static const Color neonPink = Color(0xFFFF0080);
  /// Violet électrique.
  static const Color neonPurple = Color(0xFF8A2BE2);
  /// Cyan néon (pour les indicateurs technologiques et connectivité).
  static const Color neonCyan = Color(0xFF00E5FF);
  
  // Text
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFA0A0A0);
  
  // Gradients
  static const LinearGradient magentaGradient = LinearGradient(
    colors: [neonMagenta, neonPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFF5C33CF), neonMagenta],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Border / Glow
  static final Border glassBorder = Border.all(color: Colors.white.withOpacity(0.05), width: 1);
  static final BoxDecoration glassBox = BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(16),
    border: glassBorder,
  );
}
