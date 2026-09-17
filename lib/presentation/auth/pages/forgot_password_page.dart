import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/core/validation/validators.dart';
import 'package:masrouf/presentation/auth/controllers/auth_controller.dart';
import 'package:masrouf/presentation/auth/widgets/auth_scaffold.dart';
import 'package:masrouf/presentation/common/l10n_x.dart';
import 'package:masrouf/presentation/common/widgets/app_text_field.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _email = TextEditingController();

  bool _submitted = false;
  bool _sent = false;
  ValidationError? _emailError;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    final error = Validators.email(_email.text);
    setState(() => _emailError = error);
    if (error != null) return;

    final ok =
        await ref.read(authControllerProvider.notifier).sendPasswordReset(
              _email.text,
            );
    if (mounted && ok) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final pending = ref.watch(authPendingProvider);
    final failure = ref.watch(authFailureProvider);

    return AuthScaffold(
      title: l10n.authResetPassword,
      subtitle: l10n.authResetIntro,
      children: <Widget>[
        FormErrorText(message: failure?.localise(l10n)),
        if (_sent)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.lg),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.mark_email_read_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    l10n.authResetSent,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        AppTextField(
          controller: _email,
          label: l10n.authEmail,
          errorText: _emailError?.localise(l10n),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const <String>[AutofillHints.username],
          enabled: !pending,
          autofocus: true,
          prefixIcon: Icons.alternate_email,
          onChanged: (_) {
            if (_submitted) {
              setState(() => _emailError = Validators.email(_email.text));
            }
            ref.read(authControllerProvider.notifier).clearError();
          },
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: Gap.xl),
        SubmitButton(
          label: l10n.authSendResetLink,
          pending: pending,
          onPressed: _submit,
        ),
        const SizedBox(height: Gap.md),
        TextButton(
          onPressed: pending ? null : () => context.pop(),
          child: Text(l10n.authBackToSignIn),
        ),
      ],
    );
  }
}
