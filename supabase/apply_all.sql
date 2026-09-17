-- ============================================================================
-- Masrouf — complete database setup.
--
-- Paste this whole file into the Supabase SQL editor and run it once.
-- It is the concatenation of the executable migrations in order (0001-0003,
-- 0005-0007). 0004 is a reference note about client-side seeding and runs nothing.
-- Safe to run on a fresh project; NOT idempotent, so do not run it twice.
-- ============================================================================


-- ─────────────────────────────────────────────────────────────────
-- 0001_schema.sql
-- ─────────────────────────────────────────────────────────────────

-- Masrouf — core schema.
-- Money is numeric(18,3): TND carries 3 decimals (millimes). The client mirrors this
-- as an INTEGER count of thousandths so no floating point ever touches an amount.
-- Ids are client-generated (UUIDv7) so an offline insert has a stable identity
-- before it ever reaches the server.

create extension if not exists pgcrypto;

create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

create table public.user_settings (
  user_id             uuid primary key references auth.users(id) on delete cascade,
  base_currency       text not null default 'TND',
  locale              text not null default 'fr',
  theme_mode          text not null default 'system' check (theme_mode in ('system','light','dark')),
  payday_day_of_month smallint not null default 25 check (payday_day_of_month between 1 and 31),
  updated_at          timestamptz not null default now()
);

create table public.accounts (
  id              uuid primary key,
  user_id         uuid not null references auth.users(id) on delete cascade,
  name            text not null check (length(trim(name)) > 0),
  type            text not null check (type in ('cash','bank','savings','foreign')),
  currency        text not null default 'TND',
  opening_balance numeric(18,3) not null default 0,
  sort_order      int not null default 0,
  archived        boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);

create table public.categories (
  id         uuid primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  name       text not null check (length(trim(name)) > 0),
  kind       text not null check (kind in ('income','expense')),
  icon       text not null default 'category',
  color      bigint not null default 4283215696,
  sort_order int not null default 0,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- Name uniqueness applies to live rows only: deleting "Gym" must not block re-creating it.
create unique index categories_user_kind_name_uidx
  on public.categories (user_id, kind, lower(trim(name)))
  where deleted_at is null;

create table public.recurring_rules (
  id                  uuid primary key,
  user_id             uuid not null references auth.users(id) on delete cascade,
  type                text not null check (type in ('income','expense','transfer')),
  amount              numeric(18,3) not null check (amount > 0),
  currency            text not null default 'TND',
  category_id         uuid references public.categories(id) on delete set null,
  account_id          uuid not null references public.accounts(id) on delete cascade,
  transfer_account_id uuid references public.accounts(id) on delete cascade,
  note                text,
  cadence             text not null check (cadence in ('weekly','monthly')),
  day_of_month        smallint check (day_of_month between 1 and 31),
  day_of_week         smallint check (day_of_week between 1 and 7),
  next_run_date       date not null,
  last_run_date       date,
  active              boolean not null default true,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  deleted_at          timestamptz,
  constraint recurring_cadence_fields check (
    (cadence = 'monthly' and day_of_month is not null) or
    (cadence = 'weekly'  and day_of_week  is not null)
  ),
  constraint recurring_transfer_shape check (
    (type =  'transfer' and transfer_account_id is not null and transfer_account_id <> account_id) or
    (type <> 'transfer' and transfer_account_id is null)
  )
);

create table public.transactions (
  id                  uuid primary key,
  user_id             uuid not null references auth.users(id) on delete cascade,
  type                text not null check (type in ('income','expense','transfer')),
  amount              numeric(18,3) not null check (amount > 0),
  currency            text not null default 'TND',
  -- Rate captured at entry time so historical rows never shift when the user
  -- updates a manual rate later.
  fx_rate_to_base     numeric(18,6) not null default 1 check (fx_rate_to_base > 0),
  category_id         uuid references public.categories(id) on delete set null,
  account_id          uuid not null references public.accounts(id) on delete cascade,
  transfer_account_id uuid references public.accounts(id) on delete cascade,
  date                date not null,
  note                text,
  tags                text[] not null default '{}',
  recurring_rule_id   uuid references public.recurring_rules(id) on delete set null,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  deleted_at          timestamptz,
  constraint txn_transfer_shape check (
    (type =  'transfer' and transfer_account_id is not null and transfer_account_id <> account_id) or
    (type <> 'transfer' and transfer_account_id is null)
  ),
  constraint txn_non_transfer_has_category check (type = 'transfer' or category_id is not null)
);

create table public.exchange_rates (
  user_id      uuid not null references auth.users(id) on delete cascade,
  currency     text not null,
  rate_to_base numeric(18,6) not null check (rate_to_base > 0),
  updated_at   timestamptz not null default now(),
  primary key (user_id, currency)
);

do $$
declare t text;
begin
  foreach t in array array['user_settings','accounts','categories',
                           'recurring_rules','transactions','exchange_rates']
  loop
    execute format(
      'create trigger %1$I_touch before update on public.%1$I
         for each row execute function public.touch_updated_at()', t);
  end loop;
end $$;

-- ─────────────────────────────────────────────────────────────────
-- 0002_indexes.sql
-- ─────────────────────────────────────────────────────────────────

-- Live-query indexes exclude tombstones; the sync index must include them so a
-- delta pull can still learn about deletions.

create index transactions_user_date_idx
  on public.transactions (user_id, date desc) where deleted_at is null;
create index transactions_user_category_idx
  on public.transactions (user_id, category_id) where deleted_at is null;
create index transactions_user_account_idx
  on public.transactions (user_id, account_id) where deleted_at is null;
create index transactions_user_updated_idx
  on public.transactions (user_id, updated_at);
create index transactions_tags_gin
  on public.transactions using gin (tags) where deleted_at is null;

create index accounts_user_updated_idx    on public.accounts (user_id, updated_at);
create index accounts_user_sort_idx       on public.accounts (user_id, sort_order)
  where deleted_at is null and not archived;

create index categories_user_updated_idx  on public.categories (user_id, updated_at);
create index categories_user_kind_idx     on public.categories (user_id, kind, sort_order)
  where deleted_at is null;

create index recurring_user_updated_idx   on public.recurring_rules (user_id, updated_at);
create index recurring_due_idx            on public.recurring_rules (user_id, next_run_date)
  where active and deleted_at is null;

-- ─────────────────────────────────────────────────────────────────
-- 0003_rls.sql
-- ─────────────────────────────────────────────────────────────────

-- Every table is user-scoped and follows the identical four-policy shape, so it is
-- generated rather than hand-repeated: one missed table is a data leak.
--
-- Policies use (select auth.uid()) rather than bare auth.uid(). Postgres treats the
-- subquery as a stable InitPlan evaluated once per statement instead of re-invoking
-- the function per row — material on a multi-thousand-row history scan.

do $$
declare t text;
begin
  foreach t in array array['user_settings','accounts','categories',
                           'recurring_rules','transactions','exchange_rates']
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from anon', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);

    execute format(
      'create policy %1$I on public.%2$I for select
         using ((select auth.uid()) = user_id)', t || '_sel', t);
    execute format(
      'create policy %1$I on public.%2$I for insert
         with check ((select auth.uid()) = user_id)', t || '_ins', t);
    execute format(
      'create policy %1$I on public.%2$I for update
         using ((select auth.uid()) = user_id)
         with check ((select auth.uid()) = user_id)', t || '_upd', t);
    execute format(
      'create policy %1$I on public.%2$I for delete
         using ((select auth.uid()) = user_id)', t || '_del', t);
  end loop;
end $$;

-- ─────────────────────────────────────────────────────────────────
-- 0005_budgets.sql
-- ─────────────────────────────────────────────────────────────────

-- Monthly spending caps, one per category.
--
-- Mirrors the local `budgets` table (drift schema v2). Same four-column synced
-- shape as every other table here — (id, user_id, updated_at, deleted_at) — so
-- the table-agnostic sync engine needs no per-table code, only a new entry in
-- the SyncEntity enum.

create table public.budgets (
  id          uuid primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  -- Cascade rather than set null: a budget with no category is not a thing the
  -- app can render or the user can act on.
  category_id uuid not null references public.categories(id) on delete cascade,
  amount      numeric(18,3) not null check (amount > 0),
  currency    text not null default 'TND',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);

-- One live cap per category. Partial, so a soft-deleted budget does not block
-- setting a new one for the same category later.
create unique index budgets_one_per_category
  on public.budgets (user_id, category_id) where deleted_at is null;

-- The delta pull rides (user_id, updated_at) and must see tombstones.
create index budgets_user_updated_idx on public.budgets (user_id, updated_at);

create trigger budgets_touch before update on public.budgets
  for each row execute function public.touch_updated_at();

-- The same four-policy shape as every other user-scoped table. Written out
-- rather than looped because this migration adds exactly one table, and the
-- loop's value is in not missing a table when there are several.
alter table public.budgets enable row level security;
revoke all on public.budgets from anon;
grant select, insert, update, delete on public.budgets to authenticated;

create policy budgets_sel on public.budgets for select
  using ((select auth.uid()) = user_id);
create policy budgets_ins on public.budgets for insert
  with check ((select auth.uid()) = user_id);
create policy budgets_upd on public.budgets for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy budgets_del on public.budgets for delete
  using ((select auth.uid()) = user_id);

-- ─────────────────────────────────────────────────────────────────
-- 0006_planned_expenses.sql
-- ─────────────────────────────────────────────────────────────────

-- Dated commitments that have not moved money yet.
--
-- Mirrors the local `planned_expenses` table (drift schema v3). Deliberately
-- separate from `transactions`: the client's aggregates key off `date_ymd` with
-- no upper bound, so a future-dated transaction would be folded into balances
-- immediately. A plan must never be able to become one by accident.
--
-- `due_at` is timestamptz, not date — a plan carries a time of day, which is
-- what makes a reminder worth showing.

create table public.planned_expenses (
  id             uuid primary key,
  user_id        uuid not null references auth.users(id) on delete cascade,
  -- Set null, not cascade: deleting a category should not silently destroy a
  -- commitment the user still owes. It just becomes uncategorised.
  category_id    uuid references public.categories(id) on delete set null,
  account_id     uuid references public.accounts(id) on delete set null,
  amount         numeric(18,3) not null check (amount > 0),
  currency       text not null default 'TND',
  due_at         timestamptz not null,
  note           text,
  status         text not null default 'pending'
                 check (status in ('pending','done','cancelled')),
  -- The transaction this plan became once confirmed, so the two can be traced
  -- to each other afterwards.
  transaction_id uuid references public.transactions(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz
);

-- What Safe to spend reserves: pending plans up to a horizon.
create index planned_user_due_idx
  on public.planned_expenses (user_id, due_at)
  where deleted_at is null and status = 'pending';

-- The delta pull rides (user_id, updated_at) and must see tombstones.
create index planned_user_updated_idx
  on public.planned_expenses (user_id, updated_at);

create trigger planned_expenses_touch before update on public.planned_expenses
  for each row execute function public.touch_updated_at();

-- The same four-policy shape as every other user-scoped table.
alter table public.planned_expenses enable row level security;
revoke all on public.planned_expenses from anon;
grant select, insert, update, delete on public.planned_expenses to authenticated;

create policy planned_expenses_sel on public.planned_expenses for select
  using ((select auth.uid()) = user_id);
create policy planned_expenses_ins on public.planned_expenses for insert
  with check ((select auth.uid()) = user_id);
create policy planned_expenses_upd on public.planned_expenses for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy planned_expenses_del on public.planned_expenses for delete
  using ((select auth.uid()) = user_id);

-- ─────────────────────────────────────────────────────────────────
-- 0007_savings_goals.sql
-- ─────────────────────────────────────────────────────────────────

-- Savings targets, tracked by a real account's balance.
--
-- Mirrors the local `savings_goals` table (drift schema v4). There is no
-- `saved` column by design: progress is the linked account's balance, so the
-- goal cannot drift out of step with the ledger. A stored total would be a
-- second set of books that nobody reconciles.

create table public.savings_goals (
  id          uuid primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  name        text not null check (length(trim(name)) > 0),
  target      numeric(18,3) not null check (target > 0),
  currency    text not null default 'TND',
  -- Cascade: a goal whose account is gone has nothing left to measure.
  account_id  uuid not null references public.accounts(id) on delete cascade,
  target_date date,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);

-- The delta pull rides (user_id, updated_at) and must see tombstones.
create index goals_user_updated_idx on public.savings_goals (user_id, updated_at);

create trigger savings_goals_touch before update on public.savings_goals
  for each row execute function public.touch_updated_at();

alter table public.savings_goals enable row level security;
revoke all on public.savings_goals from anon;
grant select, insert, update, delete on public.savings_goals to authenticated;

create policy savings_goals_sel on public.savings_goals for select
  using ((select auth.uid()) = user_id);
create policy savings_goals_ins on public.savings_goals for insert
  with check ((select auth.uid()) = user_id);
create policy savings_goals_upd on public.savings_goals for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy savings_goals_del on public.savings_goals for delete
  using ((select auth.uid()) = user_id);

-- ─────────────────────────────────────────────────────────────────
-- Verification — should return 9 tables, each with rowsecurity = true
-- ─────────────────────────────────────────────────────────────────

select tablename, rowsecurity
from pg_tables
where schemaname = 'public'
order by tablename;
