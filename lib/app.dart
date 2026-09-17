import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masrouf/core/router/app_router.dart';
import 'package:masrouf/core/theme/app_theme.dart';
import 'package:masrouf/l10n/app_localizations.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';
import 'package:masrouf/presentation/providers/session_providers.dart';

class MasroufApp extends ConsumerWidget {
  const MasroufApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Instantiating these here starts the session lifecycle and the resume
    // watcher for the lifetime of the app, without giving either a place in the
    // widget tree where a rebuild could restart them.
    ref.watch(sessionLifecycleProvider);
    ref.watch(appLifecycleProvider);

    final settings = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Masrouf',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      // Locale comes from the user's own setting rather than the device, so the
      // choice survives across devices via sync. Arabic drives RTL through
      // Flutter's own directionality — no manual mirroring anywhere.
      locale: Locale(settings.locale),
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

/// Shown when the Supabase credentials were not supplied at build time.
///
/// A dedicated screen rather than a crash: the failure is a build configuration
/// mistake, and the fix is a command line the developer needs to be able to read.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.settings_ethernet, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Masrouf is not configured',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  message,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
