import '../core/auth/token_storage.dart';
import '../core/network/api_client.dart';
import '../models/app_user.dart';

class RegisterResult {
  const RegisterResult({
    required this.message,
    required this.requiresEmailVerification,
    required this.email,
  });

  final String message;
  final bool requiresEmailVerification;
  final String email;

  factory RegisterResult.fromJson(Object? rawData) {
    final data = rawData as Map<String, dynamic>;
    return RegisterResult(
      message: data['message']?.toString() ?? 'Cuenta creada correctamente.',
      requiresEmailVerification:
          data['requires_email_verification'] as bool? ?? true,
      email: data['email']?.toString() ?? '',
    );
  }
}

class AuthResult {
  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final AppUser user;
}

class AuthService {
  AuthService(this._apiClient, this._tokenStorage);

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<AuthResult> login(String email, String password) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/auth/login',
        data: {'email': email.trim(), 'password': password},
      );

      final result = _authResultFromJson(response.data);
      await _tokenStorage.saveTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );
      return result;
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }

  Future<RegisterResult> register({
    required String companyName,
    required String companyIdentifier,
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/auth/register',
        data: {
          'company_name': companyName.trim(),
          'company_identifier': companyIdentifier.trim(),
          'name': name.trim(),
          'email': email.trim(),
          'password': password,
        },
      );
      return RegisterResult.fromJson(response.data);
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }

  Future<void> resendVerificationCode(String email) async {
    try {
      await _apiClient.dio.post<dynamic>(
        '/auth/resend-verification-code',
        data: {'email': email.trim()},
      );
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }

  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    try {
      await _apiClient.dio.post<dynamic>(
        '/auth/verify-email',
        data: {'email': email.trim(), 'code': code.trim()},
      );
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      await _apiClient.dio.post<dynamic>(
        '/auth/forgot-password',
        data: {'email': email.trim()},
      );
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      await _apiClient.dio.post<dynamic>(
        '/auth/reset-password',
        data: {
          'email': email.trim(),
          'code': code.trim(),
          'new_password': newPassword,
        },
      );
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _apiClient.dio.post<dynamic>(
        '/auth/change-password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }

  Future<AuthResult> refreshSession() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw Exception('No hay refresh token guardado.');
    }

    try {
      final response = await _apiClient.dio.post<dynamic>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final data = response.data as Map<String, dynamic>;
      final accessToken = data['access_token']?.toString() ?? '';
      final newRefreshToken = data['refresh_token']?.toString() ?? refreshToken;

      if (accessToken.isEmpty || newRefreshToken.isEmpty) {
        throw Exception(
          'La respuesta de autenticacion no trajo tokens validos.',
        );
      }

      await _tokenStorage.saveTokens(
        accessToken: accessToken,
        refreshToken: newRefreshToken,
      );

      final hasUser = data['user'] != null || data['current_user'] != null;
      final user = hasUser ? _userFromJson(data) : await me();
      return AuthResult(
        accessToken: accessToken,
        refreshToken: newRefreshToken,
        user: user,
      );
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }

  Future<AppUser> me() async {
    try {
      final response = await _apiClient.dio.get<dynamic>('/auth/me');
      return _userFromJson(response.data);
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }

  Future<AppUser> updateMe({required String name}) async {
    try {
      final response = await _apiClient.dio.patch<dynamic>(
        '/users/me',
        data: {'name': name.trim()},
      );

      return AppUser.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw _apiClient.handleError(error);
    }
  }

  Future<void> logout() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _apiClient.dio.post<dynamic>(
          '/auth/logout',
          data: {'refresh_token': refreshToken},
        );
      } catch (_) {
        // Local logout should still happen if the server is unreachable.
      }
    }
    await _tokenStorage.clearTokens();
  }

  Future<bool> hasAccessToken() async {
    final token = await _tokenStorage.getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<bool> hasRefreshToken() async {
    final token = await _tokenStorage.getRefreshToken();
    return token != null && token.isNotEmpty;
  }

  AuthResult _authResultFromJson(Object? rawData, [String? fallbackRefresh]) {
    final data = rawData as Map<String, dynamic>;
    final accessToken = data['access_token']?.toString() ?? '';
    final refreshToken =
        data['refresh_token']?.toString() ?? fallbackRefresh ?? '';

    if (accessToken.isEmpty || refreshToken.isEmpty) {
      throw Exception('La respuesta de autenticacion no trajo tokens validos.');
    }

    return AuthResult(
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: _userFromJson(data),
    );
  }

  AppUser _userFromJson(Object? rawData) {
    final data = rawData as Map<String, dynamic>;
    final userJson =
        (data['user'] ?? data['current_user'] ?? data) as Map<String, dynamic>;
    return AppUser.fromJson(userJson);
  }
}
