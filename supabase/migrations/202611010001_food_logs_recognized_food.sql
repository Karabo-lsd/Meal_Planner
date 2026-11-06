alter table public.food_logs
  add column if not exists food_name text,
  add column if not exists usda_fdc_id bigint;

alter table public.food_logs
  drop constraint if exists food_logs_food_or_recipe_chk;

alter table public.food_logs
  add constraint food_logs_food_or_recipe_chk check (
    canonical_food_id is not null
    or recipe_id is not null
    or nullif(btrim(food_name), '') is not null
  );
