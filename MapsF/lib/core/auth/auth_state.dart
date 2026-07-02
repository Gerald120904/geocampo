import '../../models/app_user.dart';

enum AuthStatus {
  initial,
  unauthenticated,
  loadingSession,
  authenticated,
  refreshingProfile,
  savingProfile,
  error,
}

class AuthState {
  const AuthState({required this.status, this.user, this.email, this.error});

  const AuthState.checking()
    : status = AuthStatus.loadingSession,
      user = null,
      email = null,
      error = null;

  const AuthState.initial()
    : status = AuthStatus.initial,
      user = null,
      email = null,
      error = null;

  const AuthState.guest()
    : status = AuthStatus.unauthenticated,
      user = null,
      email = null,
      error = null;

  final AuthStatus status;
  final AppUser? user;
  final String? email;
  final String? error;

  bool get isChecking => status == AuthStatus.loadingSession;
  bool get isAuthenticated =>
      status == AuthStatus.authenticated ||
      status == AuthStatus.refreshingProfile ||
      status == AuthStatus.savingProfile;
  bool get isRefreshingProfile => status == AuthStatus.refreshingProfile;
  bool get isSavingProfile => status == AuthStatus.savingProfile;

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    String? email,
    String? error,
    bool clearUser = false,
    bool clearEmail = false,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : user ?? this.user,
      email: clearEmail ? null : email ?? this.email,
      error: clearError ? null : error ?? this.error,
    );
  }
}
