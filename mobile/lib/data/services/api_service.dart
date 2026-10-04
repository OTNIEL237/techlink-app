import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/logger_service.dart';
import '../../core/utils/app_error_handler.dart';

/// Exception personnalisée pour l'API avec message d'erreur clair en français
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  ApiException(this.message, {this.statusCode, this.originalError});

  @override
  String toString() => message;
}

class ApiService {
  static const String _baseUrl = 'https://techlink-backend-nu.vercel.app/api';
  
  late final Dio _dio;

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

  bool _shouldRetry(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
           e.type == DioExceptionType.sendTimeout ||
           e.type == DioExceptionType.receiveTimeout ||
           e.type == DioExceptionType.connectionError;
  }


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