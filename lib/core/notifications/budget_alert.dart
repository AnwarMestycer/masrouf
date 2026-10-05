import 'package:masrouf/core/time/ym.dart';
import 'package:masrouf/domain/entities/budget.dart';
import 'package:meta/meta.dart';

/// How far into a budget the user has got.
enum BudgetAlertLevel {
  /// Four fifths spent — the last point at which saying so is still actionable
  /// rather than an obituary.
  nearLimit(80),

  overspent(100);

  const BudgetAlertLevel(this.percent);

  final int percent;

  double get threshold => percent / 100;
}

/// A crossing worth telling the user about.
@immutable
class BudgetAlert {
  const BudgetAlert({required this.progress, required this.level});

  final BudgetProgress progress;
  final BudgetAlertLevel level;

  String get budgetId => progress.budget.id;

  /// Spent to the cap exactly, with nothing over.
  ///
  /// Still an [BudgetAlertLevel.overspent] crossing — reaching the line is the
  /// event worth reporting, and `ratio >= 1` is what decides that. But the app's
  /// own [BudgetProgress.isOver] is strictly greater, so at exactly the cap the
  /// alert would otherwise contradict every screen that shows the same budget,
  /// and quote an overage of zero while doing it.
  bool get isFullySpent =>
      level == BudgetAlertLevel.overspent && progress.overspend.milli == 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BudgetAlert &&
          other.budgetId == budgetId &&
          other.level == level);

  @override
  int get hashCode => Object.hash(budgetId, level);

  @override
  String toString() => 'BudgetAlert($budgetId, ${level.percent}%)';
}

/// What to do after evaluating this month's budgets.
@immutable
class BudgetAlertDecision {
  const BudgetAlertDecision({
    required this.toFire,
    required this.toMark,
    required this.toClear,
  });

  /// Alerts to show now. At most one per budget — see [BudgetAlerts.evaluate].
  final List<BudgetAlert> toFire;

  /// Flag keys to set, so nothing fires twice for the same month.
  final List<String> toMark;

  /// Flag keys to clear, because the budget is no longer past that level.
  final List<String> toClear;

  bool get isEmpty => toFire.isEmpty && toMark.isEmpty && toClear.isEmpty;
}

/// Decides which budget alerts to raise.
///
/// Pure, so the deduplication rules are unit-tested directly rather than through
/// a notification plugin and a KV table.
abstract final class BudgetAlerts {
  /// Flag key for one budget, month and level.
  ///
  /// Scoped to the month because a cap is recurring: crossing 80% in March says
  /// nothing about April, and the alert should fire again when the new month's
  /// spending gets there.
  static String flagKey(String budgetId, Ym ym, BudgetAlertLevel level) =>
      'budget_alert.$budgetId.${ym.value}.${level.percent}';

  /// Evaluates [progress] against the flags already set.
  ///
  /// Two rules make this a *crossing* rather than a threshold:
  ///
  /// - A level that is crossed and not yet flagged fires, and is flagged.
  /// - A level that is flagged but no longer crossed is un-flagged, so raising a
  ///   cap or deleting a transaction re-arms the alert. Without that, a user who
  ///   lifted a cap after being warned would never hear about it again that month.
  ///
  /// Only the highest newly-crossed level actually fires, though every crossed
  /// level is flagged. A write that takes a budget from 50% straight to 130%
  /// should say "over budget" once, not "nearly there" and "over budget" in the
  /// same breath. This relies on [BudgetAlertLevel.values] being declared in
  /// ascending order of [BudgetAlertLevel.percent] — the later value wins.
  static BudgetAlertDecision evaluate({
    required Iterable<BudgetProgress> progress,
    required Set<String> firedKeys,
    required Ym ym,
  }) {
    final toFire = <BudgetAlert>[];
    final toMark = <String>[];
    final toClear = <String>[];

    for (final entry in progress) {
      // A budget whose category has been deleted is skipped. The budgets screen
      // already shows the orphan so the user can clear it; a notification about
      // a category that no longer exists names nothing they can act on.
      if (entry.category == null) continue;

      // A cap of zero has no meaningful ratio; `BudgetProgress.ratio` reports 0
      // for it, so it simply never crosses.
      BudgetAlertLevel? highestNew;

      for (final level in BudgetAlertLevel.values) {
        final key = flagKey(entry.budget.id, ym, level);
        final crossed =
            entry.budget.amount.milli > 0 && entry.ratio >= level.threshold;
        final flagged = firedKeys.contains(key);

        if (crossed && !flagged) {
          toMark.add(key);
          highestNew = level;
        } else if (!crossed && flagged) {
          toClear.add(key);
        }
      }

      if (highestNew != null) {
        toFire.add(BudgetAlert(progress: entry, level: highestNew));
      }
    }

    return BudgetAlertDecision(
      toFire: toFire,
      toMark: toMark,
      toClear: toClear,
    );
  }
}
