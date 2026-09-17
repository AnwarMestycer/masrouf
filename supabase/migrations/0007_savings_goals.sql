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
