import 'package:flutter_test/flutter_test.dart';
import 'package:masrouf/data/remote/dto/remote_mappers.dart';
import 'package:masrouf/data/sync/conflict_resolver.dart';
import 'package:masrouf/domain/enums/sync_enums.dart';

void main() {
  final earlier = DateTime.utc(2026, 8, 26, 10);
  final later = DateTime.utc(2026, 8, 26, 11);

  group('ConflictResolver', () {
    test('applies the server row when the device has never seen it', () {
      expect(
        ConflictResolver.resolve(
          serverUpdatedAt: earlier,
          localUpdatedAt: null,
          localHasPendingChange: false,
        ),
        ConflictOutcome.applyServer,
      );
    });

    test('applies the server row when it is newer', () {
      expect(
        ConflictResolver.resolve(
          serverUpdatedAt: later,
          localUpdatedAt: earlier,
          localHasPendingChange: false,
        ),
        ConflictOutcome.applyServer,
      );
    });

    test('keeps the local row when it is newer', () {
      expect(
        ConflictResolver.resolve(
          serverUpdatedAt: earlier,
          localUpdatedAt: later,
          localHasPendingChange: false,
        ),
        ConflictOutcome.keepLocal,
      );
    });

    test('treats an identical timestamp as already applied', () {
      // The common case: our own push echoing back on the next pull. Rewriting
      // it would trigger a pointless aggregate rebuild.
      expect(
        ConflictResolver.resolve(
          serverUpdatedAt: earlier,
          localUpdatedAt: earlier,
          localHasPendingChange: false,
        ),
        ConflictOutcome.keepLocal,
      );
    });

    test('never overwrites a row that is still queued to push', () {
      // The data-loss case this guard exists for: a pull landing between a local
      // edit and its push would otherwise discard the user's change and then
      // push the server's version back over it.
      expect(
        ConflictResolver.resolve(
          serverUpdatedAt: later,
          localUpdatedAt: earlier,
          localHasPendingChange: true,
        ),
        ConflictOutcome.keepLocal,
      );
    });
  });

  group('rowKeyFor', () {
    // Regression: rowKeyFor used to be a bare row['id'] lookup. Two tables have
    // no id column at all, so the cast threw and killed the entire pull the
    // first time a settings or rate row existed on the server — push kept
    // working, which made it look healthy while pull was permanently dead.
    test('uses the surrogate id for tables that have one', () {
      const row = <String, dynamic>{'id': 'row-1', 'user_id': 'user-1'};
      for (final entity in <SyncEntity>[
        SyncEntity.accounts,
        SyncEntity.categories,
        SyncEntity.transactions,
        SyncEntity.recurringRules,
      ]) {
        expect(rowKeyFor(entity, row), 'row-1', reason: entity.table);
      }
    });

    test('keys user_settings by user_id, which is its real primary key', () {
      // Note the absence of an 'id' field — this is the exact shape PostgREST
      // returns for this table.
      const row = <String, dynamic>{'user_id': 'user-1', 'base_currency': 'TND'};
      expect(rowKeyFor(SyncEntity.userSettings, row), 'user-1');
    });

    test('keys exchange_rates by currency, matching the local mirror', () {
      const row = <String, dynamic>{
        'user_id': 'user-1',
        'currency': 'EUR',
        'rate_to_base': 3.3,
      };
      // Must equal what PullWorker writes as the local row id, or the conflict
      // check compares against a row it can never find.
      expect(rowKeyFor(SyncEntity.exchangeRates, row), 'EUR');
    });

    test('every entity resolves a key without throwing', () {
      const row = <String, dynamic>{
        'id': 'row-1',
        'user_id': 'user-1',
        'currency': 'EUR',
      };
      for (final entity in SyncEntity.values) {
        expect(() => rowKeyFor(entity, row), returnsNormally, reason: entity.table);
      }
    });
  });

  group('SyncEntity.hasTombstones', () {
    test('is false exactly for the tables without a deleted_at column', () {
      expect(SyncEntity.userSettings.hasTombstones, isFalse);
      expect(SyncEntity.exchangeRates.hasTombstones, isFalse);
    });

    test('is true for the soft-deletable tables', () {
      for (final entity in <SyncEntity>[
        SyncEntity.accounts,
        SyncEntity.categories,
        SyncEntity.transactions,
        SyncEntity.recurringRules,
      ]) {
        expect(entity.hasTombstones, isTrue, reason: entity.table);
      }
    });
  });
}
