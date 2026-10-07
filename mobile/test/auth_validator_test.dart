// =============================================================================
// FICHIER : auth_validator_test.dart
// RÔLE : Tests unitaires pour les fonctions de validation métier d'authentification
//         (formats d'adresses e-mail, numéros de téléphone camerounais MTN/Orange,
//         longueur minimale des mots de passe).
// MODULE : Tests / Validation Métier (Mobile Flutter)
// DÉPENDANCES : package:flutter_test/flutter_test.dart
// SÉCURITÉ / RLS : N/A (Tests unitaires sans état réseau)
// =============================================================================

import 'package:flutter_test/flutter_test.dart';

/// Utilitaires de validation pour les formulaires d'authentification TechLink.
class AuthValidators {
  /// Vérifie si l'adresse e-mail fournie respecte le format standard utilisateur@domaine.ext.
  ///
  /// [email] : La chaîne représentant l'adresse e-mail à analyser.
  /// Retourne `true` si le format est valide, `false` sinon.
  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return regex.hasMatch(email.trim());
  }

  /// Vérifie si le numéro correspond à un format valide au Cameroun (9 chiffres débutant par 6).
  ///
  /// Prend en compte les préfixes des opérateurs MTN, Orange et Camtel (65x à 69x).
  /// [phone] : La chaîne représentant le numéro de téléphone.
  /// Retourne `true` si le format camerounais est respecté, `false` sinon.
  static bool isValidCameroonPhone(String phone) {
    // Format camerounais : 9 chiffres commençant par 6 (ex: 6XXXXXXXX)
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final regex = RegExp(r'^6[5-9][0-9]{7}$');
    return regex.hasMatch(cleanPhone);
  }

  /// Vérifie que le mot de passe comporte au minimum 6 caractères de sécurité.
  ///
  /// [password] : Mot de passe saisi par l'utilisateur.
  /// Retourne `true` si la longueur est supérieure ou égale à 6 caractères.
  static bool isValidPassword(String password) {
    return password.length >= 6;
  }
}

/// Point d'entrée de la suite de tests unitaires d'authentification.
void main() {
  group('Module d\'Authentification - Tests Unitaires de Validation', () {
    
    // --- 1. VALIDATION EMAIL ---
    test('TU_01 [Email] : Doit valider un format d\'e-mail standard', () {
      expect(AuthValidators.isValidEmail('otniel.techlink@gmail.com'), isTrue);
    });

    test('TU_02 [Email] : Doit rejeter un e-mail sans symbole arobase (@)', () {
      expect(AuthValidators.isValidEmail('otnielgmail.com'), isFalse);
    });

    test('TU_03 [Email] : Doit rejeter une chaîne vide', () {
      expect(AuthValidators.isValidEmail(''), isFalse);
    });

    // --- 2. VALIDATION TÉLÉPHONE CAMEROUN (MTN / Orange) ---
    test('TU_04 [Téléphone] : Doit valider un numéro MTN/Orange valide (9 chiffres)', () {
      expect(AuthValidators.isValidCameroonPhone('670123456'), isTrue);
    });

    test('TU_05 [Téléphone] : Doit rejeter un numéro invalide (trop court ou ne commençant pas par 6)', () {
      expect(AuthValidators.isValidCameroonPhone('222123456'), isFalse);
      expect(AuthValidators.isValidCameroonPhone('67012'), isFalse);
    });

    // --- 3. VALIDATION MOT DE PASSE ---
    test('TU_06 [Mot de passe] : Doit valider un mot de passe >= 6 caractères', () {
      expect(AuthValidators.isValidPassword('TechLink2026!'), isTrue);
    });

    test('TU_07 [Mot de passe] : Doit refuser un mot de passe trop court', () {
      expect(AuthValidators.isValidPassword('123'), isFalse);
    });
  });
}
