import 'package:masrouf/core/config/env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A thin wrapper over GoTrue.
///
/// Exists so the repository — and everything above it — never imports
/// `supabase_flutter`, which keeps the domain layer testable without a live
/// client and confines SDK upgrades to this file.
class AuthApi {
  AuthApi(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  Session? get currentSession => _auth.currentSession;
  User? get currentUser => _auth.currentUser;

  /// Emits on sign-in, sign-out, token refresh and password recovery.
  Stream<AuthState> get onAuthStateChange => _auth.onAuthStateChange;

  /// Signs up and, when the project requires confirmation, returns a user with no
  /// session — the caller uses that to decide between the dashboard and the
  /// check-your-inbox screen.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) =>
      _auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: Env.requireEmailConfirmation ? Env.authRedirectUrl : null,
      );

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) =>
      _auth.signInWithPassword(email: email.trim(), password: password);

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordReset(String email) => _auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: Env.authRedirectUrl,
      );

  /// Re-sends the confirmation mail for a signup that was never completed.
  Future<void> resendConfirmation(String email) => _auth.resend(
        type: OtpType.signup,
        email: email.trim(),
        emailRedirectTo: Env.authRedirectUrl,
      );

  Future<UserResponse> updatePassword(String newPassword) =>
      _auth.updateUser(UserAttributes(password: newPassword));

  /// Forces a refresh. supabase_flutter refreshes on its own timer; this is for
  /// the resume-from-background case, where the timer did not fire while the
  /// process was frozen.
  Future<Session?> refreshSession() async {
    if (_auth.currentSession == null) return null;
    final response = await _auth.refreshSession();
    return response.session;
  }
}
