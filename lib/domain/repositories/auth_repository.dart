import 'package:masrouf/core/result/result.dart';
import 'package:masrouf/domain/entities/user_settings.dart';
import 'package:meta/meta.dart';

/// What sign-up produced.
///
/// Distinguishes the two shapes Supabase returns depending on whether the project
/// requires email confirmation, so the router does not have to guess which screen
/// comes next.
enum SignUpOutcome { signedIn, confirmationRequired }

@immutable
class AuthSession {
  const AuthSession({required this.user, required this.isFresh});

  final AppUser user;

  /// True when this session came from an interactive sign-in rather than a
  /// restored token. Bootstrap uses it to decide whether to force a full pull.
  final bool isFresh;
}

abstract interface class AuthRepository {
  /// The current user, or null when signed out. Emits on sign-in, sign-out and
  /// token refresh.
  Stream<AppUser?> get authStateChanges;

  AppUser? get currentUser;

  Future<Result<SignUpOutcome>> signUp({
    required String email,
    required String password,
  });

  Future<Result<AppUser>> signIn({
    required String email,
    required String password,
  });

  Future<Result<void>> signOut();

  Future<Result<void>> sendPasswordReset(String email);

  Future<Result<void>> resendConfirmation(String email);

  /// Refreshes an expiring token. Called on app resume, where the SDK's own
  /// timer may not have fired while the process was suspended.
  Future<Result<void>> refreshSession();
}
