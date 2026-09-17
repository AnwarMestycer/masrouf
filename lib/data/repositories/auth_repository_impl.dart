import 'package:masrouf/core/config/env.dart';
import 'package:masrouf/core/error/auth_error_mapper.dart';
import 'package:masrouf/core/error/failure.dart';
import 'package:masrouf/core/result/result.dart';
import 'package:masrouf/data/remote/api/auth_api.dart';
import 'package:masrouf/domain/entities/user_settings.dart';
import 'package:masrouf/domain/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._api);

  final AuthApi _api;

  @override
  Stream<AppUser?> get authStateChanges => _api.onAuthStateChange.map(
        (state) => _toAppUser(state.session?.user),
      );

  @override
  AppUser? get currentUser => _toAppUser(_api.currentUser);

  @override
  Future<Result<SignUpOutcome>> signUp({
    required String email,
    required String password,
  }) =>
      guard(
        () async {
          final response = await _api.signUp(email: email, password: password);

          // With confirmation enabled Supabase returns a user but no session.
          // Trusting the response rather than only the build flag means the app
          // still behaves correctly if the two ever disagree.
          if (response.session != null) return SignUpOutcome.signedIn;
          if (response.user == null) {
            throw const Failure(
              FailureCode.unknown,
              debugMessage: 'Sign-up returned neither a session nor a user',
            );
          }
          return SignUpOutcome.confirmationRequired;
        },
        mapAuthError,
      );

  @override
  Future<Result<AppUser>> signIn({
    required String email,
    required String password,
  }) =>
      guard(
        () async {
          final response = await _api.signIn(email: email, password: password);
          final user = _toAppUser(response.user);
          if (user == null) {
            throw const Failure(FailureCode.invalidCredentials);
          }
          return user;
        },
        mapAuthError,
      );

  @override
  Future<Result<void>> signOut() => guard(_api.signOut, mapAuthError);

  @override
  Future<Result<void>> sendPasswordReset(String email) =>
      guard(() => _api.sendPasswordReset(email), mapAuthError);

  @override
  Future<Result<void>> resendConfirmation(String email) =>
      guard(() => _api.resendConfirmation(email), mapAuthError);

  @override
  Future<Result<void>> refreshSession() =>
      guard(_api.refreshSession, mapAuthError);

  /// Treats confirmation as satisfied when the project does not require it —
  /// otherwise a project with confirmation switched off would have every user
  /// permanently flagged unconfirmed.
  static AppUser? _toAppUser(sb.User? user) {
    if (user == null) return null;
    return AppUser(
      id: user.id,
      email: user.email ?? '',
      emailConfirmed:
          !Env.requireEmailConfirmation || user.emailConfirmedAt != null,
    );
  }
}
