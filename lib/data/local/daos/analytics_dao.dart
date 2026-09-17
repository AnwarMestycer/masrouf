import 'package:drift/drift.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/time/date_x.dart';
import 'package:masrouf/core/time/ym.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/data/local/mappers.dart';
import 'package:masrouf/data/local/tables/local_tables.dart';
import 'package:masrouf/data/local/tables/tables.dart';
import 'package:masrouf/domain/entities/analytics/analytics.dart';
import 'package:masrouf/domain/entities/category.dart';
import 'package:masrouf/domain/enums/txn_type.dart';

part 'analytics_dao.g.dart';

/// Every read here hits the incrementally maintained aggregate tables rather than
/// `transactions`.
///
/// That is the difference between a dashboard that costs a handful of row reads
/// and one that rescans the entire ledger on every insert. The aggregates are
/// kept current by [TransactionDao]; this DAO only shapes them.
@DriftAccessor(
  tables: <Type>[MonthlyCategoryTotals, DailyTotals, Categories, Transactions],
)
class AnalyticsDao extends DatabaseAccessor<AppDatabase>
    with _$AnalyticsDaoMixin {
  AnalyticsDao(super.db);

  /// In / out / net for a single month — at most two rows of arithmetic.
  Stream<MonthSummary> watchMonthSummary(String userId, Ym ym, Currency base) {
    final total = monthlyCategoryTotals.totalMilli.sum();
    final query = selectOnly(monthlyCategoryTotals)
      ..addColumns(<Expression<Object>>[monthlyCategoryTotals.type, total])
      ..where(
        monthlyCategoryTotals.userId.equals(userId) &
            monthlyCategoryTotals.ym.equals(ym.value),
      )
      ..groupBy(<Expression<Object>>[monthlyCategoryTotals.type]);

    return query.watch().map((rows) {
      var income = 0;
      var expense = 0;
      for (final row in rows) {
        final sum = row.read(total) ?? 0;
        if (row.read(monthlyCategoryTotals.type) == TxnType.income.wire) {
          income = sum;
        } else {
          expense = sum;
        }
      }
      return MonthSummary(
        ym: ym,
        income: Money(income, base),
        expense: Money(expense, base),
      );
    });
  }

  /// Spending by category for [ym], each slice carrying the previous month's
  /// figure so the UI can show a delta without a second round trip.
  Stream<List<CategorySlice>> watchCategorySlices(
    String userId,
    Ym ym,
    Currency base, {
    TxnType type = TxnType.expense,
  }) {
    final query = select(monthlyCategoryTotals).join(
      <Join<HasResultSet, dynamic>>[
        leftOuterJoin(
          categories,
          categories.id.equalsExp(monthlyCategoryTotals.categoryId),
        ),
      ],
    )..where(
        monthlyCategoryTotals.userId.equals(userId) &
            monthlyCategoryTotals.type.equals(type.wire) &
            monthlyCategoryTotals.ym.isIn(<int>[ym.value, ym.previous.value]),
      );

    return query.watch().map((rows) {
      final current = <String, MonthlyCategoryTotalRow>{};
      final previous = <String, int>{};
      final categoriesById = <String, Category>{};

      for (final row in rows) {
        final agg = row.readTable(monthlyCategoryTotals);
        final category = row.readTableOrNull(categories);
        if (category != null && category.deletedAt == null) {
          categoriesById[category.id] = category.toEntity();
        }
        if (agg.ym == ym.value) {
          current[agg.categoryId] = agg;
        } else {
          previous[agg.categoryId] = agg.totalMilli;
        }
      }

      final grandTotal =
          current.values.fold<int>(0, (sum, row) => sum + row.totalMilli);

      final slices = current.entries.map((entry) {
        final agg = entry.value;
        return CategorySlice(
          category: categoriesById[entry.key],
          total: Money(agg.totalMilli, base),
          txnCount: agg.txnCount,
          share: grandTotal == 0 ? 0 : agg.totalMilli / grandTotal,
          previousTotal: Money(previous[entry.key] ?? 0, base),
        );
      }).toList()
        ..sort((a, b) => b.total.milli.compareTo(a.total.milli));

      return slices;
    });
  }

  /// Cash flow across [ym], bucketed by day or week.
  ///
  /// Buckets are zero-filled so the chart has a point for every day of the month;
  /// a sparse series would make an idle week look like a gap in the data rather
  /// than a week without spending.
  Stream<List<CashflowPoint>> watchCashflow(
    String userId,
    Ym ym,
    Currency base,
    CashflowGranularity granularity,
  ) {
    final firstYmd = ym.firstDay.ymd;
    final lastYmd = ym.lastDay.ymd;

    final query = select(dailyTotals)
      ..where(
        (t) =>
            t.userId.equals(userId) &
            t.ymd.isBiggerOrEqualValue(firstYmd) &
            t.ymd.isSmallerOrEqualValue(lastYmd),
      );

    return query.watch().map((rows) {
      final incomeByDay = <int, int>{};
      final expenseByDay = <int, int>{};
      for (final row in rows) {
        final target =
            row.type == TxnType.income.wire ? incomeByDay : expenseByDay;
        target[row.ymd] = (target[row.ymd] ?? 0) + row.totalMilli;
      }

      final zero = Money.zero(base);
      final points = <CashflowPoint>[];

      if (granularity == CashflowGranularity.daily) {
        for (var day = 1; day <= ym.dayCount; day++) {
          final date = DateTime(ym.year, ym.month, day);
          points.add(
            CashflowPoint(
              start: date,
              income: Money(incomeByDay[date.ymd] ?? 0, base),
              expense: Money(expenseByDay[date.ymd] ?? 0, base),
            ),
          );
        }
        return points;
      }

      // Weekly: accumulate into Monday-anchored buckets.
      final buckets = <DateTime, List<int>>{};
      for (var day = 1; day <= ym.dayCount; day++) {
        final date = DateTime(ym.year, ym.month, day);
        final bucket = buckets.putIfAbsent(
          date.startOfWeek,
          () => <int>[0, 0],
        );
        bucket[0] += incomeByDay[date.ymd] ?? 0;
        bucket[1] += expenseByDay[date.ymd] ?? 0;
      }
      final starts = buckets.keys.toList()..sort();
      for (final start in starts) {
        final bucket = buckets[start]!;
        points.add(
          CashflowPoint(
            start: start,
            income: Money(bucket[0], base),
            expense: Money(bucket[1], base),
          ),
        );
      }
      if (points.isEmpty) {
        points.add(
          CashflowPoint(start: ym.firstDay, income: zero, expense: zero),
        );
      }
      return points;
    });
  }

  /// Income per source category across the last [monthCount] months.
  Stream<IncomeBreakdown> watchIncomeBreakdown(
    String userId,
    Ym latest,
    Currency base, {
    int monthCount = 6,
  }) {
    final months = latest.lastMonths(monthCount);
    final monthValues = months.map((m) => m.value).toList(growable: false);

    final query = select(monthlyCategoryTotals).join(
      <Join<HasResultSet, dynamic>>[
        leftOuterJoin(
          categories,
          categories.id.equalsExp(monthlyCategoryTotals.categoryId),
        ),
      ],
    )..where(
        monthlyCategoryTotals.userId.equals(userId) &
            monthlyCategoryTotals.type.equals(TxnType.income.wire) &
            monthlyCategoryTotals.ym.isIn(monthValues),
      );

    return query.watch().map((rows) {
      final monthIndex = <int, int>{
        for (var i = 0; i < months.length; i++) months[i].value: i,
      };
      final totalsByCategory = <String, List<int>>{};
      final categoriesById = <String, Category>{};

      for (final row in rows) {
        final agg = row.readTable(monthlyCategoryTotals);
        final category = row.readTableOrNull(categories);
        if (category != null && category.deletedAt == null) {
          categoriesById[category.id] = category.toEntity();
        }
        final index = monthIndex[agg.ym];
        if (index == null) continue;
        totalsByCategory
            .putIfAbsent(agg.categoryId, () => List<int>.filled(months.length, 0))
            [index] += agg.totalMilli;
      }

      final series = totalsByCategory.entries
          .map(
            (entry) => IncomeSeries(
              category: categoriesById[entry.key],
              totals: entry.value
                  .map((milli) => Money(milli, base))
                  .toList(growable: false),
            ),
          )
          .toList()
        ..sort(
          (a, b) => b.grandTotal.milli.compareTo(a.grandTotal.milli),
        );

      return IncomeBreakdown(months: months, series: series);
    });
  }

  /// Per-month totals of spend that no recurring rule generated, oldest first.
  ///
  /// Reads the ledger rather than `monthly_category_totals`, because the
  /// aggregate carries no record of which rows a rule produced. Without that
  /// split a forecast would count the rent twice — once in the historical
  /// baseline and again in the enumerated commitments.
  ///
  /// A one-shot query over a personal-sized ledger, run when the forecast
  /// screen opens rather than on every write.
  Future<Map<int, int>> spontaneousExpenseByMonth(
    String userId,
    List<Ym> months,
    Currency base,
  ) async {
    if (months.isEmpty) return const <int, int>{};

    final first = months.first.firstDay.ymd;
    final last = months.last.lastDay.ymd;

    final rows = await (select(transactions)
          ..where(
            (t) =>
                t.userId.equals(userId) &
                t.deletedAt.isNull() &
                t.type.equals(TxnType.expense.wire) &
                t.recurringRuleId.isNull() &
                t.dateYmd.isBiggerOrEqualValue(first) &
                t.dateYmd.isSmallerOrEqualValue(last),
          ))
        .get();

    final byMonth = <int, int>{for (final m in months) m.value: 0};
    for (final row in rows) {
      final ym = row.dateYmd ~/ 100;
      if (!byMonth.containsKey(ym)) continue;
      byMonth[ym] = byMonth[ym]! + row.baseMilliIn(base);
    }
    return byMonth;
  }

  /// Per-month income totals, oldest first. Recurring income is enumerated
  /// separately, so rule-generated rows are excluded here for the same reason.
  Future<Map<int, int>> spontaneousIncomeByMonth(
    String userId,
    List<Ym> months,
    Currency base,
  ) async {
    if (months.isEmpty) return const <int, int>{};

    final first = months.first.firstDay.ymd;
    final last = months.last.lastDay.ymd;

    final rows = await (select(transactions)
          ..where(
            (t) =>
                t.userId.equals(userId) &
                t.deletedAt.isNull() &
                t.type.equals(TxnType.income.wire) &
                t.recurringRuleId.isNull() &
                t.dateYmd.isBiggerOrEqualValue(first) &
                t.dateYmd.isSmallerOrEqualValue(last),
          ))
        .get();

    final byMonth = <int, int>{for (final m in months) m.value: 0};
    for (final row in rows) {
      final ym = row.dateYmd ~/ 100;
      if (!byMonth.containsKey(ym)) continue;
      byMonth[ym] = byMonth[ym]! + row.baseMilliIn(base);
    }
    return byMonth;
  }

  /// Total expense in `[from, to]`, in base currency.
  ///
  /// Reads `daily_totals`, the maintained aggregate, so a week's figure is a
  /// handful of row reads rather than a scan.
  Future<int> expenseBetween(String userId, DateTime from, DateTime to) async {
    final total = dailyTotals.totalMilli.sum();
    final row = await (selectOnly(dailyTotals)
          ..addColumns(<Expression<Object>>[total])
          ..where(
            dailyTotals.userId.equals(userId) &
                dailyTotals.type.equals(TxnType.expense.wire) &
                dailyTotals.ymd.isBiggerOrEqualValue(from.ymd) &
                dailyTotals.ymd.isSmallerOrEqualValue(to.ymd),
          ))
        .getSingle();
    return row.read(total) ?? 0;
  }

  /// Non-streaming summary, for the month-over-month comparison strip.
  Future<List<MonthSummary>> summariesFor(
    String userId,
    List<Ym> months,
    Currency base,
  ) async {
    if (months.isEmpty) return const <MonthSummary>[];
    final total = monthlyCategoryTotals.totalMilli.sum();
    final rows = await (selectOnly(monthlyCategoryTotals)
          ..addColumns(<Expression<Object>>[
            monthlyCategoryTotals.ym,
            monthlyCategoryTotals.type,
            total,
          ])
          ..where(
            monthlyCategoryTotals.userId.equals(userId) &
                monthlyCategoryTotals.ym
                    .isIn(months.map((m) => m.value).toList(growable: false)),
          )
          ..groupBy(<Expression<Object>>[
            monthlyCategoryTotals.ym,
            monthlyCategoryTotals.type,
          ]))
        .get();

    final income = <int, int>{};
    final expense = <int, int>{};
    for (final row in rows) {
      final ym = row.read(monthlyCategoryTotals.ym)!;
      final sum = row.read(total) ?? 0;
      if (row.read(monthlyCategoryTotals.type) == TxnType.income.wire) {
        income[ym] = sum;
      } else {
        expense[ym] = sum;
      }
    }

    return months
        .map(
          (m) => MonthSummary(
            ym: m,
            income: Money(income[m.value] ?? 0, base),
            expense: Money(expense[m.value] ?? 0, base),
          ),
        )
        .toList(growable: false);
  }
}
