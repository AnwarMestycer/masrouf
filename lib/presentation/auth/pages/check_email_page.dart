import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:masrouf/core/router/routes.dart';
import 'package:masrouf/core/theme/spacing.dart';
import 'package:masrouf/presentation/auth/controllers/auth_controller.dart';
import 'package:masrouf/presentation/auth/widgets/auth_scaffold.dart';
import 'package:masrouf/presentation/common/l10n_x.dart';
import 'package:masrouf/presentation/common/widgets/app_text_field.dart';

/// Shown after a sign-up that needs email confirmation.
///
/// The app does not poll for confirmation: opening the emailed link brings the
/// user back through the `io.masrouf://auth-callback` deep link, supabase_flutter
/// exchanges it for a session, and the router's redirect takes over. This screen
/// only has to explain that and offer a resend.
class CheckEmailPage extends ConsumerStatefulWidget {
  const CheckEmailPage({required this.email, super.key});

  final String email;

  @override
  ConsumerState<CheckEmailPage> createState() => _CheckEmailPageState();
}

class _CheckEmailPageState extends ConsumerState<CheckEmailPage> {
  bool _resent = false;

  Future<void> _resend() async {
    final ok = await ref
        .read(authControllerProvider.notifier)
        .resendConfirmation(widget.email);
    if (mounted && ok) setState(() => _resent = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final pending = ref.watch(authPendingProvider);
    final failure = ref.watch(authFailureProvider);

    return AuthScaffold(
      title: l10n.authCheckEmailTitle,
      showBack: false,
      children: <Widget>[
        FormErrorText(message: failure?.localise(l10n)),
        Icon(
          Icons.mark_email_unread_outlined,
          size: 56,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: Gap.lg),
        Text(
          l10n.authCheckEmailBody(widget.email),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: Gap.xl),
        if (_resent)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.md),
            child: Text(
              l10n.authResetSent,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        SubmitButton(
          label: l10n.authResendEmail,
          pending: pending,
          onPressed: _resend,
        ),
        const SizedBox(height: Gap.md),
        TextButton(
          onPressed: pending ? null : () => context.go(Routes.signIn),
          child: Text(l10n.authBackToSignIn),
        ),
      ],
    );
  }
}
