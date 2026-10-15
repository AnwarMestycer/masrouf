-- Pay-yourself-first: what each cycle asked for, and what was actually set aside.
--
-- Mirrors the local `savings_periods` table (drift schema v5).
--
-- A period is closed by confirming it rather than by a date. Income here does
-- not arrive on a schedule — it has landed on the 26th, the 16th and the 5th —
-- so "the end of the month" is not a moment the ledger can recognise, while
-- "I have counted what I saved" is.
--
-- There is no `owed` column by design. What is still owed to yourself is
-- max(0, sum(committed) - sum(saved)) across confirmed periods: one invariant,
-- derived on read. Storing it would be a second set of books that nobody
-- reconciles, and the first thing to go wrong when a period is edited.

create table public.savings_periods (
  id           uuid primary key,
  user_id      uuid not null references auth.users(id) on delete cascade,
  started_on   date not null,
  -- Income counted into the period. Grows until the period is closed.
  income       numeric(18,3) not null default 0 check (income >= 0),
  -- The share of income the plan asked for, frozen when the period closed.
  committed    numeric(18,3) not null default 0 check (committed >= 0),
  -- Null until confirmed; the period is open until then.
  confirmed_on date,
  saved        numeric(18,3) check (saved >= 0),
  currency     text not null default 'TND',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz,
  -- A confirmed period must carry the figure it was confirmed with. Allowing
  -- one without the other is how a cycle ends up closed but uncounted, which
  -- silently understates what is owed.
  constraint savings_periods_confirmed_has_saved
    check ((confirmed_on is null) = (saved is null))
);

-- The delta pull rides (user_id, updated_at) and must see tombstones.
create index savings_periods_user_updated_idx
  on public.savings_periods (user_id, updated_at);

-- At most one period may be open at a time: two would both claim the same
-- income and both reserve against the same balance.
create unique index savings_periods_one_open_idx
  on public.savings_periods (user_id)
  where confirmed_on is null and deleted_at is null;

create trigger savings_periods_touch before update on public.savings_periods
  for each row execute function public.touch_updated_at();

alter table public.savings_periods enable row level security;
revoke all on public.savings_periods from anon;
grant select, insert, update, delete on public.savings_periods to authenticated;

create policy savings_periods_sel on public.savings_periods for select
  using ((select auth.uid()) = user_id);
create policy savings_periods_ins on public.savings_periods for insert
  with check ((select auth.uid()) = user_id);
create policy savings_periods_upd on public.savings_periods for update
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy savings_periods_del on public.savings_periods for delete
  using ((select auth.uid()) = user_id);

-- The plan itself is one row per user, exactly like the payday it sits beside.
alter table public.user_settings
  add column if not exists savings_rate numeric(5,4) not null default 0
    check (savings_rate >= 0 and savings_rate <= 1),
  add column if not exists savings_floor numeric(18,3),
  add column if not exists savings_ceiling numeric(18,3),
  add column if not exists savings_recovery_periods integer not null default 1
    check (savings_recovery_periods >= 1);
