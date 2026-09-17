import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:masrouf/core/router/routes.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/core/validation/validators.dart';
import 'package:masrouf/domain/repositories/auth_repository.dart';
import 'package:masrouf/presentation/auth/controllers/auth_controller.dart';
import 'package:masrouf/presentation/auth/widgets/auth_scaffold.dart';
import 'package:masrouf/presentation/common/l10n_x.dart';
import 'package:masrouf/presentation/common/widgets/app_text_field.dart';

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _submitted = false;
  ValidationError? _emailError;
  ValidationError? _passwordError;
  ValidationError? _confirmError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool _validate() {
    final emailError = Validators.email(_email.text);
    final passwordError = Validators.password(_password.text);
    final confirmError =
        Validators.confirmPassword(_confirm.text, _password.text);
    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
      _confirmError = confirmError;
    });
    return emailError == null && passwordError == null && confirmError == null;
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (!_validate()) return;

    final outcome = await ref.read(authControllerProvider.notifier).signUp(
          email: _email.text,
          password: _password.text,
        );
    if (!mounted || outcome == null) return;

    TextInput.finishAutofillContext();

    // With confirmation enabled Supabase returns no session, so the router will
    // not redirect on its own — the user has to be told to go and check their
    // inbox. With it disabled, the session arrives and the redirect handles it.
    if (outcome == SignUpOutcome.confirmationRequired) {
      context.go('${Routes.checkEmail}?email=${Uri.encodeComponent(_email.text.trim())}');
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
      title: l10n.authCreateAccount,
      children: <Widget>[
        FormErrorText(message: failure?.localise(l10n)),
        AppTextField(
          controller: _email,
          label: l10n.authEmail,
          errorText: _emailError?.localise(l10n),
          keyboardType: TextInputType.emailAddress,
          autofillHints: const <String>[AutofillHints.newUsername],
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
          autofillHints: const <String>[AutofillHints.newPassword],
          onChanged: (_) => _revalidate(),
        ),
        const SizedBox(height: Gap.lg),
        PasswordField(
          controller: _confirm,
          label: l10n.authConfirmPassword,
          errorText: _confirmError?.localise(l10n),
          enabled: !pending,
          textInputAction: TextInputAction.done,
          autofillHints: const <String>[AutofillHints.newPassword],
          onChanged: (_) => _revalidate(),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: Gap.xl),
        SubmitButton(
          label: l10n.authSignUp,
          pending: pending,
          onPressed: _submit,
        ),
        const SizedBox(height: Gap.md),
        TextButton(
          onPressed: pending ? null : () => context.pop(),
          child: Text(l10n.authHaveAccount),
        ),
      ],
    );
  }
}
