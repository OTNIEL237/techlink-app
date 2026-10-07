// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : api_service.dart
// Rôle          : Client HTTP Dio centralisé pour communiquer avec le backend Node.js.
// Module        : Data / Services
// Dépendances   : dio, supabase_flutter, logger_service.dart, app_error_handler.dart
// Sécurité/RLS  : Injection automatique du JWT Bearer de session Supabase pour les requêtes backend.
// =============================================================================

import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/logger_service.dart';
import '../../core/utils/app_error_handler.dart';

/// Exception personnalisée pour les erreurs de communication réseau API.
///
/// Encapsule un message explicatif en français, le code de statut HTTP optionnel,
/// ainsi que l'exception racine sous-jacente.
class ApiException implements Exception {
  /// Message descriptif de l'erreur destiné à l'affichage ou au débogage.
  final String message;

  /// Code de statut HTTP retourné par le serveur (ex: 400, 401, 404, 500).
  final int? statusCode;

  /// Erreur d'origine interceptée (ex: [DioException]).
  final dynamic originalError;

  /// Crée une instance d'[ApiException].
  ApiException(this.message, {this.statusCode, this.originalError});

  @override
  String toString() => message;
}

/// Service HTTP assurant la communication entre l'application mobile et l'API backend TechLink.
///
/// Gère les en-têtes HTTP, l'authentification automatique par JWT, la journalisation des
/// requêtes/réponses, ainsi qu'une politique de reprise sur incident (retry automatique).
class ApiService {
  /// URL racine du backend TechLink hébergé sur Vercel.
  static const String _baseUrl = 'https://techlink-backend-nu.vercel.app/api';
  
  /// Instance interne du client HTTP [Dio].
  late final Dio _dio;

  /// Constructeur initialisant [Dio] avec les timeouts, en-têtes et intercepteurs de sécurité.
  ///
  /// [dio] Instance Dio optionnelle (utile pour injecter un mock lors des tests unitaires).
  ApiService({Dio? dio}) {
    _dio = dio ?? Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    // Intercepteur d'authentification et de log
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final session = Supabase.instance.client.auth.currentSession;
        // Injecte le token uniquement si on tape sur NOTRE backend
        final isOurBackend = options.path.startsWith('/') || options.path.startsWith(_baseUrl);
        if (isOurBackend && session != null && session.accessToken.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer ${session.accessToken}';
        }
        LoggerService.logNetworkRequest(options.method, options.path, data: options.data);
        return handler.next(options);
      },
      onResponse: (response, handler) {
        LoggerService.logNetworkResponse(response.requestOptions.path, response.statusCode, data: response.data);
        return handler.next(response);
      },
      onError: (DioException e, handler) async {
        LoggerService.logError(
          'Erreur API [${e.response?.statusCode}] sur ${e.requestOptions.path}',
          error: e.error,
        );

        // Implémentation d'un retry simple (1 tentative) en cas de timeout
        if (_shouldRetry(e) && (e.requestOptions.extra['retries'] ?? 0) < 1) {
          e.requestOptions.extra['retries'] = (e.requestOptions.extra['retries'] ?? 0) + 1;
          LoggerService.logWarning('Tentative de reconnexion pour ${e.requestOptions.path}...');
          try {
            final response = await _dio.fetch(e.requestOptions);
            return handler.resolve(response);
          } catch (retryError) {
            return handler.next(retryError is DioException ? retryError : e);
          }
        }
        return handler.next(e);
      },
    ));
  }

  /// Évalue si une exception [DioException] est éligible à une nouvelle tentative immédiate.
  ///
  /// Retourne vrai en cas de timeout ou d'interruption temporaire de connexion réseau.
  bool _shouldRetry(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
           e.type == DioExceptionType.sendTimeout ||
           e.type == DioExceptionType.receiveTimeout ||
           e.type == DioExceptionType.connectionError;
  }

  /// Transmet une description de panne à l'API pour analyse et pré-diagnostic par intelligence artificielle.
  ///
  /// [problem] Description textuelle du problème saisi par l'utilisateur.
  /// [photosCount] Nombre de photos jointes à la demande.
  /// Retourne la réponse JSON formatée avec catégorie suggérée et estimation du coût.
  Future<Map<String, dynamic>> analyzeProblem({
    required String problem,
    int photosCount = 0,
  }) async {
    try {
      final response = await _dio.post('/ai/analyze', data: {
        'problem': problem,
        'photos_count': photosCount,
      });
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException(AppErrorHandler.parse(e), statusCode: e.response?.statusCode, originalError: e);
    }
  }

  /// Exécute une requête HTTP POST générique vers un point de terminaison du backend.
  ///
  /// [path] Chemin relatif de la route (ex: '/missions/create').
  /// [data] Corps de la requête sous forme de map JSON.
  /// [options] Options Dio additionnelles (en-têtes spécifiques, etc.).
  /// Retourne la réponse serveur sous forme de [Map<String, dynamic>].
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> data, {Options? options}) async {
    try {
      final response = await _dio.post(path, data: data, options: options);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException(AppErrorHandler.parse(e), statusCode: e.response?.statusCode, originalError: e);
    } catch (e) {
      throw ApiException(AppErrorHandler.parse(e), originalError: e);
    }
  }

  /// Exécute une requête HTTP GET générique vers un point de terminaison du backend.
  ///
  /// [path] Chemin relatif de la route (ex: '/missions').
  /// [queryParameters] Paramètres URL de requête optionnels (?key=value).
  /// [options] Options Dio additionnelles.
  /// Retourne la réponse serveur sous forme de [Map<String, dynamic>].
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? queryParameters, Options? options}) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters, options: options);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException(AppErrorHandler.parse(e), statusCode: e.response?.statusCode, originalError: e);
    } catch (e) {
      throw ApiException(AppErrorHandler.parse(e), originalError: e);
    }
  }
}