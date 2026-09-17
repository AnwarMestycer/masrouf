import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Reports whether the device *might* have a route to the internet.
///
/// Deliberately advisory: a captive portal reports "connected". The sync engine
/// uses this only to decide when it is worth *attempting* a push, and still
/// treats every request as able to fail. Nothing in the UI blocks on it.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Stream<bool> get onStatusChange => _connectivity.onConnectivityChanged
      .map(_isOnline)
      .distinct();

  Future<bool> isOnline() async => _isOnline(
        await _connectivity.checkConnectivity(),
      );

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}
