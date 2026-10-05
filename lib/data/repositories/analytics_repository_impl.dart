import 'package:masrouf/core/error/auth_error_mapper.dart';
import 'package:masrouf/core/config/app_config.dart';
import 'package:masrouf/domain/entities/analytics/cashflow_calendar.dart';
import 'package:masrouf/domain/entities/analytics/forecast.dart';
import 'package:masrouf/core/money/currency.dart';
import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/result/result.dart';
import 'package:masrouf/core/time/date_x.dart';
import 'package:masrouf/core/time/ym.dart';
import 'package:masrouf/data/local/app_database.dart';
import 'package:masrouf/domain/entities/analytics/analytics.dart';
import 'package:masrouf/domain/entities/analytics/date_range.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:masrouf/domain/repositories/repositories.dart';

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  AnalyticsRepositoryImpl({
    required AppDatabase db,
    required RecurringRepository recurring,
    required PlannedRepository planned,
    required this.userId,
    required this.base,
    required this.paydayDayOfMonth,
    required this.ratesToBase,
  })  : _db = db,
        _recurring = recurring,
        _planned = planned;

  final AppDatabase _db;
  final RecurringRepository _recurring;
  final PlannedRepository _planned;
  final String userId;
  final Currency base;
  final int paydayDayOfMonth;
  final Map<String, double> ratesToBase;

  @override
  Stream<MonthSummary> watchMonthSummary(Ym ym) =>
      _db.analyticsDao.watchMonthSummary(userId, ym, base);

  @override
  Stream<List<CategorySlice>> watchCategorySlices(
    Ym ym, {
    TxnType type = TxnType.expense,
  }) =>
      _db.analyticsDao.watchCategorySlices(userId, ym, base, type: type);

  @override
  Stream<List<CashflowPoint>> watchCashflow(
    DateRange range,
    CashflowGranularity granularity,
  ) =>
      _db.analyticsDao.watchCashflow(userId, range, base, granularity);

  @override
  Stream<IncomeBreakdown> watchIncomeBreakdown(Ym latest, {int monthCount = 6}) =>
      _db.analyticsDao
          .watchIncomeBreakdown(userId, latest, base, monthCount: monthCount);

  @override
  Future<List<MonthSummary>> summaries(List<Ym> months) =>
      _db.analyticsDao.summariesFor(userId, months, base);

  /// Current balance minus every known bill falling before the next payday.
  ///
  /// The horizon is the next occurrence of the user's payday, clamped onto a real
  /// calendar day — a payday on the 31st still resolves in February. Only
  /// outflows are subtracted; expected income is deliberately ignored so the
  /// figure answers "what can I spend from what I actually have".
  @override
  Future<SafeToSpend> safeToSpend() async {
    final horizon = _nextPayday(DateTime.now().dateOnly);
    final bills = await _recurring.upcomingBefore(horizon);
    // Plans are reserved on the same footing as bills: both are money already
    // committed but not yet spent. The only difference is that one repeats and
    // the other was promised once.
    final plans = await _planned.pendingBefore(horizon);

    final balances =
        await _db.accountDao.watchWithBalances(userId).first;

    var totalMilli = 0;
    for (final entry in balances) {
      final code = entry.account.currency.code;
      final rate = code == base.code ? 1.0 : (ratesToBase[code] ?? 0.0);
      totalMilli += (entry.balance.milli * rate).round();
    }
    final balance = Money(totalMilli, base);

    int inBase(Money amount) => amount.currency == base
        ? amount.milli
        : (amount.milli * (ratesToBase[amount.currency.code] ?? 0)).round();

    final committed = bills.fold<int>(0, (sum, b) => sum + inBase(b.amount));
    final reserved = plans.fold<int>(0, (sum, p) => sum + inBase(p.amount));

    return SafeToSpend(
      amount: Money(balance.milli - committed - reserved, base),
      currentBalance: balance,
      upcomingBills: bills,
      reserved: Money(reserved, base),
      horizon: horizon,
    );
  }

  /// Projects the next [monthCount] months.
  ///
  /// `projected = typical + committed + planned` per month, where *typical* is
  /// the **median** of the last [historyMonths] months of non-rule-generated
  /// spend. Median rather than mean because one month with a plane ticket in it
  /// should not raise every future month's estimate — and with a handful of
  /// samples, a mean is exactly what an outlier moves most.
  @override
  Future<Forecast> forecast({
    int monthCount = AppConfig.forecastMonthWindow,
    int historyMonths = AppConfig.analyticsMonthWindow,
  }) async {
    final now = DateTime.now().dateOnly;
    final thisMonth = Ym.fromDate(now);

    // History excludes the current month: it is partway through, so including
    // it would drag every projection down by however much of it is left.
    final past = thisMonth.previous.lastMonths(historyMonths);
    final future = thisMonth.next.nextMonths(monthCount);

    final expenseByMonth =
        await _db.analyticsDao.spontaneousExpenseByMonth(userId, past, base);
    final incomeByMonth =
        await _db.analyticsDao.spontaneousIncomeByMonth(userId, past, base);

    // Months before the user started are not evidence of frugality — dropping
    // the leading empty ones stops an account opened last week from projecting
    // near-zero spending forever.
    final expenseSamples = _trimLeadingEmpty(
      past.map((m) => expenseByMonth[m.value] ?? 0).toList(growable: false),
    );
    final incomeSamples = _trimLeadingEmpty(
      past.map((m) => incomeByMonth[m.value] ?? 0).toList(growable: false),
    );

    // With no completed month to learn from, the projection would be all
    // zeros — technically true and completely useless to someone who started
    // using the app this month. Fall back to the month in progress, scaled up
    // to a whole one. Still flagged provisional, because a week of data is a
    // hint rather than a pattern.
    var typicalMilli = _median(expenseSamples);
    var typicalIncomeMilli = _median(incomeSamples);

    if (expenseSamples.isEmpty && incomeSamples.isEmpty) {
      final partial = await _proRatedCurrentMonth(thisMonth, now);
      typicalMilli = partial.$1;
      typicalIncomeMilli = partial.$2;
    }

    final typical = Money(typicalMilli, base);
    final typicalIncome = Money(typicalIncomeMilli, base);

    final rules = await _recurring.all();
    final plans = await _planned.pendingBefore(future.last.lastDay);

    final months = <MonthForecast>[];
    for (final ym in future) {
      final from = ym.firstDay;
      final to = ym.lastDay;

      var committedOut = 0;
      var committedIn = 0;
      for (final rule in rules) {
        final count = rule.occurrencesBetween(from, to).length;
        if (count == 0) continue;
        final milli = _inBase(rule.amount) * count;
        if (rule.type == TxnType.income) {
          committedIn += milli;
        } else if (!rule.type.isTransfer) {
          committedOut += milli;
        }
      }

      final plannedMilli = plans
          .where((p) => !p.dueAt.isBefore(from) && !p.dueAt.isAfter(to))
          .fold<int>(0, (sum, p) => sum + _inBase(p.amount));

      months.add(
        MonthForecast(
          ym: ym,
          typical: typical,
          committed: Money(committedOut, base),
          planned: Money(plannedMilli, base),
          expectedIncome: Money(typicalIncome.milli + committedIn, base),
        ),
      );
    }

    return Forecast(months: months, historyMonths: expenseSamples.length);
  }

  /// Every expected outflow in [ym], grouped by day.
  ///
  /// Combines the two things that can be known ahead of time: plans the user
  /// entered, and occurrences enumerated from the recurring rules. Transfers
  /// and income rules are excluded — the calendar answers "what is going out".
  @override
  Future<CashflowCalendar> calendar(Ym ym) async {
    final from = ym.firstDay;
    final to = ym.lastDay;

    final byDay = <int, List<CalendarEntry>>{};
    void add(CalendarEntry entry) =>
        byDay.putIfAbsent(entry.date.day, () => <CalendarEntry>[]).add(entry);

    final categories = <String, String>{
      for (final c in await _db.categoryDao.getAll(userId)) c.id: c.name,
    };

    final plans = await _planned.between(from, to);
    for (final view in plans) {
      final plan = view.plan;
      if (plan.status != PlannedStatus.pending) continue;
      add(
        CalendarEntry(
          id: plan.id,
          label: plan.note?.trim().isNotEmpty ?? false
              ? plan.note!.trim()
              : view.category?.name ?? '',
          amount: Money(_inBase(plan.amount), base),
          date: plan.dueAt,
          source: CalendarSource.planned,
        ),
      );
    }

    final rules = await _recurring.all();
    for (final rule in rules) {
      if (rule.type.isTransfer || rule.type == TxnType.income) continue;
      for (final date in rule.occurrencesBetween(from, to)) {
        add(
          CalendarEntry(
            // Unique per occurrence: one rule can appear four times in a month.
            id: '${rule.id}@${date.ymd}',
            label: rule.note?.trim().isNotEmpty ?? false
                ? rule.note!.trim()
                : categories[rule.categoryId] ?? '',
            amount: Money(_inBase(rule.amount), base),
            date: date,
            source: CalendarSource.recurring,
          ),
        );
      }
    }

    for (final entries in byDay.values) {
      entries.sort((a, b) => a.date.compareTo(b.date));
    }
    return CashflowCalendar(byDay: byDay, currency: base);
  }

  /// The month in progress, scaled to a full month: `(expense, income)`.
  ///
  /// Divided by days elapsed rather than by the whole month, so a user four
  /// days in is not projected to spend four days' money over thirty.
  Future<(int, int)> _proRatedCurrentMonth(Ym ym, DateTime now) async {
    final expense = await _db.analyticsDao
        .spontaneousExpenseByMonth(userId, <Ym>[ym], base);
    final income = await _db.analyticsDao
        .spontaneousIncomeByMonth(userId, <Ym>[ym], base);

    final elapsed = now.day.clamp(1, ym.dayCount);
    final scale = ym.dayCount / elapsed;
    return (
      ((expense[ym.value] ?? 0) * scale).round(),
      ((income[ym.value] ?? 0) * scale).round(),
    );
  }

  int _inBase(Money amount) => amount.currency == base
      ? amount.milli
      : (amount.milli * (ratesToBase[amount.currency.code] ?? 0)).round();

  /// Drops leading zero months, which represent "before this user existed"
  /// rather than "a month they spent nothing".
  static List<int> _trimLeadingEmpty(List<int> samples) {
    final firstNonZero = samples.indexWhere((v) => v != 0);
    if (firstNonZero <= 0) return firstNonZero == 0 ? samples : const <int>[];
    return samples.sublist(firstNonZero);
  }

  static int _median(List<int> values) {
    if (values.isEmpty) return 0;
    final sorted = <int>[...values]..sort();
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) ~/ 2;
  }

  @override
  Future<Result<void>> rebuild() => guard(
        () => _db.transactionDao.rebuildAggregates(userId, base),
        mapDataError,
      );

  DateTime _nextPayday(DateTime from) {
    final thisMonth = dayOfMonthIn(from.year, from.month, paydayDayOfMonth);
    if (thisMonth.isAfter(from)) return thisMonth;
    final next = from.addMonthsClamped(1);
    return dayOfMonthIn(next.year, next.month, paydayDayOfMonth);
  }
}
