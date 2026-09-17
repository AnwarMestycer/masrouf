import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:sqlite3/open.dart';

/// Opens an in-memory database for tests.
///
/// Tests run on the host VM, not on a device, so `sqlite3_flutter_libs` — which
/// bundles the library into the app — is not in play. The host loader wants an
/// unversioned `libsqlite3.so`, which only ships with the distro's -dev package;
/// the versioned `.so.0` is present on any machine that has sqlite at all. This
/// tries both so the suite runs without a system package install.
bool _configured = false;

void useHostSqlite() {
  if (_configured) return;
  _configured = true;

  if (!Platform.isLinux) return;

  open.overrideFor(OperatingSystem.linux, () {
    for (final candidate in const <String>[
      'libsqlite3.so',
      'libsqlite3.so.0',
      '/usr/lib64/libsqlite3.so.0',
      '/usr/lib/x86_64-linux-gnu/libsqlite3.so.0',
    ]) {
      try {
        return DynamicLibrary.open(candidate);
      } on ArgumentError {
        continue;
      }
    }
    // Last resort: the symbols may already be linked into the process.
    return DynamicLibrary.process();
  });
}

AppDatabase openTestDatabase() {
  useHostSqlite();
  return AppDatabase.forTesting(NativeDatabase.memory());
}

/// Convenience for asserting on a table's full contents.
Future<List<D>> allRows<T extends Table, D>(
  DatabaseConnectionUser db,
  ResultSetImplementation<T, D> table,
) =>
    db.select(table).get();
