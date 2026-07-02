import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/auth_service.dart';
import '../../services/service_providers.dart';
import 'auth_state.dart';

class AuthController extends Notifier<AuthState> {
  late final AuthService _authService;

  @override
  AuthState build() {
    _authService = ref.read(authServiceProvider);
    return const AuthState.checking();
  }

  Future<void> restoreSession() async {
    state = state.copyWith(status: AuthStatus.loadingSession, clearError: true);
    try {
      final hasAccessToken = await _authService.hasAccessToken();
      final hasRefreshToken = await _authService.hasRefreshToken();
      if (!hasAccessToken && !hasRefreshToken) {
        state = const AuthState.guest();
        return;
      }

      final user = hasRefreshToken
          ? (await _authService.refreshSession()).user
          : await _authService.me();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (error) {
      try {
        final result = await _authService.refreshSession();
        state = AuthState(status: AuthStatus.authenticated, user: result.user);
      } catch (refreshError) {
        await _authService.logout();
        state = AuthState(
          status: AuthStatus.error,
          error: refreshError.toString(),
        );
      }
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loadingSession, clearError: true);
    try {
      final result = await _authService.login(email, password);
      state = AuthState(status: AuthStatus.authenticated, user: result.user);
    } catch (error) {
      state = AuthState(status: AuthStatus.error, error: error.toString());
      rethrow;
    }
  }

  Future<void> register({
    required String companyName,
    required String companyIdentifier,
    required String name,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loadingSession, clearError: true);
    try {
      final result = await _authService.register(
        companyName: companyName,
        companyIdentifier: companyIdentifier,
        name: name,
        email: email,
        password: password,
      );
      state = AuthState(
        status: AuthStatus.unauthenticated,
        email: result.email.isEmpty ? email.trim() : result.email,
      );
    } catch (error) {
      state = AuthState(status: AuthStatus.error, error: error.toString());
      rethrow;
    }
  }

  Future<void> verifyEmail(String email, String code) async {
    state = state.copyWith(status: AuthStatus.loadingSession, clearError: true);
    try {
      await _authService.verifyEmail(email: email, code: code);
      state = const AuthState.guest();
    } catch (error) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        email: email,
        error: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> resendVerificationCode(String email) async {
    state = state.copyWith(status: AuthStatus.loadingSession, clearError: true);
    try {
      await _authService.resendVerificationCode(email);
      state = AuthState(status: AuthStatus.unauthenticated, email: email);
    } catch (error) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        email: email,
        error: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> forgotPassword(String email) async {
    state = state.copyWith(status: AuthStatus.loadingSession, clearError: true);
    try {
      await _authService.forgotPassword(email);
      state = const AuthState.guest();
    } catch (error) {
      state = AuthState(status: AuthStatus.error, error: error.toString());
      rethrow;
    }
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    state = state.copyWith(status: AuthStatus.loadingSession, clearError: true);
    try {
      await _authService.resetPassword(
        email: email,
        code: code,
        newPassword: newPassword,
      );
      state = const AuthState.guest();
    } catch (error) {
      state = AuthState(status: AuthStatus.error, error: error.toString());
      rethrow;
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(status: AuthStatus.savingProfile, clearError: true);
    try {
      await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      await logout();
    } catch (error) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        error: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> refreshProfile() async {
    if (state.user == null || state.isRefreshingProfile) return;

    state = state.copyWith(
      status: AuthStatus.refreshingProfile,
      clearError: true,
    );
    try {
      final user = await _authService.me();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (error) {
      state = state.copyWith(
        status: AuthStatus.authenticated,
        error: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> updateProfileName(String name) async {
    final cleanName = name.trim();

    if (cleanName.length < 2) {
      throw Exception('El nombre debe tener al menos 2 caracteres.');
    }

    final updatedUser = await _authService.updateMe(name: cleanName);

    state = state.copyWith(user: updatedUser, clearError: true);
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState.guest();
  }
}
