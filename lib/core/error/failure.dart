import 'package:meta/meta.dart';

/// The set of failures the UI is expected to react to differently.
///
/// Deliberately small. Anything the user cannot act on differently collapses into
/// [unknown]; the detail survives in [Failure.debugMessage] for logs.
enum FailureCode {
  invalidCredentials,
  emailAlreadyRegistered,
  weakPassword,
  emailNotConfirmed,
  network,
  rateLimited,
  sessionExpired,
  notFound,
  validation,
  storage,
  unknown,
}

/// A domain-level error.
///
/// Carries a [code] rather than a message so the domain layer stays free of
/// `BuildContext` and the same failure can be rendered in three languages. The
/// human string is resolved in the presentation layer.
@immutable
class Failure implements Exception {
  const Failure(
    this.code, {
    this.debugMessage,
    this.cause,
    this.stackTrace,
  });

  const Failure.network([this.debugMessage])
      : code = FailureCode.network,
        cause = null,
        stackTrace = null;

  const Failure.unknown([this.debugMessage])
      : code = FailureCode.unknown,
        cause = null,
        stackTrace = null;

  const Failure.validation([this.debugMessage])
      : code = FailureCode.validation,
        cause = null,
        stackTrace = null;

  final FailureCode code;

  /// Never shown to the user — logs and bug reports only.
  final String? debugMessage;
  final Object? cause;
  final StackTrace? stackTrace;

  /// Whether retrying the same operation later could plausibly succeed.
  /// Drives whether the sync queue keeps an item or drops it to the dead letter.
  bool get isTransient =>
      code == FailureCode.network || code == FailureCode.rateLimited;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Failure &&
          other.code == code &&
          other.debugMessage == debugMessage);

  @override
  int get hashCode => Object.hash(code, debugMessage);

  @override
  String toString() =>
      'Failure(${code.name}${debugMessage == null ? '' : ': $debugMessage'})';
}
