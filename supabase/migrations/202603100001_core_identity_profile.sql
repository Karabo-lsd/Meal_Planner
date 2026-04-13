-- Phase 2A: Core identity and profile schema
-- Safe, additive migration for Supabase Postgres.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.sync_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, email)
  values (new.id, new.email)
  on conflict (id) do update
    set email = excluded.email,
        updated_at = now();
  return new;
end;
$$;

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint users_email_format_chk check (position('@' in email) > 1)
);

create index if not exists idx_users_email on public.users(email);

create trigger trg_users_updated_at
before update on public.users
for each row execute function public.set_updated_at();

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.sync_auth_user();

create table if not exists public.user_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.users(id) on delete cascade,
  first_name text,
  last_name text,
  phone text,
  age int,
  sex text,
  weight numeric(6,2),
  height numeric(6,2),
  activity_level text,
  goal text,
  daily_calorie_target numeric(8,2),
  daily_protein_target numeric(8,2),
  daily_carb_target numeric(8,2),
  daily_fat_target numeric(8,2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_profiles_age_chk check (age is null or age between 5 and 120),
  constraint user_profiles_weight_chk check (weight is null or weight > 0),
  constraint user_profiles_height_chk check (height is null or height > 0),
  constraint user_profiles_cal_target_chk check (daily_calorie_target is null or daily_calorie_target > 0),
  constraint user_profiles_protein_target_chk check (daily_protein_target is null or daily_protein_target >= 0),
  constraint user_profiles_carb_target_chk check (daily_carb_target is null or daily_carb_target >= 0),
  constraint user_profiles_fat_target_chk check (daily_fat_target is null or daily_fat_target >= 0)
);

create index if not exists idx_user_profiles_user_id on public.user_profiles(user_id);

create trigger trg_user_profiles_updated_at
before update on public.user_profiles
for each row execute function public.set_updated_at();

create table if not exists public.dietary_preferences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.users(id) on delete cascade,
  diet_type text,
  allergies text[] not null default '{}',
  excluded_ingredients text[] not null default '{}',
  preferred_cuisines text[] not null default '{}',
  disliked_foods text[] not null default '{}',
  max_prep_time_minutes int,
  budget_preference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint dietary_preferences_max_prep_chk check (max_prep_time_minutes is null or max_prep_time_minutes between 1 and 720)
);

create index if not exists idx_dietary_preferences_user_id on public.dietary_preferences(user_id);
create index if not exists idx_dietary_preferences_diet_type on public.dietary_preferences(diet_type);

create trigger trg_dietary_preferences_updated_at
before update on public.dietary_preferences
for each row execute function public.set_updated_at();

alter table public.users enable row level security;
alter table public.user_profiles enable row level security;
alter table public.dietary_preferences enable row level security;

create policy users_select_own on public.users
for select using (auth.uid() = id);

create policy users_update_own on public.users
for update using (auth.uid() = id)
with check (auth.uid() = id);

create policy user_profiles_select_own on public.user_profiles
for select using (auth.uid() = user_id);

create policy user_profiles_insert_own on public.user_profiles
for insert with check (auth.uid() = user_id);

create policy user_profiles_update_own on public.user_profiles
for update using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy user_profiles_delete_own on public.user_profiles
for delete using (auth.uid() = user_id);

create policy dietary_preferences_select_own on public.dietary_preferences
for select using (auth.uid() = user_id);

create policy dietary_preferences_insert_own on public.dietary_preferences
for insert with check (auth.uid() = user_id);

create policy dietary_preferences_update_own on public.dietary_preferences
for update using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy dietary_preferences_delete_own on public.dietary_preferences
for delete using (auth.uid() = user_id);
