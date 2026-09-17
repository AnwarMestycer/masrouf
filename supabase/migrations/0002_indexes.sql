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
