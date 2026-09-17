import 'package:drift/drift.dart';
import 'package:masrouf/core/time/date_x.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/local/mappers.dart';
import 'package:masrouf/data/local/tables/tables.dart';
import 'package:masrouf/domain/entities/recurring_rule.dart';

part 'recurring_dao.g.dart';

@DriftAccessor(tables: <Type>[RecurringRules])
class RecurringDao extends DatabaseAccessor<AppDatabase>
    with _$RecurringDaoMixin {
  RecurringDao(super.db);

  Stream<List<RecurringRule>> watchAll(String userId) => (select(recurringRules)
        ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull())
        ..orderBy(<OrderClauseGenerator<$RecurringRulesTable>>[
          (t) => OrderingTerm.asc(t.nextRunYmd),
        ]))
      .watch()
      .map((rows) => rows.map((r) => r.toEntity()).toList(growable: false));

  /// Rules whose next occurrence is on or before [asOf].
  ///
  /// Uses `<=` rather than `==` so an app that was not opened for three months
  /// still sees every rule that came due in the meantime; the materialiser then
  /// walks each one forward occurrence by occurrence.
  Future<List<RecurringRule>> due(String userId, DateTime asOf) async {
    final rows = await (select(recurringRules)
          ..where(
            (t) =>
                t.userId.equals(userId) &
                t.deletedAt.isNull() &
                t.active.equals(true) &
                t.nextRunYmd.isSmallerOrEqualValue(asOf.ymd),
          )
          ..orderBy(<OrderClauseGenerator<$RecurringRulesTable>>[
            (t) => OrderingTerm.asc(t.nextRunYmd),
          ]))
        .get();
    return rows.map((r) => r.toEntity()).toList(growable: false);
  }

  /// Rules falling between now and [horizon] — the "upcoming bills" that
  /// "safe to spend" subtracts.
  /// One-shot read of every live rule.
  ///
  /// Distinct from `watchAll` on purpose: callers that are themselves Futures
  /// must not await a stream's first event. It works in the app and deadlocks
  /// under `testWidgets`, whose fake clock only advances when the tester pumps.
  Future<List<RecurringRule>> getAll(String userId) async {
    final rows = await (select(recurringRules)
          ..where((t) => t.userId.equals(userId) & t.deletedAt.isNull()))
        .get();
    return rows.map((r) => r.toEntity()).toList(growable: false);
  }

  Future<List<RecurringRule>> upcomingBetween(
    String userId,
    DateTime from,
    DateTime horizon,
  ) async {
    final rows = await (select(recurringRules)
          ..where(
            (t) =>
                t.userId.equals(userId) &
                t.deletedAt.isNull() &
                t.active.equals(true) &
                t.nextRunYmd.isBiggerOrEqualValue(from.ymd) &
                t.nextRunYmd.isSmallerOrEqualValue(horizon.ymd),
          )
          ..orderBy(<OrderClauseGenerator<$RecurringRulesTable>>[
            (t) => OrderingTerm.asc(t.nextRunYmd),
          ]))
        .get();
    return rows.map((r) => r.toEntity()).toList(growable: false);
  }

  Future<RecurringRule?> getById(String id) async {
    final row = await (select(recurringRules)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row?.toEntity();
  }

  Future<void> upsert(String userId, RecurringRule rule) =>
      into(recurringRules).insert(
        _toCompanion(userId, rule),
        mode: InsertMode.insertOrReplace,
      );

  Future<void> upsertAll(String userId, List<RecurringRule> rules) =>
      batch((Batch b) {
        b.insertAllOnConflictUpdate(
          recurringRules,
          rules.map((r) => _toCompanion(userId, r)).toList(growable: false),
        );
      });

  /// Advances a rule's cursor after its occurrences have been materialised.
  Future<void> advance(
    String id,
    DateTime nextRun,
    DateTime lastRun,
  ) =>
      (update(recurringRules)..where((t) => t.id.equals(id))).write(
        RecurringRulesCompanion(
          nextRunYmd: Value<int>(nextRun.ymd),
          lastRunYmd: Value<int>(lastRun.ymd),
          updatedAt: Value<DateTime>(DateTime.now()),
        ),
      );

  Future<void> setActive(String id, {required bool active}) =>
      (update(recurringRules)..where((t) => t.id.equals(id))).write(
        RecurringRulesCompanion(
          active: Value<bool>(active),
          updatedAt: Value<DateTime>(DateTime.now()),
        ),
      );

  Future<void> softDelete(String id) =>
      (update(recurringRules)..where((t) => t.id.equals(id))).write(
        RecurringRulesCompanion(
          deletedAt: Value<DateTime>(DateTime.now()),
          updatedAt: Value<DateTime>(DateTime.now()),
        ),
      );

  RecurringRulesCompanion _toCompanion(String userId, RecurringRule rule) =>
      RecurringRulesCompanion.insert(
        id: rule.id,
        userId: userId,
        type: rule.type.wire,
        amountMilli: rule.amount.milli,
        currency: rule.amount.currency.code,
        categoryId: Value<String?>(rule.categoryId),
        accountId: rule.accountId,
        transferAccountId: Value<String?>(rule.transferAccountId),
        note: Value<String?>(rule.note),
        cadence: rule.cadence.wire,
        dayOfMonth: Value<int?>(rule.dayOfMonth),
        dayOfWeek: Value<int?>(rule.dayOfWeek),
        nextRunYmd: rule.nextRunDate.ymd,
        lastRunYmd: Value<int?>(rule.lastRunDate?.ymd),
        active: Value<bool>(rule.active),
        createdAt: DateTime.now(),
        updatedAt: rule.updatedAt,
      );
}
