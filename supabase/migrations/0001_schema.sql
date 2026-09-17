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
