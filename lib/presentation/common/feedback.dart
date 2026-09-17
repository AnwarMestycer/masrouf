import 'package:flutter/material.dart';
import 'package:masrouf/core/error/failure.dart';
import 'package:masrouf/core/result/result.dart';
import 'package:masrouf/presentation/common/l10n_x.dart';

/// Surfacing failures the user caused or can retry.
///
/// Every write in this app went through `Result`, and almost every call site
/// then did `if (result.isOk) pop()` — so a failure did nothing at all. The
/// sheet just sat there, including for the app's primary action. One helper,
/// applied everywhere, is the difference between "the button is broken" and
/// "you are offline".
extension ResultFeedback<T> on Result<T> {
  /// Shows the failure as a snackbar and reports whether the call succeeded.
  ///
  /// Returns true on success so call sites read as
  /// `if (!result.report(context)) return;` — the guard and the error message
  /// are then impossible to separate, which is how they drifted apart before.
  ///
  /// Safe to call after an `await`: a caller that has been disposed simply gets
  /// false and shows nothing.
  bool report(BuildContext context) {
    final failure = failureOrNull;
    if (failure == null) return true;
    if (context.mounted) showFailure(context, failure);
    return false;
  }
}

/// Shows [failure] in the app's error colour, with a localised message.
///
/// Never renders `debugMessage`: those strings are Drift and PostgREST internals
/// and mean nothing to a user, which is exactly the mistake the history list
/// made by printing `error.toString()`.
void showFailure(BuildContext context, Failure failure) {
  final theme = Theme.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          failure.localise(context.l10n),
          style: TextStyle(color: theme.colorScheme.onErrorContainer),
        ),
        backgroundColor: theme.colorScheme.errorContainer,
        // Longer than the default: an error the user has to read and act on
        // deserves more than the two seconds a confirmation gets.
        duration: const Duration(seconds: 4),
      ),
    );
}

/// Shown where a real number could not be loaded.
///
/// A finance app must never substitute a plausible zero for a value it failed to
/// fetch: a confident wrong number is worse than a visible error, because the
/// user acts on it. Coercing a failed balance stream to `Money.zero` told people
/// they had nothing.
class ValueUnavailable extends StatelessWidget {
  const ValueUnavailable({this.onRetry, this.compact = false, super.key});

  final VoidCallback? onRetry;

  /// Icon only, for tight spots like a header where a sentence will not fit.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    if (compact) {
      return Tooltip(
        message: l10n.errorUnknown,
        child: Icon(
          Icons.error_outline,
          size: 20,
          color: theme.colorScheme.error,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.errorUnknown,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: Text(l10n.actionRetry)),
        ],
      ),
    );
  }
}
