import 'package:drift/drift.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/local/mappers.dart';
import 'package:masrouf/data/local/tables/tables.dart';
import 'package:masrouf/domain/entities/savings_plan.dart';

part 'savings_dao.g.dart';

/// Savings periods, and the running account between plan and reality.
///
/// Nothing here stores what is owed. It is
/// `max(0, sum(committed) - sum(saved))` over confirmed periods — derived on
/// read, so an edited period cannot leave a stale total behind.
@DriftAccessor(tables: <Type>[SavingsPeriods])
class SavingsDao extends DatabaseAccessor<AppDatabase> with _$SavingsDaoMixin {
  SavingsDao(super.db);

  /// At most one period is open at a time: two would both claim the same income
  /// and both reserve against the same balance.
  Stream<SavingsPeriod?> watchOpen(String userId) =>
      (select(savingsPeriods)
            ..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.deletedAt.isNull() &
                  t.confirmedOn.isNull(),
            )
            ..orderBy(<OrderClauseGenerator<$SavingsPeriodsTable>>[
              (t) => OrderingTerm.desc(t.startedOn),
            ])
            ..limit(1))
          .watchSingleOrNull()
          .map((row) => row?.toEntity());

  /// The day the most recent period was confirmed, or null if none has been.
  Future<DateTime?> lastConfirmedOn(String userId) async {
    final row = await (select(savingsPeriods)
          ..where(
            (t) =>
                t.userId.equals(userId) &
                t.deletedAt.isNull() &
                t.confirmedOn.isNotNull(),
          )
          ..orderBy(<OrderClauseGenerator<$SavingsPeriodsTable>>[
            (t) => OrderingTerm.desc(t.confirmedOn),
          ])
          ..limit(1))
        .getSingleOrNull();
    return row?.confirmedOn;
  }

  Future<SavingsPeriod?> openPeriod(String userId) async {
    final row = await (select(savingsPeriods)
          ..where(
            (t) =>
                t.userId.equals(userId) &
                t.deletedAt.isNull() &
                t.confirmedOn.isNull(),
          )
          ..orderBy(<OrderClauseGenerator<$SavingsPeriodsTable>>[
            (t) => OrderingTerm.desc(t.startedOn),
          ])
          ..limit(1))
        .getSingleOrNull();
    return row?.toEntity();
  }

  /// Closed periods, newest first.
  Stream<List<SavingsPeriod>> watchConfirmed(String userId) =>
      (select(savingsPeriods)
            ..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.deletedAt.isNull() &
                  t.confirmedOn.isNotNull(),
            )
            ..orderBy(<OrderClauseGenerator<$SavingsPeriodsTable>>[
              (t) => OrderingTerm.desc(t.startedOn),
            ]))
          .watch()
          .map(
            (rows) => rows.map((r) => r.toEntity()).toList(growable: false),
          );

  /// Totals across confirmed periods, which is everything [SavingsLedger]
  /// needs. Summed in SQL rather than by reading every row back.
  Stream<({Money committed, Money saved})> watchTotals(
    String userId,
    Currency base,
  ) {
    final committed = savingsPeriods.committedMilli.sum();
    final saved = savingsPeriods.savedMilli.sum();
    return (selectOnly(savingsPeriods)
          ..addColumns(<Expression<Object>>[committed, saved])
          ..where(
            savingsPeriods.userId.equals(userId) &
                savingsPeriods.deletedAt.isNull() &
                savingsPeriods.confirmedOn.isNotNull(),
          ))
        .watchSingle()
        .map(
          (row) => (
            committed: Money(row.read(committed) ?? 0, base),
            saved: Money(row.read(saved) ?? 0, base),
          ),
        );
  }

  Future<void> upsert(String userId, SavingsPeriod period) =>
      into(savingsPeriods).insert(
        SavingsPeriodsCompanion.insert(
          id: period.id,
          userId: userId,
          startedOn: period.startedOn,
          incomeMilli: Value<int>(period.income.milli),
          committedMilli: Value<int>(period.committed.milli),
          confirmedOn: Value<DateTime?>(period.confirmedOn),
          savedMilli: Value<int?>(period.saved?.milli),
          currency: period.committed.currency.code,
          createdAt: DateTime.now(),
          updatedAt: period.updatedAt,
        ),
        mode: InsertMode.insertOrReplace,
      );

  /// Soft delete, so the removal reaches the user's other devices.
  Future<void> softDelete(String id) =>
      (update(savingsPeriods)..where((t) => t.id.equals(id))).write(
        SavingsPeriodsCompanion(
          deletedAt: Value<DateTime>(DateTime.now()),
          updatedAt: Value<DateTime>(DateTime.now()),
        ),
      );
}
