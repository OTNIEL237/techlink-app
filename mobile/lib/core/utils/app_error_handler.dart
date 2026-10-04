import 'dart:io';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Gestionnaire centralisé des erreurs pour l'application TechLink.
/// Transforme toute exception technique en message français, précis, concis et compréhensible.
class AppErrorHandler {
  /// Traduit et nettoie n'importe quelle erreur en français lisible.
  static String parse(dynamic error, {String defaultMessage = 'Une erreur inattendue est survenue.'}) {
    if (error == null) return defaultMessage;

    // 1. Erreurs Dio (appels HTTP / Backend / Campay)
    if (error is DioException) {
      return _parseDioException(error);
    }

    // 2. Erreurs d'authentification Supabase
    if (error is AuthException) {
      return _parseAuthException(error);
    }

    // 3. Erreurs de base de données Supabase (Postgrest)
    if (error is PostgrestException) {
      return _parsePostgrestException(error);
    }

    // 4. Erreurs de connectivité socket
    if (error is SocketException) {
      return 'Impossible de joindre le serveur. Vérifiez votre connexion Internet.';
    }

    // 5. Erreurs sous forme de chaîne ou Exception générique
    String raw = error.toString().trim();
    if (raw.startsWith('Exception: ')) {
      raw = raw.substring('Exception: '.length).trim();
    }

    // Vérifier les correspondances connues
    final translated = _translateKnownMessage(raw);
    if (translated != null) return translated;

    // Si le message est trop long ou technique (ex: contient du code HTTP / URL)
    if (raw.contains('http') || raw.contains('RequestOptions') || raw.length > 120) {
      return 'Une erreur de communication est survenue. Veuillez réessayer.';
    }

    return raw.isNotEmpty ? raw : defaultMessage;
  }

  static String _parseDioException(DioException e) {
    // A. Si le serveur a renvoyé une réponse JSON avec un message d'erreur
    if (e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map) {
        final serverError = data['error'] ?? data['message'] ?? data['msg'] ?? data['detail'];
        if (serverError != null && serverError.toString().trim().isNotEmpty) {
          final translated = _translateKnownMessage(serverError.toString().trim());
          if (translated != null) return translated;
          // Si le message serveur est court et propre, on l'affiche
          final clean = serverError.toString().trim();
          if (clean.length < 120 && !clean.contains('http')) {
            return clean;
          }
        }
      } else if (data is String && data.trim().isNotEmpty && data.length < 100) {
        final translated = _translateKnownMessage(data.trim());
        if (translated != null) return translated;
      }
    }

    // B. Selon le type de l'exception Dio
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Le serveur met trop de temps à répondre. Vérifiez votre réseau.';
      case DioExceptionType.connectionError:
        return 'Connexion au serveur impossible. Vérifiez votre accès Internet.';
      case DioExceptionType.cancel:
        return 'La requête a été annulée.';
      case DioExceptionType.badCertificate:
        return 'Erreur de sécurité lors de la connexion sécurisée.';
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        if (status != null) {
          switch (status) {
            case 400:
              return 'Informations invalides ou incomplètes. Vérifiez vos données.';
            case 401:
              return 'Session expirée. Veuillez vous reconnecter.';
            case 403:
              return 'Accès refusé. Vous n\'avez pas les permissions nécessaires.';
            case 404:
              return 'L\'élément demandé est introuvable.';
            case 408:
              return 'Délai d\'attente dépassé. Veuillez réessayer.';
            case 409:
              return 'Conflit : cette opération a déjà été effectuée.';
            case 429:
              return 'Trop de tentatives rapprochées. Veuillez patienter un instant.';
            case 500:
            case 502:
            case 503:
              return 'Le service rencontre une anomalie temporaire. Réessayez dans un instant.';
          }
        }
        return 'Une erreur est survenue lors du traitement (code ${status ?? 'inconnu'}).';
      case DioExceptionType.unknown:
      default:
        if (e.message != null && e.message!.contains('SocketException')) {
          return 'Pas de connexion Internet. Vérifiez votre réseau.';
        }
        return 'Erreur réseau inattendue. Veuillez réessayer.';
    }
  }

  static String _parseAuthException(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials') || msg.contains('invalid credentials')) {
      return 'Email ou mot de passe incorrect.';
    }
    if (msg.contains('user already registered') || msg.contains('already exists')) {
      return 'Un compte existe déjà avec cette adresse email.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Veuillez confirmer votre email avant de vous connecter.';
    }
    if (msg.contains('password should be at least')) {
      return 'Le mot de passe doit comporter au moins 6 caractères.';
    }
    if (msg.contains('rate limit')) {
      return 'Trop de tentatives de connexion. Patientez quelques minutes.';
    }
    return _translateKnownMessage(e.message) ?? e.message;
  }

  static String _parsePostgrestException(PostgrestException e) {
    if (e.code == '23505') {
      return 'Cet enregistrement existe déjà dans le système.';
    }
    if (e.code == 'PGRST116') {
      return 'Aucune donnée correspondante trouvée.';
    }
    return _translateKnownMessage(e.message) ?? 'Erreur lors de l\'enregistrement des données.';
  }

  /// Dictionnaire de traduction des messages anglais fréquents vers un français clair
  static String? _translateKnownMessage(String message) {
    final m = message.toLowerCase();

    // Campay & Paiement
    if (m.contains('campay') || m.contains('failed to obtain campay token') || m.contains('camerpay')) {
      return 'Le service Campay est expiré ou indisponible. Veuillez renouveler vos identifiants ou régler en direct.';
    }
    if (m.contains('missing required fields')) {
      return 'Informations de paiement incomplètes. Veuillez vérifier vos données.';
    }
    if (m.contains('cette mission a déjà été payée') || m.contains('already paid')) {
      return 'Cette mission a déjà été payée.';
    }
    if (m.contains('mission technician not found')) {
      return 'Coordonnées du technicien introuvables pour cette mission.';
    }
    if (m.contains('payment verification failed')) {
      return 'Échec de la vérification du paiement auprès de l\'opérateur.';
    }
    if (m.contains('failed to initialize payment')) {
      return 'Impossible d\'initialiser le paiement en ligne. Veuillez réessayer ou régler en direct.';
    }
    if (m.contains('failed to record payment')) {
      return 'Impossible d\'enregistrer le paiement en base de données.';
    }

    // Authentification
    if (m.contains('invalid login credentials')) {
      return 'Email ou mot de passe incorrect.';
    }
    if (m.contains('user already registered')) {
      return 'Un compte existe déjà avec cette adresse email.';
    }
    if (m.contains('jwt expired') || m.contains('token expired')) {
      return 'Votre session a expiré. Veuillez vous reconnecter.';
    }
    if (m.contains('not authorized') || m.contains('unauthorized')) {
      return 'Action non autorisée. Reconnectez-vous.';
    }

    // Réseau
    if (m.contains('network error') || m.contains('connection refused') || m.contains('host lookup')) {
      return 'Impossible de joindre le serveur. Vérifiez votre connexion Internet.';
    }

    return null;
  }
}
