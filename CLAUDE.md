# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Masrouf is an offline-first personal finance tracker: Flutter + Drift (SQLite) +
Supabase. `README.md` covers Supabase project setup, the SQL migrations and the
credential file; this file covers working in the code.

## Commands

```bash
flutter pub get
dart run build_runner build          # REQUIRED after touching drift tables or DAOs
dart run build_runner watch          # during development
flutter gen-l10n                     # after editing lib/l10n/*.arb

flutter run --dart-define-from-file=masrouf.env
flutter analyze
flutter test
flutter test test/unit/money_test.dart                      # one file
flutter test test/unit/sync_test.dart -n 'substring of name' # one test
dart run flutter_launcher_icons     # regenerates android mipmap-* from assets/icon/
```

`masrouf.env` is gitignored (`cp masrouf.env.example masrouf.env`). Without it
the app shows a configuration screen rather than failing on first request, and
two tests in `test/unit/env_test.dart` self-skip.

Baseline as of the last check: `flutter test` is 257 passing / 2 skipped and
`flutter analyze` is clean.

Codegen is **drift only**. `riverpod_annotation` / `riverpod_generator` are in
`pubspec.yaml` but no file uses `@riverpod`; every provider is hand-written.
`custom_lint`/`riverpod_lint` are dev deps but are not wired into
`analysis_options.yaml`, so `dart run custom_lint` is not part of the gate.
Generated `*.g.dart` and `lib/l10n/app_localizations*.dart` are excluded from
analysis — never hand-edit them.

## Layering

```
lib/core/         money, time, validation, Result/Failure, theme, router, config
lib/domain/       entities, enums, repository interfaces  (imports nothing below)
lib/data/local/   drift schema, DAOs, mappers, seed, row writer
lib/data/remote/  Supabase APIs + DTO mapping
lib/data/sync/    pull, push, conflict resolution
lib/data/backup/  local JSON snapshots and restore
lib/presentation/ Riverpod providers + widgets
```

Dependencies point inward. `domain` imports nothing from `data` or
`presentation`; widgets never touch drift or supabase directly — they go through
a repository interface resolved from a provider.

`lib/presentation/providers/core_providers.dart` and `data_providers.dart` are
the composition root: everything below the UI is constructed there, so widgets
contain no `new` calls and each dependency is individually overridable in tests.

Repositories return `Result<T>` (`core/result/result.dart`) — a sealed
`Ok`/`Err`, exhaustively switchable. Errors are a `Failure` carrying a
`FailureCode` enum, never a message: the domain layer stays free of
`BuildContext`, and `FailureMessage.localise` in
`presentation/common/l10n_x.dart` renders it in en/fr/ar. Wrap the outermost
repository call in `guard(...)`, not deeper ones.

## Invariants that will bite you

**Money is never a double.** `Money` holds an integer count of *thousandths* of
a currency unit, uniformly for every currency (TND has three decimals, so three
is the floor). Postgres stores `numeric(18,3)`; the wire format is a decimal
string. The only place an amount becomes a `double` is the final `NumberFormat`
call for display.

**Every read comes from SQLite.** The UI never awaits the network — not the add
flow, not the dashboard, not history. A write commits locally, enqueues an
outbox row, and calls `_sync.requestSync()` fire-and-forget. See
`TransactionRepositoryImpl.add` for the canonical shape.

**Exchange rates are frozen at write time and `rateToBaseFor` can return null.**
Null means "not known yet", distinct from "no rates set". A caller that
substitutes `1.0` writes a permanently wrong amount, because editing a rate later
never rewrites history. Refuse the write instead.

**Aggregates are maintained inside the writing transaction.**
`monthly_category_totals`, `daily_totals` and `account_balances` are local-only
derived state, folded forward by `TransactionDao._applyDelta` in the same drift
transaction as the row that changed them (`+1` to apply, `-1` to reverse — an
update does both). `AnalyticsDao` only ever reads them, never `transactions`, so
the dashboard costs a handful of row reads. If you add a write path for
transactions, it must go through those deltas.
`test/unit/aggregates_test.dart` pins the invariant: after any sequence of
writes the incremental tables must equal a full `rebuildAggregates`.

**Category icons are string keys into `CategoryIcons.byKey`, never code points.**
Flutter only tree-shakes icon fonts when every `IconData` is a compile-time
constant; a code point read from the database ships the whole Material font.

**`dateYmd` is an integer (`yyyyMMdd`).** Integer ordering is chronological and
no timezone shift can move a transaction between months.

## Sync model

`lib/data/sync/` is table-agnostic and drives everything off the `SyncEntity`
enum (`domain/enums/sync_enums.dart`) — there are no per-table branches in the
workers.

- **Outbox keyed by record.** `sync_queue` is keyed `(entity, entity_id)`, not an
  append-only log. `PushWorker` reads the *current* local row and upserts it, so
  ten offline edits to one transaction collapse into one push. `SyncOp` has only
  `upsert` and `delete` for the same reason.
- **Delta pull, per-table cursor**, advanced only after a page commits locally
  and along the *server's* timeline (a phone with a fast clock would otherwise
  skip its own window).
- **Last-write-wins on `updated_at`, with one guard:** a local row still sitting
  in the queue is never overwritten, whatever the timestamps say.
- **Deletes are soft** (`deleted_at`). A hard delete would be resurrected by the
  next pull. `SyncEntity.hasTombstones` is false for `user_settings` and
  `exchange_rates` — pushing a delete for either is a 400.
- `push` runs before `pull`; a transient failure aborts the run, a permanent
  failure is recorded against the single offending record. A spent retry budget
  leaves the entry queued rather than dropping it.
- **`PushWorker.pushOrder` and `PullWorker.order` must both list every
  `SyncEntity`.** They are hand-maintained lists, not switches, so an omission is
  not a compile error — and it is silent in both directions: an entity missing
  from the push order jams its outbox entries forever, one missing from the pull
  order reaches the server and never comes back. `sync_outbox_test.dart` asserts
  both against `SyncEntity.values`; add to both lists together.
- Writing wire rows into drift lives in `applyRemoteRows`
  (`data/local/row_writer.dart`), shared by the pull and by backup restore. It
  opens no transaction of its own and does no conflict filtering — the caller
  decides both.
- Tuning lives in `AppConfig`, not inline.

**Adding a synced table** touches: a `supabase/migrations/NNNN_*.sql` file (plus
RLS), the drift table + an additive `onUpgrade` step and a bump of
`schemaVersion` in `app_database.dart`, a DAO, `mappers.dart`,
`remote_mappers.dart` (hand-written, must match the SQL exactly), a `SyncEntity`
entry and its `hasTombstones` arm, an `applyRemoteRows` case, **both**
`pushOrder` and `PullWorker.order`, `clearUserData` and `clearSyncedData`, and a
repository + provider. Then `dart run build_runner build`. The backup format
needs no change — it iterates `SyncEntity`, so a new table is included
automatically once the above is done.

Migrations here may create and backfill but must **never** drop or rewrite a
column: existing rows are the user's only copy of anything written offline.
Current `schemaVersion` is 4.

## Notifications and backups

`core/notifications/` holds a general `NotificationService` (three Android
channels, schedule / show-now / cancel) plus two **pure decision modules** —
`ReminderSchedule` and `BudgetAlerts` — that hold the actual rules and are
unit-tested with no plugin, clock or database involved. Keep new rules there
rather than in the controllers.

`presentation/providers/notification_providers.dart` is the only wiring: the
three device-local toggles (KV, not synced — a schedule belongs to the phone),
the three controllers, and two **watcher providers**. The watchers listen to
`budgetProgressProvider` and `pendingPlansProvider` instead of hooking each write
site, so any path that touches the ledger or a plan — including a bulk edit, a
pull or a restore — reschedules correctly. They are instantiated in `app.dart`
alongside the session lifecycle.

Scheduled notifications need `ScheduledNotificationReceiver` and
`ScheduledNotificationBootReceiver` in `AndroidManifest.xml`;
`flutter_local_notifications` ships neither, and without them alarms fire into
nothing (and are lost on reboot). `release_config_test.dart` guards this.

`data/backup/backup_service.dart` snapshots all nine synced tables as the sync
wire format, keeps the newest four, and restores as truth — clear, rewrite,
enqueue every row as a push, drop the pull cursors, rebuild aggregates. Inject
`root:` and `encode:` in tests; the default encoder hops to a background isolate
via `compute`.

## Session and routing

`SessionLifecycle` (`presentation/providers/session_providers.dart`) owns
sign-in/sign-out and runs outside the widget tree so it fires once per session,
not once per rebuild. The order is deliberate: sync start (wrapped in
try/catch — everything after it must run offline) → seed default categories only
if the pull found none → `materialiseDue()` for recurring rules → rebuild
aggregates → refresh digest. Sign-out clears pull cursors *and* user data, so the
next account on the device does a complete first pull.

Seeding is client-side only, in `data/local/seed/default_categories.dart`; there
is deliberately no Postgres trigger doing the same job, and ids are minted fresh
rather than fixed so two devices converge instead of colliding.

`bootstrap()` opens the database and restores the Supabase session *before*
`runApp`, so the first frame has real data. The database is injected by
overriding `appDatabaseProvider`.

The router (`core/router/app_router.dart`) redirects on auth via a
`ChangeNotifier` fed by `ref.listen` — not `ref.watch`, which would rebuild the
router and discard the navigation stack — and only when sign-in *state* flips, so
a token refresh never disturbs it. Add paths to `Routes` as constants; full-screen
routes declare the root navigator key so they cover the bottom bar.

Locale comes from the user's own setting (so it syncs across devices), not the
device. Arabic RTL is handled entirely by Flutter's directionality — never mirror
anything by hand. UI strings go in all three `lib/l10n/app_*.arb` files.

## Tests

`test/helpers/app_harness.dart` boots the real router, real screens and a real
in-memory database. The only fakes are the two things a test process cannot have:
a Supabase session (`TestAuthRepository`) and a network (`OfflineConnectivity`).
Prefer this over mocking a repository — the bugs these tests exist to catch live
in the widget↔repository wiring that a mock would hide.

- `pumpApp(tester, db:, sync:)` returns the `GoRouter` so a test can assert on
  location as well as on what rendered; pass `locale:` for fr/ar.
- `seedMinimalLedger(db)` gives one account and one category — the minimum before
  the add flow will accept anything.
- `openSettingsItem(tester, label)` drags the lazy settings list into view; a row
  below the fold has no element for `ensureVisible` to find, and "built" is not
  the same as "hit-testable".
- `test/helpers/test_database.dart` loads the host's versioned `libsqlite3.so.0`
  when the unversioned dev symlink is absent, so the suite runs with no system
  package installed.

`test/unit/release_config_test.dart` asserts on `AndroidManifest.xml` — INTERNET
permission, notification permissions, `allowBackup="false"`. These are failures
that otherwise only appear in a release build on a real phone.

## Charts

The categorical palette in `core/theme/app_colors.dart` is validated, not picked
by eye (lightness band, chroma floor, CVD and normal-vision separation against
both chart surfaces). Slot **order** is the CVD-safety mechanism: **append, never
insert**. Three light-mode slots are under 3:1 on a light surface, so any chart
using them must ship direct labels or a ranked list — identity is never carried by
colour alone. Dark mode is a separately chosen set of steps, not a flip of the
light values. The donut caps at six real slices and folds the tail into a neutral
"Other".
