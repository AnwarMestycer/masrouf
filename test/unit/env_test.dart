import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/config/env.dart';

/// Guards the build-time wiring.
///
/// [Env] reads compile-time constants, so these only mean anything when the
/// defines were actually passed:
///
///   flutter test --dart-define-from-file=masrouf.env
///
/// Without them the suite still has to pass, so the configured cases skip rather
/// than fail — a plain `flutter test` must not require secrets to be present.
void main() {
  group('Env', () {
    test('reports whether the build was configured', () {
      expect(Env.isConfigured, isA<bool>());
    });

    test('assertConfigured explains how to fix an unconfigured build', () {
      if (Env.isConfigured) return;
      expect(
        Env.assertConfigured,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('SUPABASE_URL'), contains('dart-define')),
          ),
        ),
      );
    });

    test(
      'the publishable key is present and is not a service_role key',
      () {
        // service_role JWTs carry the role in their payload; one reaching the
        // client would bypass RLS entirely, so this fails loudly if the wrong
        // key is ever pasted into the config file.
        expect(Env.supabasePublishableKey, isNotEmpty);
        expect(Env.supabasePublishableKey, isNot(startsWith('eyJ')));
        expect(Env.supabasePublishableKey, isNot(contains('service_role')));
      },
      skip: Env.isConfigured ? false : 'build not configured',
    );

    test(
      'the Supabase URL points at a project',
      () {
        expect(Env.supabaseUrl, startsWith('https://'));
        expect(Env.supabaseUrl, contains('.supabase.co'));
      },
      skip: Env.isConfigured ? false : 'build not configured',
    );

    test('the auth redirect matches the scheme registered on both platforms',
        () {
      expect(Env.authRedirectUrl, startsWith('io.masrouf://'));
    });
  });
}
