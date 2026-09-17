import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masrouf/data/repositories/auth_repository_impl.dart';
import 'package:masrouf/domain/entities/user_settings.dart';
import 'package:masrouf/domain/repositories/auth_repository.dart';
import 'package:masrouf/presentation/providers/core_providers.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(authApiProvider)),
);

/// The authenticated user, or null.
///
/// Seeded synchronously from the SDK's restored session so a returning user goes
/// straight to the dashboard on the first frame rather than through a splash —
/// the difference between a cold start that feels instant and one that blinks.
final authStateProvider = StreamProvider<AppUser?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.authStateChanges;
});

final currentUserProvider = Provider<AppUser?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return ref.watch(authStateProvider).maybeWhen(
        data: (user) => user,
        orElse: () => repository.currentUser,
      );
});

/// The signed-in user's id, for the repositories that are scoped to it.
///
/// Throws when read while signed out. That is deliberate: every screen that
/// depends on it lives behind the auth gate, so a null here is a routing bug
/// worth surfacing loudly rather than a state to handle.
final currentUserIdProvider = Provider<String>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    throw StateError('currentUserIdProvider read while signed out');
  }
  return user.id;
});

final isSignedInProvider = Provider<bool>(
  (ref) => ref.watch(currentUserProvider) != null,
);
