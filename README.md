# Masrouf

An offline-first personal finance tracker. Log income and expenses in three taps,
categorise them, and see where the month is going — with or without a connection.

Flutter + Supabase. Drift (SQLite) is the source of truth for every read;
Supabase is the sync target.

---

## Setup

### 1. Prerequisites

- Flutter **3.47.1** stable (Dart 3.13.1) or newer
- A Supabase project — https://supabase.com/dashboard

### 2. Database

Run the migrations in `supabase/migrations/` **in order**, either through the
SQL editor in the dashboard or with the Supabase CLI:

```bash
supabase db push
```

If you'd rather not wire up the CLI, paste **`supabase/apply_all.sql`** into the
SQL editor and run it once — it is the same four files concatenated in order,
followed by a query that lists the six tables and confirms RLS is on for each.
It is not idempotent, so run it exactly once on a fresh project.

| File | What it does |
|------|--------------|
| `0001_schema.sql` | Tables, constraints, `updated_at` triggers |
| `0002_indexes.sql` | Query and sync indexes |
| `0003_rls.sql` | Row-level security — **required**, the app cannot read without it |
| `0004_defaults_reference.sql` | Documentation only; seeding happens client-side |

`0003_rls.sql` generates the same four policies for every table rather than
listing them by hand: a table missed in a hand-written list is a data leak, not a
typo. Every policy uses `(select auth.uid())` so Postgres evaluates it once per
statement instead of once per row.

### 3. Email auth

In **Authentication → Providers → Email**:

- Enable **Email**.
- Decide whether **Confirm email** is on. Whatever you choose, pass the matching
  value for `REQUIRE_EMAIL_CONFIRMATION` below — the app cannot reliably infer it,
  and the two must agree or sign-up routes to the wrong screen.

  To check what a project is actually set to, without opening the dashboard:

  ```bash
  curl -s "$SUPABASE_URL/auth/v1/settings" -H "apikey: $SUPABASE_KEY" \
    | python3 -c 'import json,sys; print("confirm email:", not json.load(sys.stdin)["mailer_autoconfirm"])'
  ```

In **Authentication → URL Configuration → Redirect URLs**, add:

```
io.masrouf://auth-callback
```

That value is already registered in `android/app/src/main/AndroidManifest.xml`
and `ios/Runner/Info.plist`. Change it in all three places if you change it at all.

### 4. Run

```bash
flutter pub get
dart run build_runner build

flutter run --dart-define-from-file=masrouf.env
```

`masrouf.env` holds the project URL and the **publishable** key. It is
gitignored; `masrouf.env.example` is the committed template — copy it and fill
it in:

```bash
cp masrouf.env.example masrouf.env
```

```bash
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_PUBLISHABLE_KEY=<publishable key>
REQUIRE_EMAIL_CONFIRMATION=true
AUTH_REDIRECT_URL=io.masrouf://auth-callback
BASE_CURRENCY=TND
```

Individual `--dart-define=KEY=value` flags work too, and `SUPABASE_ANON_KEY` is
accepted as an alias for the publishable key.

> **Never put the `service_role` key in this file or anywhere else in the app.**
> It bypasses row-level security completely, and anything compiled into a Flutter
> binary is extractable. The client only ever needs the publishable key — RLS is
> what scopes each user to their own rows. If a service key is ever pasted into a
> chat, a log, or a commit, rotate it in Settings → API.

Running without credentials shows a configuration screen with the command above
rather than failing on the first request.

### 5. Verify

```bash
flutter analyze   # clean
flutter test      # 257 tests (2 skip without the config file)
```

---

## Architecture

```
lib/
├── core/          money, time, validation, errors, theme, router, config
├── domain/        entities, enums, repository interfaces, use cases
├── data/
│   ├── local/     drift schema, DAOs, mappers, seed, row writer
│   ├── remote/    Supabase APIs and DTO mapping
│   ├── sync/      pull, push, conflict resolution
│   ├── backup/    local JSON snapshots and restore
│   └── repositories/
└── presentation/  Riverpod providers + widgets
```

Dependencies point inward. `domain` imports nothing from `data` or
`presentation`; widgets never touch drift or supabase directly.

### Reads are local, always

Every read comes from SQLite. The UI never awaits the network — not on the add
flow, not on the dashboard, not on history. Writes commit locally and enqueue a
push; the sync engine catches up afterwards. This is what makes the app fully
usable offline rather than merely degraded.

### Money is never a double

Amounts are integer **thousandths** of a currency unit, uniformly for every
currency (`Money`). TND carries three decimals — millimes — so three is the floor,
and one scale everywhere means addition never reconciles differing precisions.
Postgres stores `numeric(18,3)`; the wire format is a decimal string.

The only place a monetary value becomes a `double` is the final call into
`NumberFormat` for display.

### Sync

**Outbox, keyed by record.** `sync_queue` is keyed `(entity, entity_id)`, not an
append-only operation log. The pusher reads the *current* local row and upserts
it, so ten offline edits to one transaction collapse into a single push. This
composes exactly with last-write-wins, which only cares about final state.

**Delta pull.** Each table keeps its own `updated_at` cursor. The cursor advances
only after a page is committed locally, and it moves along the *server's*
timeline — a phone with a fast clock would otherwise skip its own window.

**Conflicts: last-write-wins on `updated_at`, with one guard.** A local row still
sitting in the queue is never overwritten, regardless of timestamps. Without that,
a pull landing between an edit and its push would discard the user's change and
then push the server's version back over it.

**Tombstones.** Deletes are soft (`deleted_at`). A hard delete could not
propagate: the next pull would resurrect the row on every device.

### Derived tables

`monthly_category_totals`, `daily_totals` and `account_balances` are maintained
incrementally inside the same drift transaction as the write that changes them.
They are local-only and never synced — pure derived state, rebuildable from
`transactions` at any time.

This is the app's performance strategy: the dashboard reads a handful of rows
instead of scanning the ledger, and an insert invalidates one narrow provider
rather than every analytics widget.

`test/unit/aggregates_test.dart` pins the invariant that matters: after any
sequence of writes, the incrementally maintained tables must equal what a full
rebuild produces. Both bugs that test caught during development were real.

---

## Notifications

Three kinds, each its own Android channel so one can be silenced without the
others, and each off until the user turns it on. The permission is requested at
that moment rather than at launch.

Everything is composed **while the app is open**, from data already on the
device — the notification carries a finished string. Nothing wakes up to query
anything, so there is no background worker to keep alive or get wrong.

| | When | How it is decided |
|---|---|---|
| Weekly summary | Sunday 20:00 | Recomputed and rescheduled every launch |
| Bill reminders | 08:00 on a plan's due date | `ReminderSchedule`, capped at 30 |
| Budget alerts | Immediately, on crossing 80% or 100% | `BudgetAlerts`, deduped per budget/month/level |

Both decision rules are pure functions with no plugin or clock in them, so they
are unit-tested directly.

Bill reminders and budget alerts are driven by **listeners on the streams they
care about** rather than calls at each write site. Every ledger write updates
`monthly_category_totals` in the same transaction, and every plan mutation writes
`planned_expenses` — so an edit, a bulk re-categorise, a restore or a pull all
reach the right watcher without five call sites each having to remember.

A budget alert is a *crossing*, not a threshold: falling back under a level
clears its flag, so raising a cap after being warned re-arms the alert instead of
silencing it for the rest of the month. Only the highest newly-crossed level
fires — one write taking a budget from 50% to 130% says "over budget" once.

Scheduling needs two receivers declared in `AndroidManifest.xml`
(`ScheduledNotificationReceiver` and `ScheduledNotificationBootReceiver`);
`flutter_local_notifications` bundles neither. Without the first, an alarm fires
and nothing appears. Without the second, every pending reminder is lost on reboot
or app update. `release_config_test.dart` asserts both are present.

---

## Backups

A local JSON snapshot of all nine synced tables, written to `backups/` in the app
documents directory, newest four kept. Automatic at launch when the switch is on
and the newest is over a week old; manual backup, share and restore from
settings.

The file reuses the **sync wire format verbatim** — `remote_mappers.dart` writes
it and `applyRemoteRows` reads it — so a backup is exactly what the server would
have been sent, and the two can never disagree about what a row is. Tombstones
are included: dropping them would make a restore resurrect everything the user
had deleted.

Restore is **restore-as-truth**, in one transaction: the synced tables are
cleared and rewritten, every row is enqueued as a push, and the pull cursors are
cleared so the next sync re-reads the account from scratch rather than resuming a
position describing data that no longer exists. The aggregates are rebuilt rather
than nudged.

This is a second line of defence, not a replacement for sync: an account can be
locked out, and a user on a bad connection may have weeks of rows that have never
left the phone.

---

## Performance notes

- **Cold start.** The database opens and the session restores before `runApp`, so
  the first frame renders real data instead of a spinner.
- **Drift on a background isolate** (`shareAcrossIsolates`), so a sync batch
  writing does not block the list scrolling.
- **WAL + `synchronous = NORMAL`.** Readers and the sync writer stop blocking each
  other. A hard power loss can cost the last commit — acceptable for a cache whose
  authority is Supabase.
- **`dateYmd` as an integer** (`yyyyMMdd`). Every query against it is a calendar
  operation, integer ordering is chronological for free, and no timezone shift can
  move a transaction between months.
- **History is paged** (50/page) and built with `ListView.builder`; the next page
  loads 600px before the end so rows are in place before the scroll reaches them.
- **Granular providers.** `select()` on settings means a payday change does not
  rebuild every amount on screen.
- **Category icons are keys, not code points.** Flutter can only tree-shake icon
  fonts when every `IconData` is a compile-time constant; a code point loaded from
  the database would ship the entire Material font.

---

## Charts

The categorical palette in `AppColors` is validated, not chosen by eye. The eight
hues and their dark counterparts clear the lightness band, chroma floor,
adjacent-pair CVD separation (worst ΔE 9.1 light / 8.4 dark) and normal-vision
separation (19.6 / 19.3) against both chart surfaces.

Three light-mode slots fall below 3:1 contrast on a light surface, so every chart
using them ships direct labels and a ranked list beside it — identity is never
carried by colour alone. The slot **order** is the CVD-safety mechanism; append
rather than insert.

The donut caps at six real slices and folds the tail into a neutral "Other".
Dark mode is a selected set of steps, not an automatic flip of the light values.

---

## Known v1 limitations

Called out rather than hidden:

- **Transfers must be between accounts of the same currency.** A cross-currency
  transfer needs the exact amount credited on the destination side; guessing it
  from a display rate would silently corrupt both balances. Do it as an expense
  plus an income until this is built properly.
- **Exchange rates are manual.** Deliberate for TND, where the rate that matters
  is the one your exchange office gave you, not a mid-market feed. Each
  transaction freezes its rate at write time, so editing a rate never rewrites
  history.
- **The ≤3-tap target holds for single-digit amounts** (`5` → category → save).
  Two-digit amounts cost one more tap. Account and date default themselves, so
  neither is ever on the critical path.
- **Recurring backfill is capped at 24 occurrences per rule per run**, so an app
  left closed for two years does not materialise hundreds of rows at launch. The
  remainder generates on subsequent launches.
- **Restore reads only backups already on this device.** Picking an arbitrary
  file would need a file-picker dependency, and the case it buys — a file carried
  from another phone — is the one the account sync already serves. Share exists so
  a copy can leave the device; bringing one back is a v2 problem.
- **A failed push is retried, never dropped.** After the retry budget is spent the
  entry stays in the queue rather than being discarded — the local row is still
  the user's data.

---

## Project commands

```bash
dart run build_runner build          # after touching drift tables or providers
dart run build_runner watch          # during development
flutter gen-l10n                     # after editing lib/l10n/*.arb
flutter analyze
flutter test
```

`test/helpers/test_database.dart` loads the host's versioned `libsqlite3.so.0`
when the unversioned dev symlink is absent, so the suite runs without installing
a system package.
