import 'package:masrouf/core/money/money.dart';
import 'package:masrouf/core/time/date_x.dart';
import 'package:masrouf/domain/enums/txn_type.dart';
import 'package:meta/meta.dart';

/// A template that materialises transactions on a schedule.
///
/// Materialisation happens locally (see `MaterialiseDueRecurring`) rather than via
/// a server cron: the app must generate this month's rent while offline, and a
/// server job would produce rows the device only learns about on next sync.
@immutable
class RecurringRule {
  const RecurringRule({
    required this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.accountId,
    required this.transferAccountId,
    required this.note,
    required this.cadence,
    required this.dayOfMonth,
    required this.dayOfWeek,
    required this.nextRunDate,
    required this.lastRunDate,
    required this.active,
    required this.updatedAt,
  });

  final String id;
  final TxnType type;
  final Money amount;
  final String? categoryId;
  final String accountId;
  final String? transferAccountId;
  final String? note;
  final Cadence cadence;

  /// Set for monthly rules. Values past the end of a short month are clamped at
  /// materialisation time, so a rule on the 31st still fires every month.
  final int? dayOfMonth;

  /// Set for weekly rules. 1 = Monday, matching [DateTime.weekday].
  final int? dayOfWeek;

  final DateTime nextRunDate;
  final DateTime? lastRunDate;
  final bool active;
  final DateTime updatedAt;

  bool isDueOn(DateTime day) =>
      active && !nextRunDate.dateOnly.isAfter(day.dateOnly);

  /// The occurrence after [from].
  ///
  /// Advances from the scheduled date rather than from "now", so an app that was
  /// closed for three months backfills all three occurrences instead of skipping
  /// to the next one.
  DateTime advanceFrom(DateTime from) => switch (cadence) {
        Cadence.weekly => from.dateOnly.add(const Duration(days: 7)),
        Cadence.monthly => _nextMonthlyAfter(from),
      };

  /// Every occurrence of this rule falling in `[from, to]`.
  ///
  /// The stored `nextRunDate` is a single cursor, so anything reading it alone
  /// sees at most one occurrence no matter how long the window — which is why
  /// a weekly rule used to contribute one bill to a month's commitments instead
  /// of four, and why Safe to spend under-reported.
  ///
  /// Capped at [maxOccurrences]: a weekly rule over a five-year horizon is 260
  /// dates nobody will read, and an unbounded loop here would be driven by
  /// user-supplied dates.
  List<DateTime> occurrencesBetween(
    DateTime from,
    DateTime to, {
    int maxOccurrences = 400,
  }) {
    if (!active || to.isBefore(from)) return const <DateTime>[];

    final result = <DateTime>[];
    var cursor = nextRunDate.dateOnly;
    final start = from.dateOnly;
    final end = to.dateOnly;

    // A rule whose cursor is behind the window — the app has not been opened in
    // a while — is walked forward first, so the window still sees real dates.
    var guard = 0;
    while (cursor.isBefore(start) && guard < maxOccurrences) {
      cursor = advanceFrom(cursor);
      guard++;
    }

    while (!cursor.isAfter(end) && result.length < maxOccurrences) {
      result.add(cursor);
      cursor = advanceFrom(cursor);
    }
    return result;
  }

  DateTime _nextMonthlyAfter(DateTime from) {
    final target = dayOfMonth ?? from.day;
    final base = from.dateOnly.addMonthsClamped(1);
    return dayOfMonthIn(base.year, base.month, target);
  }

  RecurringRule copyWith({
    Money? amount,
    String? categoryId,
    String? accountId,
    String? note,
    Cadence? cadence,
    int? dayOfMonth,
    int? dayOfWeek,
    DateTime? nextRunDate,
    DateTime? lastRunDate,
    bool? active,
    DateTime? updatedAt,
  }) =>
      RecurringRule(
        id: id,
        type: type,
        amount: amount ?? this.amount,
        categoryId: categoryId ?? this.categoryId,
        accountId: accountId ?? this.accountId,
        transferAccountId: transferAccountId,
        note: note ?? this.note,
        cadence: cadence ?? this.cadence,
        dayOfMonth: dayOfMonth ?? this.dayOfMonth,
        dayOfWeek: dayOfWeek ?? this.dayOfWeek,
        nextRunDate: nextRunDate ?? this.nextRunDate,
        lastRunDate: lastRunDate ?? this.lastRunDate,
        active: active ?? this.active,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecurringRule &&
          other.id == id &&
          other.amount == amount &&
          other.nextRunDate == nextRunDate &&
          other.active == active &&
          other.updatedAt == updatedAt);

  @override
  int get hashCode => Object.hash(id, amount, nextRunDate, active, updatedAt);
}
