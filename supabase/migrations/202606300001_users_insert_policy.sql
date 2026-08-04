-- Allow authenticated users to insert their own row in public.users.
-- This supports app-level upserts when auth trigger bootstrap is missing or delayed.

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'users'
      and policyname = 'users_insert_own'
  ) then
    create policy users_insert_own on public.users
      for insert
      with check (auth.uid() = id);
  end if;
end
$$;
