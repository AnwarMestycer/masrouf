/// Tunable constants that are not user settings and not build-time secrets.
abstract final class AppConfig {
  /// Page size for the history list. Sized so one page comfortably overfills a
  /// phone screen, keeping the scroll smooth without over-fetching.
  static const int historyPageSize = 50;

  /// How many category chips the fast-add flow offers before "more". Recent-first,
  /// so this is a *reach* budget rather than a completeness one.
  static const int quickCategoryCount = 8;

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
