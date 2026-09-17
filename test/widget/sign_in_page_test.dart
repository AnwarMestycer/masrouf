import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/core/error/failure.dart';
import 'package:masrouf/core/result/result.dart';
import 'package:masrouf/core/theme/app_theme.dart';
import 'package:masrouf/domain/entities/user_settings.dart';
import 'package:masrouf/domain/repositories/auth_repository.dart';
import 'package:masrouf/l10n/app_localizations.dart';
import 'package:masrouf/presentation/auth/pages/sign_in_page.dart';
import 'package:masrouf/presentation/providers/auth_providers.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.signInResult});

  /// What the next sign-in attempt returns.
  final Result<AppUser>? signInResult;
  int signInCalls = 0;

  @override
  Stream<AppUser?> get authStateChanges => const Stream<AppUser?>.empty();

  @override
  AppUser? get currentUser => null;

  @override
  Future<Result<AppUser>> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    return signInResult ??
        const Ok<AppUser>(
          AppUser(id: 'u1', email: 'a@b.com', emailConfirmed: true),
        );
  }

  @override
  Future<Result<SignUpOutcome>> signUp({
    required String email,
    required String password,
  }) async =>
      const Ok<SignUpOutcome>(SignUpOutcome.confirmationRequired);

  @override
  Future<Result<void>> signOut() async => const Ok<void>(null);

  @override
  Future<Result<void>> sendPasswordReset(String email) async =>
      const Ok<void>(null);

  @override
  Future<Result<void>> resendConfirmation(String email) async =>
      const Ok<void>(null);

  @override
  Future<Result<void>> refreshSession() async => const Ok<void>(null);
}

Widget _harness(AuthRepository repository) => ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('en'),
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          L10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SignInPage(),
      ),
    );

void main() {
  testWidgets('renders the form', (tester) async {
    await tester.pumpWidget(_harness(_FakeAuthRepository()));
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in'), findsWidgets);
  });

  testWidgets('does not call the API until the form validates',
      (tester) async {
    final repository = _FakeAuthRepository();
    await tester.pumpWidget(_harness(repository));

    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(repository.signInCalls, 0);
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('reports a malformed email without hitting the API',
      (tester) async {
    final repository = _FakeAuthRepository();
    await tester.pumpWidget(_harness(repository));

    await tester.enterText(find.byType(TextField).first, 'not-an-email');
    await tester.enterText(find.byType(TextField).last, 'longenough');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(repository.signInCalls, 0);
    expect(find.text('Enter a valid email address'), findsOneWidget);
  });

  testWidgets('enforces the eight-character minimum', (tester) async {
    final repository = _FakeAuthRepository();
    await tester.pumpWidget(_harness(repository));

    await tester.enterText(find.byType(TextField).first, 'a@b.com');
    await tester.enterText(find.byType(TextField).last, 'short');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(repository.signInCalls, 0);
    expect(
      find.text('Password must be at least 8 characters'),
      findsOneWidget,
    );
  });

  testWidgets('submits a valid form', (tester) async {
    final repository = _FakeAuthRepository();
    await tester.pumpWidget(_harness(repository));

    await tester.enterText(find.byType(TextField).first, 'a@b.com');
    await tester.enterText(find.byType(TextField).last, 'longenough');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(repository.signInCalls, 1);
  });

  testWidgets('shows a friendly message for bad credentials', (tester) async {
    final repository = _FakeAuthRepository(
      signInResult: const Err<AppUser>(Failure(FailureCode.invalidCredentials)),
    );
    await tester.pumpWidget(_harness(repository));

    await tester.enterText(find.byType(TextField).first, 'a@b.com');
    await tester.enterText(find.byType(TextField).last, 'longenough');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();

    // The raw exception must never reach the user.
    expect(find.text('Wrong email or password.'), findsOneWidget);
  });

  testWidgets('maps a network failure to its own message', (tester) async {
    final repository = _FakeAuthRepository(
      signInResult: const Err<AppUser>(Failure(FailureCode.network)),
    );
    await tester.pumpWidget(_harness(repository));

    await tester.enterText(find.byType(TextField).first, 'a@b.com');
    await tester.enterText(find.byType(TextField).last, 'longenough');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(
      find.text('No connection. Check your network and try again.'),
      findsOneWidget,
    );
  });
}
