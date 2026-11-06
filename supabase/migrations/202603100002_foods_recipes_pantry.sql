-- Phase 2B/3: Canonical foods, pantry, recipes, and nutrition schema.

create table if not exists public.foods_master (
  id uuid primary key default gen_random_uuid(),
  canonical_name text not null,
  aliases text[] not null default '{}',
  food_category text,
  spoonacular_id text,
  edamam_id text,
  usda_fdc_id text,
  open_food_facts_id text,
  image_model_label_id text,
  food_type text not null,
  default_serving_size numeric(10,3),
  default_serving_unit text,
  allergens text[] not null default '{}',
  dietary_tags text[] not null default '{}',
  cuisine_tags text[] not null default '{}',
  verification_status text not null default 'provider_reported',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint foods_master_food_type_chk check (food_type in ('ingredient', 'packaged_food', 'prepared_meal', 'recipe')),
  constraint foods_master_verification_status_chk check (
    verification_status in (
      'provider_reported',
      'validated_with_usda',
      'user_confirmed',
      'estimated_from_image',
      'partially_estimated'
    )
  ),
  constraint foods_master_default_serving_chk check (default_serving_size is null or default_serving_size > 0)
);

create unique index if not exists uq_foods_master_spoonacular_id on public.foods_master(spoonacular_id) where spoonacular_id is not null;
create unique index if not exists uq_foods_master_edamam_id on public.foods_master(edamam_id) where edamam_id is not null;
create unique index if not exists uq_foods_master_usda_fdc_id on public.foods_master(usda_fdc_id) where usda_fdc_id is not null;
create unique index if not exists uq_foods_master_open_food_facts_id on public.foods_master(open_food_facts_id) where open_food_facts_id is not null;
create index if not exists idx_foods_master_canonical_name on public.foods_master(canonical_name);
create index if not exists idx_foods_master_food_type on public.foods_master(food_type);
create index if not exists idx_foods_master_verification_status on public.foods_master(verification_status);

create trigger trg_foods_master_updated_at
before update on public.foods_master
for each row execute function public.set_updated_at();

create table if not exists public.food_nutrition (
  id uuid primary key default gen_random_uuid(),
  food_id uuid not null references public.foods_master(id) on delete cascade,
  per_100g_calories numeric(10,3),
  per_100g_protein numeric(10,3),
  per_100g_carbs numeric(10,3),
  per_100g_fat numeric(10,3),
  per_100g_fiber numeric(10,3),
  per_100g_sugar numeric(10,3),
  per_100g_sodium numeric(10,3),
  micronutrients_json jsonb,
  validated_by text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint food_nutrition_food_unique unique (food_id),
  constraint food_nutrition_non_negative_chk check (
    (per_100g_calories is null or per_100g_calories >= 0) and
    (per_100g_protein is null or per_100g_protein >= 0) and
    (per_100g_carbs is null or per_100g_carbs >= 0) and
    (per_100g_fat is null or per_100g_fat >= 0) and
    (per_100g_fiber is null or per_100g_fiber >= 0) and
    (per_100g_sugar is null or per_100g_sugar >= 0) and
    (per_100g_sodium is null or per_100g_sodium >= 0)
  )
);

create index if not exists idx_food_nutrition_food_id on public.food_nutrition(food_id);

create trigger trg_food_nutrition_updated_at
before update on public.food_nutrition
for each row execute function public.set_updated_at();

create table if not exists public.pantry_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  canonical_food_id uuid references public.foods_master(id) on delete set null,
  ingredient_name_raw text not null,
  ingredient_name_normalized text,
  quantity numeric(10,3) not null,
  unit text not null,
  expiry_date date,
  source text not null default 'manual',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint pantry_items_quantity_chk check (quantity > 0)
);

create index if not exists idx_pantry_items_user_id on public.pantry_items(user_id);
create index if not exists idx_pantry_items_user_expiry on public.pantry_items(user_id, expiry_date);
create index if not exists idx_pantry_items_canonical_food_id on public.pantry_items(canonical_food_id);
create index if not exists idx_pantry_items_name_normalized on public.pantry_items(ingredient_name_normalized);

create trigger trg_pantry_items_updated_at
before update on public.pantry_items
for each row execute function public.set_updated_at();

create table if not exists public.recipes (
  id uuid primary key default gen_random_uuid(),
  source_provider text not null,
  external_recipe_id text,
  title text not null,
  image_url text,
  source_url text,
  summary text,
  cuisine text,
  meal_type text,
  prep_time_minutes int,
  cook_time_minutes int,
  total_time_minutes int,
  servings numeric(10,3),
  dietary_tags text[] not null default '{}',
  health_labels text[] not null default '{}',
  confidence_score numeric(5,4),
  estimation_flag boolean not null default false,
  verification_status text not null default 'provider_reported',
  source_payload_hash text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint recipes_time_non_negative_chk check (
    (prep_time_minutes is null or prep_time_minutes >= 0) and
    (cook_time_minutes is null or cook_time_minutes >= 0) and
    (total_time_minutes is null or total_time_minutes >= 0)
  ),
  constraint recipes_servings_chk check (servings is null or servings > 0),
  constraint recipes_confidence_chk check (confidence_score is null or (confidence_score >= 0 and confidence_score <= 1)),
  constraint recipes_verification_status_chk check (
    verification_status in (
      'provider_reported',
      'validated_with_usda',
      'user_confirmed',
      'estimated_from_image',
      'partially_estimated'
    )
  )
);

create unique index if not exists uq_recipes_provider_external_id
on public.recipes(source_provider, external_recipe_id)
where external_recipe_id is not null;
create index if not exists idx_recipes_source_provider on public.recipes(source_provider);
create index if not exists idx_recipes_title on public.recipes(title);
create index if not exists idx_recipes_cuisine on public.recipes(cuisine);
create index if not exists idx_recipes_total_time on public.recipes(total_time_minutes);

create trigger trg_recipes_updated_at
before update on public.recipes
for each row execute function public.set_updated_at();

create table if not exists public.recipe_ingredients (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null references public.recipes(id) on delete cascade,
  canonical_food_id uuid references public.foods_master(id) on delete set null,
  ingredient_name_raw text not null,
  ingredient_name_normalized text,
  quantity numeric(10,3),
  unit text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint recipe_ingredients_quantity_chk check (quantity is null or quantity > 0)
);

create index if not exists idx_recipe_ingredients_recipe_id on public.recipe_ingredients(recipe_id);
create index if not exists idx_recipe_ingredients_canonical_food_id on public.recipe_ingredients(canonical_food_id);
create index if not exists idx_recipe_ingredients_name_normalized on public.recipe_ingredients(ingredient_name_normalized);

create trigger trg_recipe_ingredients_updated_at
before update on public.recipe_ingredients
for each row execute function public.set_updated_at();

create table if not exists public.recipe_nutrition (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null unique references public.recipes(id) on delete cascade,
  calories numeric(10,3),
  protein numeric(10,3),
  carbs numeric(10,3),
  fat numeric(10,3),
  fiber numeric(10,3),
  sugar numeric(10,3),
  sodium numeric(10,3),
  validation_status text not null default 'provider_reported',
  source_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint recipe_nutrition_non_negative_chk check (
    (calories is null or calories >= 0) and
    (protein is null or protein >= 0) and
    (carbs is null or carbs >= 0) and
    (fat is null or fat >= 0) and
    (fiber is null or fiber >= 0) and
    (sugar is null or sugar >= 0) and
    (sodium is null or sodium >= 0)
  )
);

create index if not exists idx_recipe_nutrition_recipe_id on public.recipe_nutrition(recipe_id);

create trigger trg_recipe_nutrition_updated_at
before update on public.recipe_nutrition
for each row execute function public.set_updated_at();

create table if not exists public.saved_recipes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  recipe_id uuid not null references public.recipes(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint saved_recipes_user_recipe_unique unique (user_id, recipe_id)
);

create index if not exists idx_saved_recipes_user_id on public.saved_recipes(user_id);
create index if not exists idx_saved_recipes_recipe_id on public.saved_recipes(recipe_id);

alter table public.foods_master enable row level security;
alter table public.food_nutrition enable row level security;
alter table public.pantry_items enable row level security;
alter table public.recipes enable row level security;
alter table public.recipe_ingredients enable row level security;
alter table public.recipe_nutrition enable row level security;
alter table public.saved_recipes enable row level security;

-- Canonical foods and recipe catalog can be read by authenticated users.
create policy foods_master_select_auth on public.foods_master
for select using (auth.role() = 'authenticated');

create policy food_nutrition_select_auth on public.food_nutrition
for select using (auth.role() = 'authenticated');

create policy recipes_select_auth on public.recipes
for select using (auth.role() = 'authenticated');

create policy recipe_ingredients_select_auth on public.recipe_ingredients
for select using (auth.role() = 'authenticated');

create policy recipe_nutrition_select_auth on public.recipe_nutrition
for select using (auth.role() = 'authenticated');

-- Mutation is backend-only.
create policy foods_master_write_service on public.foods_master
for all using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

create policy food_nutrition_write_service on public.food_nutrition
for all using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

create policy recipes_write_service on public.recipes
for all using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

create policy recipe_ingredients_write_service on public.recipe_ingredients
for all using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

create policy recipe_nutrition_write_service on public.recipe_nutrition
for all using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

create policy pantry_items_select_own on public.pantry_items
for select using (auth.uid() = user_id);

create policy pantry_items_insert_own on public.pantry_items
for insert with check (auth.uid() = user_id);

create policy pantry_items_update_own on public.pantry_items
for update using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy pantry_items_delete_own on public.pantry_items
for delete using (auth.uid() = user_id);

create policy saved_recipes_select_own on public.saved_recipes
for select using (auth.uid() = user_id);

create policy saved_recipes_insert_own on public.saved_recipes
for insert with check (auth.uid() = user_id);

create policy saved_recipes_delete_own on public.saved_recipes
for delete using (auth.uid() = user_id);
