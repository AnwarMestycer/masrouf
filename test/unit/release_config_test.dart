import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:masrouf/core/error/auth_error_mapper.dart';
import 'package:masrouf/core/error/failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Two failures that only appear in a release build on a real phone, which is
/// the worst possible place to find them.
void main() {
  /// Flutter's template declares INTERNET only in the debug and profile
  /// manifests, so a release APK ships with no network access and every request
  /// fails. Nothing in the debug build or the emulator can catch this.
  group('release manifest', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml');

    test('the shipped manifest grants internet access', () {
      expect(manifest.existsSync(), isTrue);
      expect(
        manifest.readAsStringSync(),
        contains('android.permission.INTERNET'),
        reason: 'without this, a release build cannot reach Supabase at all',
      );
    });

    test('notification permissions are declared for the weekly digest', () {
      final text = manifest.readAsStringSync();
      expect(text, contains('android.permission.POST_NOTIFICATIONS'));
      expect(text, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
    });

    /// The permissions alone deliver nothing. flutter_local_notifications
    /// bundles no receivers, so without these two declared here every scheduled
    /// notification is composed, handed to AlarmManager, and then silently
    /// dropped when the alarm fires — which is exactly what the weekly summary
    /// did before they were added. Nothing logs, and it cannot be reproduced in
    /// a widget test.
    test('the receivers that deliver scheduled notifications are declared', () {
      final text = manifest.readAsStringSync();
      expect(
        text,
        contains(
          'com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver',
        ),
        reason: 'without this an alarm fires and no notification appears',
      );
      expect(
        text,
        contains(
          'com.dexterous.flutterlocalnotifications'
          '.ScheduledNotificationBootReceiver',
        ),
        reason: 'without this every pending reminder is lost on reboot',
      );
      expect(text, contains('android.intent.action.BOOT_COMPLETED'));
      expect(
        text,
        contains('android.intent.action.MY_PACKAGE_REPLACED'),
        reason: 'an app update drops pending alarms just as a reboot does',
      );
    });

    test('the unencrypted ledger stays out of cloud backup', () {
      expect(
        manifest.readAsStringSync(),
        contains('android:allowBackup="false"'),
      );
    });
  });

  /// A user with no connection was told "something went wrong", which sends
  /// them looking for a bug instead of at their wifi.
  group('transport failures read as network problems', () {
    Failure map(Object error) => mapAuthError(error, StackTrace.current);

    test('a retryable fetch failure from GoTrue is a network error', () {
      expect(
        map(AuthRetryableFetchException(message: 'Failed to fetch')).code,
        FailureCode.network,
      );
    });

    test('a socket failure described in prose is recognised', () {
      // What a missing INTERNET permission actually produces, once the SDK has
      // flattened the cause into a message.
      expect(
        map(
          AuthUnknownException(
            message: 'SocketException: Operation not permitted',
            originalError: 'transport',
          ),
        ).code,
        FailureCode.network,
      );
    });

    test('a failed DNS lookup is recognised', () {
      expect(
        map(
          AuthUnknownException(
            message: 'Failed host lookup: bgqfkixmhkjzlkdodokq.supabase.co',
            originalError: 'transport',
          ),
        ).code,
        FailureCode.network,
      );
    });

    test('bare socket and client exceptions still map', () {
      expect(
        mapNetworkError(
          const SocketException('Operation not permitted'),
          StackTrace.current,
        ).code,
        FailureCode.network,
      );
      expect(
        mapNetworkError(ClientException('Connection closed'), StackTrace.current)
            .code,
        FailureCode.network,
      );
      expect(
        mapNetworkError(TimeoutException('slow'), StackTrace.current).code,
        FailureCode.network,
      );
    });

    test('a wrong password is still a credentials error, not a network one', () {
      // The detection must stay narrow: telling someone to check their
      // connection when they mistyped their password is its own bad bug.
      expect(
        map(
          const AuthApiException(
            'Invalid login credentials',
            statusCode: '400',
            code: 'invalid_credentials',
          ),
        ).code,
        FailureCode.invalidCredentials,
      );
    });
  });
}
