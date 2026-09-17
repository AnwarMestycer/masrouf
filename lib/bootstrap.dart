import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masrouf/app.dart';
import 'package:masrouf/core/config/env.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/presentation/providers/core_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Starts the app.
///
/// The ordering here is what keeps cold start under the 2s budget: the database
/// is opened and the Supabase session restored *before* the first frame, so the
/// dashboard renders with real data instead of a spinner that resolves a beat
/// later. Both are local operations — neither waits on the network.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations(
    // Phone-first and one-handed: a landscape layout would need a second design
    // that nothing in v1 calls for.
    <DeviceOrientation>[DeviceOrientation.portraitUp],
  );

  if (!Env.isConfigured) {
    runApp(const ConfigErrorApp(message: _configMessage));
    return;
  }

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
    authOptions: const FlutterAuthClientOptions(
      // Persists the session in secure storage and refreshes it silently, which
      // is what makes auto-login on launch work without a round trip.
      autoRefreshToken: true,
    ),
  );

  final database = AppDatabase();

  runApp(
    ProviderScope(
      overrides: [
        // The database is opened before runApp, so the very first frame reads
        // real data rather than waiting on a FutureProvider.
        appDatabaseProvider.overrideWithValue(database),
      ],
      child: const MasroufApp(),
    ),
  );
}

const String _configMessage = '''
Supabase credentials were not supplied at build time.

flutter run \\
  --dart-define=SUPABASE_URL=https://<project>.supabase.co \\
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable key>

See README.md → Setup.''';
