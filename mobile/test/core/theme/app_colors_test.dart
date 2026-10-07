// =============================================================================
// FICHIER : app_colors_test.dart
// RÔLE : Tests unitaires de validation de la palette chromatique TechLink
//         (AppColors statiques, thèmes TechLinkColors clair/sombre, méthodes copyWith, lerp,
//         ratios de contraste et accessibilité WCAG).
// MODULE : Tests / Thème & Design System (Mobile Flutter)
// DÉPENDANCES : package:flutter/material.dart, package:flutter_test/flutter_test.dart, package:techlink/core/constants/app_colors.dart
// SÉCURITÉ / RLS : N/A (Tests unitaires de design tokens)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:techlink/core/constants/app_colors.dart';

/// Point d'entrée des tests unitaires de la palette de couleurs.
void main() {
  group('AppColors - Couleurs statiques', () {
    test('primary devrait être violet (#7C3AED)', () {
      expect(AppColors.primary, equals(const Color(0xFF7C3AED)));
    });

    test('success devrait être vert (#16A34A)', () {
      expect(AppColors.success, equals(const Color(0xFF16A34A)));
    });

    test('warning devrait être orange/ambre (#F59E0B)', () {
      expect(AppColors.warning, equals(const Color(0xFFF59E0B)));
    });

    test('error devrait être rouge (#DC2626)', () {
      expect(AppColors.error, equals(const Color(0xFFDC2626)));
    });

    test('les couleurs spécifiques aux rôles devraient être définies', () {
      expect(AppColors.technicianColor, isNotNull);
      expect(AppColors.clientColor, isNotNull);
      expect(AppColors.adminColor, isNotNull);
    });

    test('les couleurs Mobile Money devraient être définies', () {
      expect(AppColors.mtnColor, equals(const Color(0xFFFFCC00)));
      expect(AppColors.orangeColor, equals(const Color(0xFFFF6600)));
    });
  });

  group('TechLinkColors - Mode Clair', () {
    test('devrait avoir un fond clair', () {
      expect(TechLinkColors.light.background, equals(AppColors.background));
      expect(TechLinkColors.light.surface, equals(AppColors.surface));
    });

    test('devrait avoir du texte sombre sur fond clair', () {
      expect(TechLinkColors.light.textPrimary, equals(AppColors.textPrimary));
      expect(TechLinkColors.light.textSecondary, equals(AppColors.textSecondary));
    });

    test('le fond devrait être proche du blanc', () {
      // F9FAFB est un gris très clair
      expect(TechLinkColors.light.background.value, greaterThan(0xFFF00000));
    });
  });

  group('TechLinkColors - Mode Sombre', () {
    test('devrait avoir un fond sombre', () {
      expect(TechLinkColors.dark.background, equals(AppColors.darkBackground));
      expect(TechLinkColors.dark.surface, equals(AppColors.darkSurface));
    });

    test('devrait avoir du texte clair sur fond sombre', () {
      expect(TechLinkColors.dark.textPrimary, equals(AppColors.darkTextPrimary));
    });

    test('le fond devrait être sombre (composante rouge < 0x30)', () {
      // 0F0D1A est très sombre
      final red = (TechLinkColors.dark.background.value >> 16) & 0xFF;
      expect(red, lessThan(0x30));
    });

    test('dark.card devrait être différent de dark.background', () {
      expect(TechLinkColors.dark.card, isNot(equals(TechLinkColors.dark.background)));
    });
  });

  group('TechLinkColors - copyWith', () {
    test('devrait créer une copie avec des valeurs modifiées', () {
      const original = TechLinkColors.light;
      final modified = original.copyWith(background: Colors.red);

      expect(modified.background, equals(Colors.red));
      // Les autres champs doivent rester identiques
      expect(modified.surface, equals(original.surface));
      expect(modified.textPrimary, equals(original.textPrimary));
    });

    test('devrait garder les valeurs originales si aucun paramètre n\'est passé', () {
      const original = TechLinkColors.dark;
      final copy = original.copyWith();

      expect(copy.background, equals(original.background));
      expect(copy.surface, equals(original.surface));
      expect(copy.card, equals(original.card));
      expect(copy.border, equals(original.border));
      expect(copy.textPrimary, equals(original.textPrimary));
      expect(copy.textSecondary, equals(original.textSecondary));
      expect(copy.primaryLight, equals(original.primaryLight));
      expect(copy.searchBarFill, equals(original.searchBarFill));
    });
  });

  group('TechLinkColors - lerp', () {
    test('lerp(0) devrait retourner les couleurs d\'origine', () {
      final result = TechLinkColors.light.lerp(TechLinkColors.dark, 0);

      expect(result.background, equals(TechLinkColors.light.background));
    });

    test('lerp(1) devrait retourner les couleurs cibles', () {
      final result = TechLinkColors.light.lerp(TechLinkColors.dark, 1);

      expect(result.background, equals(TechLinkColors.dark.background));
    });

    test('lerp(0.5) devrait retourner des couleurs intermédiaires', () {
      final result = TechLinkColors.light.lerp(TechLinkColors.dark, 0.5);

      // La couleur intermédiaire ne doit être ni l'une ni l'autre
      expect(result.background, isNot(equals(TechLinkColors.light.background)));
      expect(result.background, isNot(equals(TechLinkColors.dark.background)));
    });

    test('lerp avec un type non-TechLinkColors devrait retourner this', () {
      final result = TechLinkColors.light.lerp(null, 0.5);
      expect(result.background, equals(TechLinkColors.light.background));
    });
  });

  group('Contraste et accessibilité', () {
    test('le texte primaire devrait avoir un contraste suffisant en mode clair', () {
      // textPrimary (0xFF111827) sur background (0xFFF9FAFB)
      // Vérifie que le texte est sombre (luminosité < 0.2)
      final luminance = TechLinkColors.light.textPrimary.computeLuminance();
      expect(luminance, lessThan(0.2));
    });

    test('le texte primaire devrait avoir un contraste suffisant en mode sombre', () {
      // darkTextPrimary (0xFFECECF0) sur darkBackground (0xFF0F0D1A)
      // Vérifie que le texte est clair (luminosité > 0.7)
      final luminance = TechLinkColors.dark.textPrimary.computeLuminance();
      expect(luminance, greaterThan(0.7));
    });
  });
}
