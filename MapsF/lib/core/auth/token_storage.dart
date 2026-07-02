import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  const TokenStorage();

  static const _storage = FlutterSecureStorage();
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _rememberLoginKey = 'remember_login';
  static const _rememberedEmailKey = 'remembered_email';
  static const _rememberedPasswordKey = 'remembered_password';

  static String? _memoryAccessToken;
  static String? _memoryRefreshToken;

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _memoryAccessToken = accessToken;
    _memoryRefreshToken = refreshToken;

    try {
      await Future.wait([
        _storage.write(key: _accessTokenKey, value: accessToken),
        _storage.write(key: _refreshTokenKey, value: refreshToken),
      ]).safeWebStorageTimeout();
    } catch (_) {
      // On web, FlutterSecureStorage can fail when IndexedDB/WebCrypto is
      // unavailable or corrupted. Keep the in-memory session usable.
    }
  }

  Future<String?> getAccessToken() async =>
      _memoryAccessToken ?? await _readToken(_accessTokenKey, isAccess: true);

  Future<String?> getRefreshToken() async =>
      _memoryRefreshToken ??
      await _readToken(_refreshTokenKey, isAccess: false);

  Future<void> clearTokens() async {
    _memoryAccessToken = null;
    _memoryRefreshToken = null;

    try {
      await Future.wait([
        _storage.delete(key: _accessTokenKey),
        _storage.delete(key: _refreshTokenKey),
      ]).safeWebStorageTimeout();
    } catch (_) {
      // Local session is cleared in memory even if web storage is unhealthy.
    }
  }

  Future<RememberedLogin?> getRememberedLogin() async {
    try {
      final remember = await _storage
          .read(key: _rememberLoginKey)
          .safeWebStorageTimeout();
      if (remember != 'true') return null;

      final values = await Future.wait([
        _storage.read(key: _rememberedEmailKey),
        _storage.read(key: _rememberedPasswordKey),
      ]).safeWebStorageTimeout();
      final email = values[0];
      final password = values[1];
      if (email == null ||
          email.isEmpty ||
          password == null ||
          password.isEmpty) {
        return null;
      }
      return RememberedLogin(email: email, password: password);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveRememberedLogin({
    required String email,
    required String password,
  }) async {
    try {
      await Future.wait([
        _storage.write(key: _rememberLoginKey, value: 'true'),
        _storage.write(key: _rememberedEmailKey, value: email.trim()),
        _storage.write(key: _rememberedPasswordKey, value: password),
      ]).safeWebStorageTimeout();
    } catch (_) {
      // The active session can continue even if persistent web storage fails.
    }
  }

  Future<void> clearRememberedLogin() async {
    try {
      await Future.wait([
        _storage.delete(key: _rememberLoginKey),
        _storage.delete(key: _rememberedEmailKey),
        _storage.delete(key: _rememberedPasswordKey),
      ]).safeWebStorageTimeout();
    } catch (_) {
      // Nothing else to do if web storage is unavailable.
    }
  }

  Future<String?> _readToken(String key, {required bool isAccess}) async {
    try {
      final token = await _storage.read(key: key).safeWebStorageTimeout();
      if (token == null || token.isEmpty) return null;

      if (isAccess) {
        _memoryAccessToken = token;
      } else {
        _memoryRefreshToken = token;
      }
      return token;
    } catch (_) {
      return null;
    }
  }
}

class RememberedLogin {
  const RememberedLogin({required this.email, required this.password});

  final String email;
  final String password;
}

extension _WebStorageTimeout<T> on Future<T> {
  Future<T> safeWebStorageTimeout() {
    if (!kIsWeb) return this;
    return timeout(const Duration(seconds: 2));
  }
}
