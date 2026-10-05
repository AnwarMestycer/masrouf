import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:masrouf/data/backup/backup_service.dart';
import 'package:masrouf/data/local/daos/kv_dao.dart';
import 'package:masrouf/presentation/providers/auth_providers.dart';
import 'package:masrouf/presentation/providers/core_providers.dart';
import 'package:masrouf/presentation/providers/data_providers.dart';

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    db: ref.watch(appDatabaseProvider),
    userId: ref.watch(currentUserIdProvider),
    base: ref.watch(baseCurrencyProvider),
  ),
);

/// Bumped after every write so the dependent providers re-read the folder.
///
/// A file system has no change stream, so the alternative is re-listing the
/// directory on every rebuild of the settings screen.
class BackupRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final backupRevisionProvider =
    NotifierProvider<BackupRevision, int>(BackupRevision.new);

final backupsProvider = FutureProvider<List<File>>((ref) {
  ref.watch(backupRevisionProvider);
  return ref.watch(backupServiceProvider).list();
});

final lastBackupAtProvider = FutureProvider<DateTime?>((ref) {
  ref.watch(backupRevisionProvider);
  return ref.watch(backupServiceProvider).lastBackupAt();
});

final autoBackupEnabledProvider = FutureProvider<bool>(
  (ref) async => ref.watch(appDatabaseProvider).kvDao.getFlag(KvDao.autoBackup),
);

/// Drives the backup tiles in settings, and the automatic backup at launch.
class BackupController {
  BackupController(this._ref);

  final Ref _ref;

  Future<void> setAutoEnabled({required bool enabled}) async {
    await _ref
        .read(appDatabaseProvider)
        .kvDao
        .setFlag(KvDao.autoBackup, value: enabled);
    _ref.invalidate(autoBackupEnabledProvider);
  }

  /// Returns the file, or null when the ledger is empty.
  Future<File?> backupNow() async {
    final file = await _ref.read(backupServiceProvider).create();
    _bump();
    return file;
  }

  /// Takes the launch backup if one is due. Failure is swallowed: a backup that
  /// cannot be written must not stop the app starting.
  Future<void> maybeAutoBackup() async {
    try {
      await _ref.read(backupServiceProvider).maybeAutoBackup();
      _bump();
    } on Object {
      // Deliberately silent — see above.
    }
  }

  Future<int> restore(File file) async {
    final count = await _ref.read(backupServiceProvider).restore(file);
    _bump();
    // Every read in the app comes from tables that were just replaced, and the
    // sync engine has a full outbox to drain.
    _ref.read(syncEngineProvider).requestSync();
    return count;
  }

  void _bump() => _ref.read(backupRevisionProvider.notifier).bump();
}

final backupControllerProvider = Provider<BackupController>(
  BackupController.new,
);
