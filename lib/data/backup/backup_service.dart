import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/local/daos/kv_dao.dart';
import 'package:masrouf/data/local/mappers.dart';
import 'package:masrouf/data/local/row_writer.dart';
import 'package:masrouf/data/remote/dto/remote_mappers.dart';
import 'package:masrouf/data/sync/pull_worker.dart';
import 'package:masrouf/domain/enums/sync_enums.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Encodes on a background isolate.
///
/// A year of transactions is a few hundred kilobytes of JSON, which is long
/// enough to drop frames if it runs on the UI thread — and a backup is something
/// the app does to itself at launch, so the user never asked to wait for it.
Future<String> _encodeInIsolate(Object payload) =>
    compute(jsonEncode, payload);

/// Local JSON snapshots of everything that syncs.
///
/// A second line of defence rather than a replacement for sync: Supabase is the
/// authority, but an account can be locked out, a project can be deleted, and a
/// user on a bad connection may have weeks of rows that have never left the
/// phone. A file on the device needs none of that to still be readable.
///
/// The format reuses the sync wire format verbatim — [remote_mappers] produces
/// it and [applyRemoteRows] consumes it — so a backup is exactly what the server
/// would have been sent, and the two can never disagree about what a row is.
class BackupService {
  BackupService({
    required AppDatabase db,
    required this.userId,
    required this.base,
    Directory? root,
    Future<String> Function(Object payload)? encode,
  })  : _db = db,
        _root = root,
        _encode = encode ?? _encodeInIsolate;

  final AppDatabase _db;
  final Directory? _root;
  final Future<String> Function(Object payload) _encode;
  final String userId;
  final Currency base;

  /// Bump only for a change the reader cannot absorb. Adding a table or a column
  /// does not qualify: an older file simply has no rows for it, and
  /// [applyRemoteRows] already tolerates a missing optional field.
  static const int formatVersion = 1;

  static const String directoryName = 'backups';

  /// How many files to keep.
  ///
  /// Four weekly backups is roughly a month of history — long enough to notice
  /// and undo a mistake, short enough that the files never become a storage
  /// complaint on a phone.
  static const int keepCount = 4;

  /// How stale the newest backup may get before one is taken automatically.
  static const Duration autoInterval = Duration(days: 7);

  /// Every entity in the file, in the order a restore must apply them.
  ///
  /// Reuses the pull order so foreign keys resolve: accounts and categories are
  /// written before the transactions that point at them.
  static List<SyncEntity> get entities => PullWorker.order;

  /// `<app documents>/backups`, or [_root] when a test supplies one.
  ///
  /// Application documents rather than a cache or an external directory: the
  /// backup has to survive the OS reclaiming space, and it needs no storage
  /// permission on any Android version. It is also excluded from cloud backup —
  /// `allowBackup="false"` in the manifest — so an unencrypted ledger never
  /// leaves the device except through the share sheet, at the user's request.
  Future<Directory> _directory() async {
    final root = _root ?? await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, directoryName));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  /// Writes a backup, returning the file.
  ///
  /// Returns null when there is nothing worth writing: a ledger with no
  /// transactions produces a file that restores to the same empty state the user
  /// already has, and writing it would push a real backup out of the retained
  /// four.
  Future<File?> create() async {
    final tables = <String, dynamic>{};
    var rowCount = 0;

    for (final entity in entities) {
      final rows = await _rowsFor(entity);
      tables[entity.table] = rows;
      rowCount += rows.length;
    }

    if (rowCount == 0) return null;

    final createdAt = DateTime.now();
    final payload = <String, dynamic>{
      'version': formatVersion,
      'created_at': createdAt.toUtc().toIso8601String(),
      'base_currency': base.code,
      'tables': tables,
    };

    final json = await _encode(payload);

    final dir = await _directory();
    final stamp = createdAt
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final file = File(p.join(dir.path, 'masrouf-backup-$stamp.json'));
    await file.writeAsString(json, flush: true);

    await _db.kvDao.putTimestamp(KvDao.lastBackupAt, createdAt);
    await _prune();
    return file;
  }

  /// Backups on this device, newest first.
  Future<List<File>> list() async {
    final dir = await _directory();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).endsWith('.json'))
        .toList();
    // Lexicographic on an ISO stamp is chronological, so no stat call per file.
    files.sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
    return files;
  }

  Future<File?> latest() async {
    final files = await list();
    return files.isEmpty ? null : files.first;
  }

  Future<DateTime?> lastBackupAt() =>
      _db.kvDao.getTimestamp(KvDao.lastBackupAt);

  /// Takes a backup if the switch is on, the ledger is not empty and the newest
  /// backup is older than [autoInterval]. Returns the file if one was written.
  Future<File?> maybeAutoBackup() async {
    if (!await _db.kvDao.getFlag(KvDao.autoBackup)) return null;

    final last = await lastBackupAt();
    if (last != null &&
        DateTime.now().toUtc().difference(last) < autoInterval) {
      return null;
    }
    return create();
  }

  /// Replaces local data with the contents of [file].
  ///
  /// Restore-as-truth, in three parts:
  ///
  /// 1. The synced tables are cleared and rewritten from the file, in one
  ///    transaction, so a failure part-way cannot leave a half-restored ledger.
  /// 2. Every restored row is enqueued as a push. The backup is now the user's
  ///    intent, so it has to reach the server rather than be overwritten by it
  ///    on the next pull.
  /// 3. The pull cursors are cleared, so the next sync re-reads the account from
  ///    the beginning instead of resuming from a position that described data
  ///    that no longer exists.
  ///
  /// Throws [FormatException] if the file is not a backup this version can read.
  Future<int> restore(File file) async {
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Not a Masrouf backup');
    }
    final version = decoded['version'];
    if (version is! int || version > formatVersion) {
      throw FormatException('Unsupported backup version: $version');
    }
    final tables = decoded['tables'];
    if (tables is! Map<String, dynamic>) {
      throw const FormatException('Backup has no tables');
    }

    final byEntity = <SyncEntity, List<Json>>{};
    for (final entity in entities) {
      final rows = tables[entity.table];
      if (rows is! List) continue;
      byEntity[entity] = rows
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    }

    var restored = 0;
    await _db.transaction(() async {
      await _db.clearSyncedData();
      for (final entity in entities) {
        final rows = byEntity[entity];
        if (rows == null || rows.isEmpty) continue;
        await applyRemoteRows(_db, userId, entity, rows);
        restored += rows.length;
      }
    });

    for (final entry in byEntity.entries) {
      if (entry.value.isEmpty) continue;
      await _db.syncQueueDao.enqueueAll(
        entry.key,
        entry.value.map((row) => rowKeyFor(entry.key, row)),
        SyncOp.upsert,
      );
    }

    for (final entity in entities) {
      await _db.kvDao.remove(KvDaoKeys.pullCursor(entity));
    }

    // The aggregates are derived from rows that have just been replaced
    // wholesale, so they are recomputed rather than nudged.
    await _db.transactionDao.rebuildAggregates(userId, base);
    return restored;
  }

  /// Deletes all but the newest [keepCount] files.
  Future<void> _prune() async {
    final files = await list();
    for (final file in files.skip(keepCount)) {
      try {
        await file.delete();
      } on FileSystemException catch (error) {
        // A file we cannot delete is not worth failing a successful backup over.
        debugPrint('could not prune ${file.path}: $error');
      }
    }
  }

  /// Every row for [entity], tombstones included.
  ///
  /// Deleted rows are kept deliberately: dropping them would make a restore
  /// resurrect everything the user had deleted since the row was written, which
  /// is the same failure a hard delete causes in sync.
  Future<List<Json>> _rowsFor(SyncEntity entity) async {
    switch (entity) {
      case SyncEntity.accounts:
        final rows = await (_db.select(_db.accounts)
              ..where((t) => t.userId.equals(userId)))
            .get();
        return rows
            .map((r) =>
                accountToJson(userId, r.toEntity(), deletedAt: r.deletedAt))
            .toList(growable: false);

      case SyncEntity.categories:
        final rows = await (_db.select(_db.categories)
              ..where((t) => t.userId.equals(userId)))
            .get();
        return rows
            .map((r) =>
                categoryToJson(userId, r.toEntity(), deletedAt: r.deletedAt))
            .toList(growable: false);

      case SyncEntity.transactions:
        final rows = await (_db.select(_db.transactions)
              ..where((t) => t.userId.equals(userId)))
            .get();
        return rows
            .map((r) => txnToJson(userId, r.toEntity(), deletedAt: r.deletedAt))
            .toList(growable: false);

      case SyncEntity.recurringRules:
        final rows = await (_db.select(_db.recurringRules)
              ..where((t) => t.userId.equals(userId)))
            .get();
        return rows
            .map((r) =>
                recurringToJson(userId, r.toEntity(), deletedAt: r.deletedAt))
            .toList(growable: false);

      case SyncEntity.budgets:
        final rows = await (_db.select(_db.budgets)
              ..where((t) => t.userId.equals(userId)))
            .get();
        return rows
            .map(
              (r) => budgetToJson(
                userId,
                r.toEntity(Currency.fromCode(r.currency)),
                deletedAt: r.deletedAt,
              ),
            )
            .toList(growable: false);

      case SyncEntity.plannedExpenses:
        final rows = await (_db.select(_db.plannedExpenses)
              ..where((t) => t.userId.equals(userId)))
            .get();
        return rows
            .map(
              (r) => plannedToJson(
                userId,
                r.toEntity(Currency.fromCode(r.currency)),
                deletedAt: r.deletedAt,
              ),
            )
            .toList(growable: false);

      case SyncEntity.savingsGoals:
        final rows = await (_db.select(_db.savingsGoals)
              ..where((t) => t.userId.equals(userId)))
            .get();
        return rows
            .map(
              (r) => goalToJson(
                userId,
                r.toEntity(Currency.fromCode(r.currency)),
                deletedAt: r.deletedAt,
              ),
            )
            .toList(growable: false);

      case SyncEntity.exchangeRates:
        final rows = await (_db.select(_db.exchangeRates)
              ..where((t) => t.userId.equals(userId)))
            .get();
        return rows
            .map((r) => rateToJson(userId, r.toEntity()))
            .toList(growable: false);

      case SyncEntity.userSettings:
        final rows = await (_db.select(_db.userSettingsRows)
              ..where((t) => t.userId.equals(userId)))
            .get();
        return rows
            .map((r) => settingsToJson(userId, r.toEntity()))
            .toList(growable: false);
    }
  }
}
