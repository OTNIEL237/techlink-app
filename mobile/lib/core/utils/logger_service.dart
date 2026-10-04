import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

class LoggerService {
  static void logInfo(String message, {String tag = 'INFO'}) {
    if (kDebugMode) {
      developer.log(message, name: 'TechLink.$tag');
    }
  }

  static void logWarning(String message, {String tag = 'WARNING'}) {
    if (kDebugMode) {
      developer.log('⚠️ $message', name: 'TechLink.$tag');
    }
  }

  static void logError(String message, {Object? error, StackTrace? stackTrace, String tag = 'ERROR'}) {
    if (kDebugMode) {
      developer.log(
        '🔴 $message',
        name: 'TechLink.$tag',
        error: error,
        stackTrace: stackTrace,
      );
    }
    
    // TODO: Intégrer un système de crash reporting (Sentry, Firebase Crashlytics) pour la production
    if (!kDebugMode) {
      // Sentry.captureException(error, stackTrace: stackTrace);
    }
  }

  /// Formatage lisible pour les requêtes réseau
  static void logNetworkRequest(String method, String path, {dynamic data}) {
    logInfo('[$method] $path\nDATA: $data', tag: 'NETWORK');
  }

  /// Formatage lisible pour les réponses réseau
  static void logNetworkResponse(String path, int? statusCode, {dynamic data}) {
    logInfo('[RES $statusCode] $path\nDATA: $data', tag: 'NETWORK');
  }
}
