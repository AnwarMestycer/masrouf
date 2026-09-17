import 'package:masrouf/core/config/app_config.dart';
import 'package:masrouf/data/remote/dto/remote_mappers.dart';
import 'package:masrouf/domain/enums/sync_enums.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The transport for sync. Table-agnostic by design: every synced table has the
/// same `(id, user_id, updated_at, deleted_at)` shape, so one implementation
/// serves all of them and adding a table needs no new code here.
class SyncApi {
  SyncApi(this._client);

  final SupabaseClient _client;

  /// Rows changed strictly after [since], oldest change first.
  ///
  /// Strictly-after is safe because `updated_at` comes from a server trigger, so
  /// two rows written in the same transaction share a timestamp and are returned
  /// together or not at all. The cursor is only advanced past a page that was
  /// fully committed locally.
  ///
  /// Tombstones are included deliberately — they are how a deletion on another
  /// device reaches this one.
  Future<List<Json>> pullSince(
    SyncEntity entity,
    DateTime? since, {
    int limit = AppConfig.syncPullPageSize,
    int offset = 0,
  }) async {
    var query = _client.from(entity.table).select();
    if (since != null) {
      query = query.gt('updated_at', since.toUtc().toIso8601String());
    }
    final rows = await query
        .order('updated_at')
        .range(offset, offset + limit - 1);
    return rows.cast<Json>();
  }

  /// Writes rows, letting the server's primary key resolve create-vs-update.
  ///
  /// A single request per batch rather than per row: on a first sync after a long
  /// offline stretch that is the difference between one round trip and hundreds.
  Future<void> upsertAll(SyncEntity entity, List<Json> rows) async {
    if (rows.isEmpty) return;
    await _client.from(entity.table).upsert(rows, onConflict: _conflictKey(entity));
  }

  /// Pushes a tombstone without resending the row body.
  ///
  /// A deleted row's other columns cannot have changed in any way that matters,
  /// so sending them would be wasted payload — and re-sending stale values could
  /// clobber a legitimate edit that landed on another device first.
  Future<void> markDeleted(
    SyncEntity entity,
    String id,
    DateTime deletedAt,
  ) async {
    // Settings and rates have no deleted_at column, so this would be a 400.
    // Reaching here means something enqueued a delete that should never exist.
    assert(
      entity.hasTombstones,
      '${entity.table} has no tombstone column; it cannot be soft-deleted',
    );
    if (!entity.hasTombstones) return;

    await _client.from(entity.table).update(<String, dynamic>{
      'deleted_at': deletedAt.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  /// The server clock, read via a row the user is guaranteed to own.
  ///
  /// Pull cursors must be compared against server time, not device time: a phone
  /// whose clock is ten minutes fast would otherwise set a cursor into the future
  /// and silently skip every change written in that window.
  Future<DateTime?> latestServerTimestamp(SyncEntity entity) async {
    final rows = await _client
        .from(entity.table)
        .select('updated_at')
        .order('updated_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return DateTime.parse(rows.first['updated_at'] as String).toUtc();
  }

  /// `user_settings` and `exchange_rates` are keyed by the user rather than by a
  /// surrogate id, so their upsert conflict target differs.
  static String _conflictKey(SyncEntity entity) => switch (entity) {
        SyncEntity.userSettings => 'user_id',
        SyncEntity.exchangeRates => 'user_id,currency',
        _ => 'id',
      };
}
