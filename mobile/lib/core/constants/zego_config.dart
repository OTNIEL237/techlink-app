// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : zego_config.dart
// Rôle          : Paramètres d'accès et identifiants du SDK audio/vidéo ZegoCloud.
//                 Lit les variables d'environnement pour initialiser les appels.
// Module        : Core / Configuration RTC
// Dépendances   : flutter_dotenv
// Sécurité/RLS  : Sensible (identifiants d'API chargés depuis le .env)
// =============================================================================

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// [ZegoConfig]
///
/// Fournit l'AppID et l'AppSign nécessaires pour initialiser le moteur
/// de télécommunication temps réel ZegoCloud.
class ZegoConfig {
  /// Identifiant d'application ZegoCloud (converti en entier).
  static int get appId => int.parse(dotenv.env['ZEGO_APP_ID'] ?? '0');

  /// Signature de sécurité d'application ZegoCloud.
  static String get appSign => dotenv.env['ZEGO_APP_SIGN'] ?? '';
}
