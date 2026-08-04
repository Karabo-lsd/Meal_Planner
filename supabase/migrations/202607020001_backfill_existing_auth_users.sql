-- Backfill existing Supabase Auth users into app tables.
-- Needed for projects where users signed up before sync trigger existed.

insert into public.users (id, email)
select au.id, coalesce(au.email, '')
from auth.users au
where au.id is not null
on conflict (id) do update
set
  email = excluded.email,
  updated_at = now();

-- Optional: bootstrap missing profile rows from auth metadata.
insert into public.user_profiles (user_id, first_name, last_name)
select
  au.id,
  nullif(trim(coalesce(au.raw_user_meta_data ->> 'first_name', split_part(coalesce(au.raw_user_meta_data ->> 'full_name', ''), ' ', 1))), ''),
  nullif(trim(
    case
      when coalesce(au.raw_user_meta_data ->> 'full_name', '') like '% %'
        then regexp_replace(au.raw_user_meta_data ->> 'full_name', '^\S+\s*', '')
      else coalesce(au.raw_user_meta_data ->> 'last_name', '')
    end
  ), '')
from auth.users au
left join public.user_profiles up on up.user_id = au.id
where up.user_id is null
on conflict (user_id) do nothing;

-- Optional: bootstrap empty dietary preference rows.
insert into public.dietary_preferences (user_id)
select au.id
from auth.users au
left join public.dietary_preferences dp on dp.user_id = au.id
where dp.user_id is null
on conflict (user_id) do nothing;
