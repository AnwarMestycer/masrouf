import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masrouf/core/error/failure.dart';
import 'package:masrouf/core/result/result.dart';
import 'package:masrouf/domain/repositories/auth_repository.dart';
import 'package:masrouf/presentation/providers/auth_providers.dart';

/// Drives the three auth screens.
///
/// State is an `AsyncValue<void>`: `loading` while a request is in flight — which
/// is what disables the submit button — and `error` carrying the [Failure] the
/// form renders inline. The success payload travels as the method's return value
/// instead of through state, because the caller needs it to decide where to
/// navigate and state would deliver it a frame later.
class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  Future<SignUpOutcome?> signUp({
    required String email,
    required String password,
  }) async =>
      _run(() => _repository.signUp(email: email, password: password));

  Future<bool> signIn({
    required String email,
    required String password,
  }) =>
      _runVoid(() => _repository.signIn(email: email, password: password));

  Future<bool> sendPasswordReset(String email) =>
      _runVoid(() => _repository.sendPasswordReset(email));

  Future<bool> resendConfirmation(String email) =>
      _runVoid(() => _repository.resendConfirmation(email));

  Future<void> signOut() async {
    state = const AsyncValue<void>.loading();
    final result = await _repository.signOut();
    state = result.fold(
      (_) => const AsyncValue<void>.data(null),
      (failure) => AsyncValue<void>.error(failure, StackTrace.current),
    );
  }

  /// Clears a stale error so a corrected form does not still show the previous
  /// message while the user types.
  void clearError() {
    if (state.hasError) state = const AsyncValue<void>.data(null);
  }

  /// Void-returning variant.
  ///
  /// Kept separate from [_run] because `T?` collapses to `void?` for a
  /// `Result<void>`, which cannot be compared against null to detect success.
  Future<bool> _runVoid(Future<Result<Object?>> Function() action) async {
    state = const AsyncValue<void>.loading();
    final result = await action();
    return result.fold(
      (_) {
        state = const AsyncValue<void>.data(null);
        return true;
      },
      (failure) {
        state = AsyncValue<void>.error(failure, StackTrace.current);
        return false;
      },
    );
  }

  Future<T?> _run<T>(Future<Result<T>> Function() action) async {
    state = const AsyncValue<void>.loading();
    final result = await action();
    return result.fold(
      (value) {
        state = const AsyncValue<void>.data(null);
        return value;
      },
      (failure) {
        state = AsyncValue<void>.error(failure, StackTrace.current);
        return null;
      },
    );
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);

/// The current failure, if the last attempt failed.
final authFailureProvider = Provider<Failure?>((ref) {
  final state = ref.watch(authControllerProvider);
  final error = state.error;
  return error is Failure ? error : null;
});

final authPendingProvider = Provider<bool>(
  (ref) => ref.watch(authControllerProvider).isLoading,
);
