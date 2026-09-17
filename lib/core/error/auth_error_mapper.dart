import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' show ClientException;
import 'package:masrouf/core/error/failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Translates whatever Supabase / the socket layer threw into a [Failure].
///
/// GoTrue's `error_code` field is the stable contract; `message` is prose that
/// changes between releases, so it is only consulted as a fallback for older
/// projects that do not send a code.
Failure mapAuthError(Object error, StackTrace stackTrace) {
  if (error is Failure) return error;

  if (error is AuthException) {
    final code = error.code?.toLowerCase();
    final message = error.message.toLowerCase();

    final mapped = switch (code) {
      'invalid_credentials' ||
      'invalid_grant' =>
        FailureCode.invalidCredentials,
      'user_already_exists' ||
      'email_exists' ||
      'phone_exists' =>
        FailureCode.emailAlreadyRegistered,
      'weak_password' => FailureCode.weakPassword,
      'email_not_confirmed' => FailureCode.emailNotConfirmed,
      'over_request_rate_limit' ||
      'over_email_send_rate_limit' =>
        FailureCode.rateLimited,
      'session_expired' ||
      'refresh_token_not_found' ||
      'refresh_token_already_used' =>
        FailureCode.sessionExpired,
      _ => null,
    };
    if (mapped != null) {
      return Failure(mapped, debugMessage: error.message, cause: error);
    }

    // Fallbacks for projects on older GoTrue builds that omit error_code.
    if (message.contains('invalid login credentials')) {
      return Failure(
        FailureCode.invalidCredentials,
        debugMessage: error.message,
        cause: error,
      );
    }
    if (message.contains('already registered') ||
        message.contains('already been registered')) {
      return Failure(
        FailureCode.emailAlreadyRegistered,
        debugMessage: error.message,
        cause: error,
      );
    }
    if (message.contains('email not confirmed')) {
      return Failure(
        FailureCode.emailNotConfirmed,
        debugMessage: error.message,
        cause: error,
      );
    }
    if (message.contains('password') && message.contains('least')) {
      return Failure(
        FailureCode.weakPassword,
        debugMessage: error.message,
        cause: error,
      );
    }
    if (error.statusCode == '429') {
      return Failure(
        FailureCode.rateLimited,
        debugMessage: error.message,
        cause: error,
      );
    }
    // GoTrue wraps a failed request in one of its own exceptions, so a socket
    // problem never reaches [mapNetworkError] and used to surface as
    // "something went wrong" — the least useful thing to tell someone whose
    // real problem is that they have no connection.
    if (error is AuthRetryableFetchException || _looksLikeTransport(error.message)) {
      return Failure(
        FailureCode.network,
        debugMessage: error.message,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    return Failure(
      FailureCode.unknown,
      debugMessage: error.message,
      cause: error,
      stackTrace: stackTrace,
    );
  }

  return mapNetworkError(error, stackTrace);
}

/// Translates PostgREST / transport errors raised by the data APIs.
Failure mapDataError(Object error, StackTrace stackTrace) {
  if (error is Failure) return error;

  if (error is PostgrestException) {
    // 23505 unique_violation is expected during sync: an upsert racing another
    // device. Treated as "already there", not as a hard failure.
    final mapped = switch (error.code) {
      'PGRST116' || '42P01' => FailureCode.notFound,
      '23505' => FailureCode.validation,
      '42501' => FailureCode.sessionExpired,
      _ => FailureCode.unknown,
    };
    return Failure(
      mapped,
      debugMessage: '${error.code}: ${error.message}',
      cause: error,
      stackTrace: stackTrace,
    );
  }

  return mapNetworkError(error, stackTrace);
}

/// Whether a message reads like a transport failure rather than a rejection.
///
/// A fallback for wrappers that flatten the cause into prose. Deliberately
/// narrow: matching too eagerly would relabel real auth errors as network ones
/// and send the user to check their wifi over a wrong password.
bool _looksLikeTransport(String message) {
  final text = message.toLowerCase();
  return text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('connection closed') ||
      text.contains('connection refused') ||
      text.contains('connection reset') ||
      text.contains('operation not permitted') ||
      text.contains('network is unreachable') ||
      text.contains('clientexception');
}

Failure mapNetworkError(Object error, StackTrace stackTrace) {
  if (error is Failure) return error;
  if (error is SocketException ||
      error is TimeoutException ||
      error is HttpException ||
      error is HandshakeException ||
      error is ClientException ||
      _looksLikeTransport(error.toString())) {
    return Failure(
      FailureCode.network,
      debugMessage: error.toString(),
      cause: error,
      stackTrace: stackTrace,
    );
  }
  return Failure(
    FailureCode.unknown,
    debugMessage: error.toString(),
    cause: error,
    stackTrace: stackTrace,
  );
}
