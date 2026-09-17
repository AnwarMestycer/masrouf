import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masrouf/core/connectivity/connectivity_service.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/remote/api/auth_api.dart';
import 'package:masrouf/data/remote/api/sync_api.dart';
import 'package:masrouf/data/sync/sync_engine.dart';
import 'package:masrouf/data/sync/sync_status.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The composition root.
///
/// Everything below the UI is constructed here, which keeps widgets free of
/// `new` calls and makes each dependency individually overridable in tests.

/// Overridden in `bootstrap()` with the instance opened at startup, so the first
/// frame never has to await a database handle.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('appDatabaseProvider must be overridden'),
);

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(supabaseClientProvider)),
);

final syncApiProvider = Provider<SyncApi>(
  (ref) => SyncApi(ref.watch(supabaseClientProvider)),
);

final connectivityServiceProvider = Provider<ConnectivityService>(
  (ref) => ConnectivityService(),
);

/// Long-lived: the engine owns timers and stream subscriptions that must survive
/// navigation, so it is disposed only when the whole container goes away.
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine(
    db: ref.watch(appDatabaseProvider),
    api: ref.watch(syncApiProvider),
    connectivity: ref.watch(connectivityServiceProvider),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

/// The sync chip's data source.
///
/// Seeded with the engine's current status so a widget mounting mid-sync shows
/// the real state instead of flashing "up to date".
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final engine = ref.watch(syncEngineProvider);
  return engine.status;
});

final connectivityProvider = StreamProvider<bool>(
  (ref) => ref.watch(connectivityServiceProvider).onStatusChange,
);
