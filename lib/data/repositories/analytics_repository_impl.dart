import 'package:masrouf/core/error/auth_error_mapper.dart';
import 'package:masrouf/domain/entities/analytics/cashflow_calendar.dart';
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
    this.savingsReserved = const Money(0, Currency.tnd),
    DateTime Function()? clock,
  })  : _db = db,
        _recurring = recurring,
        _planned = planned,
        _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final RecurringRepository _recurring;
  final PlannedRepository _planned;
  final String userId;
  final Currency base;
  final int paydayDayOfMonth;
  final Map<String, double> ratesToBase;

  /// What this month has yet to put aside. Injected rather than queried
  /// so this repository keeps taking its inputs from one place.
  final Money savingsReserved;

  /// Injected so tests can stand on payday.
  final DateTime Function() _clock;

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
  ///
  /// On payday itself, until some income has been recorded that day, the
  /// horizon is today. Skipping straight to next month's payday would hold the
  /// whole coming month's bills and plans against a balance the salary has not
  /// reached yet.
  @override
  Future<SafeToSpend> safeToSpend() async {
    final today = _clock().dateOnly;
    final isPayday =
        dayOfMonthIn(today.year, today.month, paydayDayOfMonth) == today;
    final awaitingPayday = isPayday &&
        await _db.analyticsDao.incomeBetween(userId, today, today) == 0;
    final horizon = awaitingPayday ? today : _nextPayday(today);
    final bills = await _recurring.upcomingBefore(horizon);
    // Plans are reserved on the same footing as bills: both are money already
    // committed but not yet spent. The only difference is that one repeats and
    // the other was promised once.
    // Through the end of the horizon day, as bills are: a plan carries a time
    // of day, and against bare midnight one due later on payday would be left
    // out — on a payday horizon of today, that is every plan due today.
    final plans = await _planned.pendingBefore(
      horizon.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1)),
    );

    final balances =
        await _db.accountDao.watchWithBalances(userId).first;

    var totalMilli = 0;
    for (final entry in balances) {
      // Savings accounts hold money already put away. Counting them would offer
      // back last month's savings as this week's spending money — and a saving
      // would never lower the figure, since moving money between two counted
      // accounts changes nothing.
      if (entry.account.type == AccountType.savings) continue;
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
      // Savings come out too: whatever this month has yet to put aside. It is
      // still sitting in the account it arrived in, so without this the app
      // would offer back what has already been promised. What has been put
      // aside is out of the balance above already and is not taken twice.
      amount: Money(
        balance.milli - committed - reserved - savingsReserved.milli,
        base,
      ),
      currentBalance: balance,
      upcomingBills: bills,
      bills: Money(committed, base),
      reserved: Money(reserved, base),
      savingsReserved: savingsReserved,
      horizon: horizon,
      awaitingPayday: awaitingPayday,
    );
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

  int _inBase(Money amount) => amount.currency == base
      ? amount.milli
      : (amount.milli * (ratesToBase[amount.currency.code] ?? 0)).round();

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
