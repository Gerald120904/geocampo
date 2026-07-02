import 'package:dio/dio.dart';

import '../auth/token_storage.dart';
import '../constants/app_constants.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient(this._tokenStorage) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiUrl,
        connectTimeout: const Duration(minutes: 5),
        receiveTimeout: const Duration(minutes: 5),
        sendTimeout: const Duration(minutes: 5),
        headers: {'Accept': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final response = error.response;
          final alreadyRetried = error.requestOptions.extra['retried'] == true;

          if (response?.statusCode != 401 ||
              alreadyRetried ||
              _isAuthEndpoint(error.requestOptions.path)) {
            handler.next(error);
            return;
          }

          final refreshed = await _refreshAccessToken();
          if (!refreshed) {
            await _tokenStorage.clearTokens();
            handler.next(error);
            return;
          }

          try {
            final token = await _tokenStorage.getAccessToken();
            final requestOptions = error.requestOptions;
            requestOptions.extra['retried'] = true;
            if (token != null && token.isNotEmpty) {
              requestOptions.headers['Authorization'] = 'Bearer $token';
            }

            final retryResponse = await _dio.fetch<dynamic>(requestOptions);
            handler.resolve(retryResponse);
          } catch (retryError) {
            await _tokenStorage.clearTokens();
            handler.next(error);
          }
        },
      ),
    );
  }

  final TokenStorage _tokenStorage;
  late final Dio _dio;

  Dio get dio => _dio;

  bool _isAuthEndpoint(String path) {
    return path.contains('/auth/login') ||
        path.contains('/auth/register') ||
        path.contains('/auth/refresh') ||
        path.contains('/auth/logout') ||
        path.contains('/auth/forgot-password') ||
        path.contains('/auth/reset-password') ||
        path.contains('/auth/verify-email') ||
        path.contains('/auth/resend-verification-code');
  }

  Future<bool> _refreshAccessToken() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final response = await Dio(
        BaseOptions(
          baseUrl: AppConstants.apiUrl,
          connectTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(minutes: 5),
          headers: {'Accept': 'application/json'},
        ),
      ).post<dynamic>('/auth/refresh', data: {'refresh_token': refreshToken});

      final data = response.data as Map<String, dynamic>;
      final accessToken = data['access_token']?.toString();
      final newRefreshToken = data['refresh_token']?.toString() ?? refreshToken;

      if (accessToken == null || accessToken.isEmpty) return false;

      await _tokenStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: newRefreshToken,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  ApiException handleError(Object error) {
    if (error is DioException) {
      final response = error.response;
      final data = response?.data;

      if (data is Map<String, dynamic>) {
        return ApiException(
          message:
              data['message']?.toString() ??
              data['detail']?.toString() ??
              'Error de servidor',
          code: data['code']?.toString(),
          statusCode: response?.statusCode,
        );
      }

      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return ApiException(
          message:
              'Tiempo de conexión agotado. Revisa tu internet o el backend.',
          statusCode: response?.statusCode,
        );
      }

      if (error.type == DioExceptionType.connectionError) {
        return ApiException(
          message: 'No se pudo conectar con el backend.',
          statusCode: response?.statusCode,
        );
      }

      return ApiException(
        message: error.message ?? 'Error desconocido',
        statusCode: response?.statusCode,
      );
    }

    return ApiException(message: error.toString());
  }
}
