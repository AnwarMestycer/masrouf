/// Tunable constants that are not user settings and not build-time secrets.
abstract final class AppConfig {
  /// Page size for the history list. Sized so one page comfortably overfills a
  /// phone screen, keeping the scroll smooth without over-fetching.
  static const int historyPageSize = 50;

  /// How many category chips the fast-add flow offers before "more". Recent-first,
  /// so this is a *reach* budget rather than a completeness one.
  static const int quickCategoryCount = 8;

  /// How large a single payment has to be, as a share of a window's spending,
  /// before it is set aside from the everyday figure.
  ///
  /// A share rather than a percentile or a fixed amount: it scales with the
  /// window, it is meaningful at low transaction counts where a percentile is
  /// not, and it states exactly what it means — this one payment is a tenth of
  /// everything spent. A ledger of 2 DT coffees and one 322 DT tuition bill has
  /// a mean nobody ever spent, and an unqualified total that answers the wrong
  /// question.
  static const double analyticsLargePaymentShare = 0.10;

  /// …and it must also dwarf a typical purchase by this much.
  ///
  /// The share alone is not enough. Ten identical payments are each a tenth of
  /// the window, so a share test on its own calls every one of them large and
  /// reports that nothing was everyday spending. Requiring a multiple of the
  /// median as well says what is actually meant: this payment is unlike the
  /// ones around it. A window of evenly sized purchases has no outlier, however
  /// few purchases there are.
  static const int analyticsLargePaymentMedianMultiple = 3;

  /// Months of history the analytics screens keep in memory at once.
  static const int analyticsMonthWindow = 6;

  /// How far ahead the forecast projects.
  ///
  /// Three months, not twelve: a median drawn from six months of history says
  /// very little about next spring, and a number presented that far out invites
  /// more confidence than it has earned.
  static const int forecastMonthWindow = 3;

  /// Debounce before a keystroke in the history search hits the database.
  static const Duration searchDebounce = Duration(milliseconds: 220);

  /// How long the "Undo" snackbar stays up after a delete.
  static const Duration undoWindow = Duration(seconds: 5);

  /// Sync retry backoff. Capped so a long offline stretch still retries promptly
  /// once the connection returns.
  static const Duration syncInitialBackoff = Duration(seconds: 2);
  static const Duration syncMaxBackoff = Duration(minutes: 5);
  static const int syncMaxAttempts = 8;

  /// Rows pushed per sync batch. Keeps a single request well under PostgREST's
  /// payload limits while still amortising the round trip.
  static const int syncPushBatchSize = 100;
  static const int syncPullPageSize = 500;
}
