import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:masrouf/core/router/routes.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/core/validation/validators.dart';
import 'package:masrouf/presentation/auth/controllers/auth_controller.dart';
import 'package:masrouf/presentation/auth/widgets/auth_scaffold.dart';
import 'package:masrouf/presentation/common/l10n_x.dart';
import 'package:masrouf/presentation/common/widgets/app_text_field.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  /// Validation errors are only shown after the first submit.
  ///
  /// Marking a field invalid while it is still being typed into is noise —
  /// every email is invalid until the "@" arrives.
  bool _submitted = false;

  ValidationError? _emailError;
  ValidationError? _passwordError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool _validate() {
    final emailError = Validators.email(_email.text);
    final passwordError = Validators.password(_password.text);
    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
    });
    return emailError == null && passwordError == null;
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (!_validate()) return;

    final signedIn = await ref.read(authControllerProvider.notifier).signIn(
          email: _email.text,
          password: _password.text,
        );
    // The router's redirect handles navigation on success; nothing to do here
    // beyond letting the failure surface in the banner.
    if (signedIn && mounted) {
      TextInput.finishAutofillContext();
    }
  }

  void _revalidate() {
    if (_submitted) _validate();
    ref.read(authControllerProvider.notifier).clearError();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pending = ref.watch(authPendingProvider);
    final failure = ref.watch(authFailureProvider);

    return AuthScaffold(
      title: l10n.authWelcomeBack,
      subtitle: l10n.appTitle,
      showBack: false,
      children: <Widget>[
        FormErrorText(message: failure?.localise(l10n)),
        AppTextField(
          controller: _email,
          label: l10n.authEmail,
          errorText: _emailError?.localise(l10n),
          keyboardType: TextInputType.emailAddress,
          autofillHints: const <String>[AutofillHints.username],
          enabled: !pending,
          autofocus: true,
          prefixIcon: Icons.alternate_email,
          onChanged: (_) => _revalidate(),
        ),
        const SizedBox(height: Gap.lg),
        PasswordField(
          controller: _password,
          label: l10n.authPassword,
          errorText: _passwordError?.localise(l10n),
          enabled: !pending,
          textInputAction: TextInputAction.done,
          autofillHints: const <String>[AutofillHints.password],
          onChanged: (_) => _revalidate(),
          onSubmitted: (_) => _submit(),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed:
                pending ? null : () => context.push(Routes.forgotPassword),
            child: Text(l10n.authForgotPassword),
          ),
        ),
        const SizedBox(height: Gap.sm),
        SubmitButton(
          label: l10n.authSignIn,
          pending: pending,
          onPressed: _submit,
        ),
        const SizedBox(height: Gap.md),
        TextButton(
          onPressed: pending ? null : () => context.push(Routes.signUp),
          child: Text(l10n.authNoAccount),
        ),
      ],
    );
  }
}
