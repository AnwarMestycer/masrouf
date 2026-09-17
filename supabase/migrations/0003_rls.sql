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
