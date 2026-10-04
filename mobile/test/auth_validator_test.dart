import 'package:flutter_test/flutter_test.dart';

// Fonctions de validation métier de TechLink
class AuthValidators {
  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return regex.hasMatch(email.trim());
  }

  static bool isValidCameroonPhone(String phone) {
    // Format camerounais : 9 chiffres commençant par 6 (ex: 6XXXXXXXX)
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final regex = RegExp(r'^6[5-9][0-9]{7}$');
    return regex.hasMatch(cleanPhone);
  }

  static bool isValidPassword(String password) {
    return password.length >= 6;
  }
}

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
