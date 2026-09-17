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
