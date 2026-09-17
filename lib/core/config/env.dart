/// Build-time configuration, supplied via `--dart-define`.
///
/// Compile-time constants rather than a bundled `.env` asset: the anon key ends up
/// in the binary either way, but this keeps it out of the repo and lets the tree
/// shaker fold [requireEmailConfirmation] branches away entirely.
abstract final class Env {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// The project's publishable (formerly "anon") key.
  ///
  /// Both define names are accepted: Supabase renamed the key, but existing
  /// scripts and CI configs still pass SUPABASE_ANON_KEY.
  static const String supabasePublishableKey =
      bool.hasEnvironment('SUPABASE_PUBLISHABLE_KEY')
          ? String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY')
          : String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Mirrors the "Confirm email" switch in Supabase → Authentication → Providers.
  ///
  /// When the project has confirmation off, sign-up returns a live session and
  /// routing must go straight to the dashboard; when it is on, sign-up returns a
  /// user with no session and we show the check-your-inbox screen. The app cannot
  /// reliably infer which, so it is declared here.
  static const bool requireEmailConfirmation =
      bool.fromEnvironment('REQUIRE_EMAIL_CONFIRMATION', defaultValue: true);

  /// Deep link registered in the Android manifest / iOS URL types, and added to
  /// Supabase → Authentication → URL Configuration → Redirect URLs.
  static const String authRedirectUrl = String.fromEnvironment(
    'AUTH_REDIRECT_URL',
    defaultValue: 'io.masrouf://auth-callback',
  );

  static const String defaultBaseCurrency =
      String.fromEnvironment('BASE_CURRENCY', defaultValue: 'TND');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  /// Fails fast at startup rather than surfacing an opaque 401 on first request.
  static void assertConfigured() {
    if (isConfigured) return;
    throw StateError(
      'Supabase is not configured. Run with:\n'
      '  flutter run \\\n'
      '    --dart-define=SUPABASE_URL=https://<project>.supabase.co \\\n'
      '    --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable key>\n'
      'See README.md → Setup.',
    );
  }
}
