-- Savings goals are fed by transfers rather than by an account's whole balance.
--
-- Mirrors `transactions.goal_id` in the local schema (drift schema v6).
--
-- A goal used to measure itself against the balance of the account it named,
-- so two goals on one savings account each claimed all of it. Progress is now
-- the transfers earmarked for the goal — into a savings account minus back out
-- of one — summed on read. Nothing stores the total.
--
-- No foreign key to savings_goals, deliberately. Goals push before
-- transactions, but a goal that fails permanently stays in the outbox, and a
-- foreign key would then refuse every transfer earmarked for it — a whole
-- month of savings stuck behind one bad row. Goals are only ever soft-deleted,
-- so a dangling id cannot arise from a delete.

alter table public.transactions
  add column if not exists goal_id uuid;

alter table public.transactions
  drop constraint if exists txn_goal_only_on_transfers;
alter table public.transactions
  add constraint txn_goal_only_on_transfers
    check (goal_id is null or type = 'transfer');

-- Goal progress sums by goal; the partial index keeps that off the full table.
create index if not exists transactions_goal_idx
  on public.transactions (user_id, goal_id)
  where goal_id is not null;

-- Monthly periods replace the manual start/confirm cycle. A month's period is
-- written by whichever device notices the month first, under an id derived
-- from the user and the month, so two devices converge on one row.
comment on column public.savings_periods.confirmed_on is
  'The last day the period covers. For a monthly period, the month''s last day.';
