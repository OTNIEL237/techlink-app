import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:techlink/data/services/api_service.dart';

// Création des Mocks
class MockDio extends Mock implements Dio {}
class MockHttpClientAdapter extends Mock implements HttpClientAdapter {}

void main() {
  late ApiService apiService;
  late MockDio mockDio;

  setUp(() {
    mockDio = MockDio();
    
    // Configurer le mock pour retourner un InterceptorsWrapper vide par défaut
    // pour éviter les erreurs d'initialisation dans ApiService
    when(() => mockDio.interceptors).thenReturn(Interceptors());
    when(() => mockDio.options).thenReturn(BaseOptions());
    
    apiService = ApiService(dio: mockDio);
  });

  group('ApiService Tests', () {
    test('devrait effectuer une requête POST et retourner les données', () async {
      final mockResponseData = {'success': true, 'data': 'test_data'};
      final mockResponse = Response(
        data: mockResponseData,
        statusCode: 200,
        requestOptions: RequestOptions(path: '/test/path'),
      );

      // Configuration du comportement du mock pour la méthode post
      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => mockResponse);

      final result = await apiService.post('/test/path', {'key': 'value'});

      expect(result, equals(mockResponseData));
      
      // Vérifie que Dio a bien été appelé avec les bons paramètres
      verify(() => mockDio.post(
            '/test/path',
            data: {'key': 'value'},
            options: any(named: 'options'),
          )).called(1);
    });

    test('devrait effectuer une requête GET et retourner les données', () async {
      final mockResponseData = {'success': true, 'items': []};
      final mockResponse = Response(
        data: mockResponseData,
        statusCode: 200,
        requestOptions: RequestOptions(path: '/test/get'),
      );

      when(() => mockDio.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => mockResponse);

      final result = await apiService.get('/test/get', queryParameters: {'q': 'test'});

      expect(result, equals(mockResponseData));
      
      verify(() => mockDio.get(
            '/test/get',
            queryParameters: {'q': 'test'},
            options: any(named: 'options'),
          )).called(1);
    });

    test('devrait propager l\'exception ApiException si la requête échoue', () async {
      final mockError = DioException(
        requestOptions: RequestOptions(path: '/test/error'),
        type: DioExceptionType.badResponse,
        response: Response(
          statusCode: 500,
          requestOptions: RequestOptions(path: '/test/error'),
        ),
      );

      when(() => mockDio.post(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenThrow(mockError);

      expect(
        () => apiService.post('/test/error', {}),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
