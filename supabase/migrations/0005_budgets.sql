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
