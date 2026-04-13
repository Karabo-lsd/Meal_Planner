-- Phase 5/6/7/8 schema: planning, logging, scans, AI logs, and storage policies.

create table if not exists public.meal_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  start_date date not null,
  end_date date not null,
  calorie_target numeric(10,3),
  protein_target numeric(10,3),
  carb_target numeric(10,3),
  fat_target numeric(10,3),
  generated_by text not null default 'rule_engine',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint meal_plans_date_range_chk check (end_date >= start_date),
  constraint meal_plans_targets_chk check (
    (calorie_target is null or calorie_target > 0) and
    (protein_target is null or protein_target >= 0) and
    (carb_target is null or carb_target >= 0) and
    (fat_target is null or fat_target >= 0)
  )
);

create index if not exists idx_meal_plans_user_id on public.meal_plans(user_id);
create index if not exists idx_meal_plans_user_dates on public.meal_plans(user_id, start_date, end_date);

create trigger trg_meal_plans_updated_at
before update on public.meal_plans
for each row execute function public.set_updated_at();

create table if not exists public.meal_plan_items (
  id uuid primary key default gen_random_uuid(),
  meal_plan_id uuid not null references public.meal_plans(id) on delete cascade,
  plan_date date not null,
  meal_slot text not null,
  recipe_id uuid references public.recipes(id) on delete set null,
  canonical_food_id uuid references public.foods_master(id) on delete set null,
  portion_multiplier numeric(10,3) not null default 1,
  calories_estimate numeric(10,3),
  protein_estimate numeric(10,3),
  carbs_estimate numeric(10,3),
  fat_estimate numeric(10,3),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint meal_plan_items_slot_chk check (meal_slot in ('breakfast', 'lunch', 'dinner', 'snack')),
  constraint meal_plan_items_portion_chk check (portion_multiplier > 0),
  constraint meal_plan_items_food_or_recipe_chk check (
    recipe_id is not null or canonical_food_id is not null
  )
);

create index if not exists idx_meal_plan_items_plan_id on public.meal_plan_items(meal_plan_id);
create index if not exists idx_meal_plan_items_plan_date on public.meal_plan_items(plan_date);

create trigger trg_meal_plan_items_updated_at
before update on public.meal_plan_items
for each row execute function public.set_updated_at();

create table if not exists public.food_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  log_date date not null,
  meal_slot text not null,
  canonical_food_id uuid references public.foods_master(id) on delete set null,
  recipe_id uuid references public.recipes(id) on delete set null,
  source text not null,
  quantity numeric(10,3),
  unit text,
  calories numeric(10,3),
  protein numeric(10,3),
  carbs numeric(10,3),
  fat numeric(10,3),
  confidence_score numeric(5,4),
  estimation_flag boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint food_logs_slot_chk check (meal_slot in ('breakfast', 'lunch', 'dinner', 'snack')),
  constraint food_logs_source_chk check (source in ('manual', 'recipe', 'barcode', 'image_scan', 'imported')),
  constraint food_logs_quantity_chk check (quantity is null or quantity > 0),
  constraint food_logs_confidence_chk check (confidence_score is null or (confidence_score >= 0 and confidence_score <= 1)),
  constraint food_logs_non_negative_nutrition_chk check (
    (calories is null or calories >= 0) and
    (protein is null or protein >= 0) and
    (carbs is null or carbs >= 0) and
    (fat is null or fat >= 0)
  ),
  constraint food_logs_food_or_recipe_chk check (
    canonical_food_id is not null or recipe_id is not null
  )
);

create index if not exists idx_food_logs_user_date on public.food_logs(user_id, log_date);
create index if not exists idx_food_logs_user_slot on public.food_logs(user_id, meal_slot);

create trigger trg_food_logs_updated_at
before update on public.food_logs
for each row execute function public.set_updated_at();

create table if not exists public.grocery_lists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  meal_plan_id uuid references public.meal_plans(id) on delete set null,
  title text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_grocery_lists_user_id on public.grocery_lists(user_id);
create index if not exists idx_grocery_lists_meal_plan_id on public.grocery_lists(meal_plan_id);

create trigger trg_grocery_lists_updated_at
before update on public.grocery_lists
for each row execute function public.set_updated_at();

create table if not exists public.grocery_list_items (
  id uuid primary key default gen_random_uuid(),
  grocery_list_id uuid not null references public.grocery_lists(id) on delete cascade,
  canonical_food_id uuid references public.foods_master(id) on delete set null,
  item_name text not null,
  quantity numeric(10,3),
  unit text,
  checked boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint grocery_list_items_quantity_chk check (quantity is null or quantity > 0)
);

create index if not exists idx_grocery_list_items_list_id on public.grocery_list_items(grocery_list_id);

create trigger trg_grocery_list_items_updated_at
before update on public.grocery_list_items
for each row execute function public.set_updated_at();

create table if not exists public.barcode_scans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  barcode_value text not null,
  open_food_facts_product_id text,
  canonical_food_id uuid references public.foods_master(id) on delete set null,
  raw_response_json jsonb not null,
  source_reliability text not null default 'community_unverified',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint barcode_scans_barcode_format_chk check (barcode_value ~ '^[0-9]{8,14}$'),
  constraint barcode_scans_reliability_chk check (
    source_reliability in ('community_unverified', 'provider_reported', 'validated_with_usda')
  )
);

create index if not exists idx_barcode_scans_user_id on public.barcode_scans(user_id);
create index if not exists idx_barcode_scans_barcode_value on public.barcode_scans(barcode_value);

create trigger trg_barcode_scans_updated_at
before update on public.barcode_scans
for each row execute function public.set_updated_at();

create table if not exists public.image_scans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  storage_path text not null,
  image_url text,
  scan_status text not null default 'pending',
  scan_type text not null default 'plate_food',
  overall_confidence numeric(5,4),
  portion_confidence numeric(5,4),
  estimation_flag boolean not null default true,
  notes text,
  provider_raw_response jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint image_scans_status_chk check (scan_status in ('pending', 'processing', 'completed', 'failed', 'needs_review', 'confirmed')),
  constraint image_scans_type_chk check (scan_type in ('plate_food', 'packaged_food_label')),
  constraint image_scans_overall_confidence_chk check (overall_confidence is null or (overall_confidence >= 0 and overall_confidence <= 1)),
  constraint image_scans_portion_confidence_chk check (portion_confidence is null or (portion_confidence >= 0 and portion_confidence <= 1))
);

create index if not exists idx_image_scans_user_id on public.image_scans(user_id);
create index if not exists idx_image_scans_user_status on public.image_scans(user_id, scan_status);

create trigger trg_image_scans_updated_at
before update on public.image_scans
for each row execute function public.set_updated_at();

create table if not exists public.image_scan_predictions (
  id uuid primary key default gen_random_uuid(),
  image_scan_id uuid not null references public.image_scans(id) on delete cascade,
  predicted_label text not null,
  canonical_food_id uuid references public.foods_master(id) on delete set null,
  confidence_score numeric(5,4) not null,
  portion_estimate numeric(10,3),
  portion_unit text,
  portion_confidence numeric(5,4),
  calories_estimate numeric(10,3),
  protein_estimate numeric(10,3),
  carbs_estimate numeric(10,3),
  fat_estimate numeric(10,3),
  estimation_flag boolean not null default true,
  uncertainty_note text,
  is_user_confirmed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint image_scan_predictions_confidence_chk check (confidence_score >= 0 and confidence_score <= 1),
  constraint image_scan_predictions_portion_confidence_chk check (portion_confidence is null or (portion_confidence >= 0 and portion_confidence <= 1)),
  constraint image_scan_predictions_non_negative_chk check (
    (portion_estimate is null or portion_estimate > 0) and
    (calories_estimate is null or calories_estimate >= 0) and
    (protein_estimate is null or protein_estimate >= 0) and
    (carbs_estimate is null or carbs_estimate >= 0) and
    (fat_estimate is null or fat_estimate >= 0)
  )
);

create index if not exists idx_image_scan_predictions_scan_id on public.image_scan_predictions(image_scan_id);
create index if not exists idx_image_scan_predictions_food_id on public.image_scan_predictions(canonical_food_id);

create trigger trg_image_scan_predictions_updated_at
before update on public.image_scan_predictions
for each row execute function public.set_updated_at();

create table if not exists public.ai_recommendation_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  request_type text not null,
  prompt_summary text,
  structured_input_json jsonb not null,
  structured_output_json jsonb not null,
  created_at timestamptz not null default now(),
  constraint ai_recommendation_logs_request_type_chk check (
    request_type in ('meal_recommendation', 'substitution', 'meal_plan_summary', 'nutrition_explanation', 'scan_explanation')
  )
);

create index if not exists idx_ai_recommendation_logs_user_id on public.ai_recommendation_logs(user_id);
create index if not exists idx_ai_recommendation_logs_request_type on public.ai_recommendation_logs(request_type);
create index if not exists idx_ai_recommendation_logs_created_at on public.ai_recommendation_logs(created_at);

alter table public.meal_plans enable row level security;
alter table public.meal_plan_items enable row level security;
alter table public.food_logs enable row level security;
alter table public.grocery_lists enable row level security;
alter table public.grocery_list_items enable row level security;
alter table public.barcode_scans enable row level security;
alter table public.image_scans enable row level security;
alter table public.image_scan_predictions enable row level security;
alter table public.ai_recommendation_logs enable row level security;

create policy meal_plans_select_own on public.meal_plans
for select using (auth.uid() = user_id);
create policy meal_plans_insert_own on public.meal_plans
for insert with check (auth.uid() = user_id);
create policy meal_plans_update_own on public.meal_plans
for update using (auth.uid() = user_id)
with check (auth.uid() = user_id);
create policy meal_plans_delete_own on public.meal_plans
for delete using (auth.uid() = user_id);

create policy meal_plan_items_select_own on public.meal_plan_items
for select using (
  exists (
    select 1 from public.meal_plans mp
    where mp.id = meal_plan_items.meal_plan_id and mp.user_id = auth.uid()
  )
);
create policy meal_plan_items_insert_own on public.meal_plan_items
for insert with check (
  exists (
    select 1 from public.meal_plans mp
    where mp.id = meal_plan_items.meal_plan_id and mp.user_id = auth.uid()
  )
);
create policy meal_plan_items_update_own on public.meal_plan_items
for update using (
  exists (
    select 1 from public.meal_plans mp
    where mp.id = meal_plan_items.meal_plan_id and mp.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.meal_plans mp
    where mp.id = meal_plan_items.meal_plan_id and mp.user_id = auth.uid()
  )
);
create policy meal_plan_items_delete_own on public.meal_plan_items
for delete using (
  exists (
    select 1 from public.meal_plans mp
    where mp.id = meal_plan_items.meal_plan_id and mp.user_id = auth.uid()
  )
);

create policy food_logs_select_own on public.food_logs
for select using (auth.uid() = user_id);
create policy food_logs_insert_own on public.food_logs
for insert with check (auth.uid() = user_id);
create policy food_logs_update_own on public.food_logs
for update using (auth.uid() = user_id)
with check (auth.uid() = user_id);
create policy food_logs_delete_own on public.food_logs
for delete using (auth.uid() = user_id);

create policy grocery_lists_select_own on public.grocery_lists
for select using (auth.uid() = user_id);
create policy grocery_lists_insert_own on public.grocery_lists
for insert with check (auth.uid() = user_id);
create policy grocery_lists_update_own on public.grocery_lists
for update using (auth.uid() = user_id)
with check (auth.uid() = user_id);
create policy grocery_lists_delete_own on public.grocery_lists
for delete using (auth.uid() = user_id);

create policy grocery_list_items_select_own on public.grocery_list_items
for select using (
  exists (
    select 1 from public.grocery_lists gl
    where gl.id = grocery_list_items.grocery_list_id and gl.user_id = auth.uid()
  )
);
create policy grocery_list_items_insert_own on public.grocery_list_items
for insert with check (
  exists (
    select 1 from public.grocery_lists gl
    where gl.id = grocery_list_items.grocery_list_id and gl.user_id = auth.uid()
  )
);
create policy grocery_list_items_update_own on public.grocery_list_items
for update using (
  exists (
    select 1 from public.grocery_lists gl
    where gl.id = grocery_list_items.grocery_list_id and gl.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.grocery_lists gl
    where gl.id = grocery_list_items.grocery_list_id and gl.user_id = auth.uid()
  )
);
create policy grocery_list_items_delete_own on public.grocery_list_items
for delete using (
  exists (
    select 1 from public.grocery_lists gl
    where gl.id = grocery_list_items.grocery_list_id and gl.user_id = auth.uid()
  )
);

create policy barcode_scans_select_own on public.barcode_scans
for select using (auth.uid() = user_id);
create policy barcode_scans_insert_own on public.barcode_scans
for insert with check (auth.uid() = user_id);

create policy image_scans_select_own on public.image_scans
for select using (auth.uid() = user_id);
create policy image_scans_insert_own on public.image_scans
for insert with check (auth.uid() = user_id);
create policy image_scans_update_own on public.image_scans
for update using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy image_scan_predictions_select_own on public.image_scan_predictions
for select using (
  exists (
    select 1 from public.image_scans s
    where s.id = image_scan_predictions.image_scan_id and s.user_id = auth.uid()
  )
);
create policy image_scan_predictions_insert_own on public.image_scan_predictions
for insert with check (
  exists (
    select 1 from public.image_scans s
    where s.id = image_scan_predictions.image_scan_id and s.user_id = auth.uid()
  )
);
create policy image_scan_predictions_update_own on public.image_scan_predictions
for update using (
  exists (
    select 1 from public.image_scans s
    where s.id = image_scan_predictions.image_scan_id and s.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from public.image_scans s
    where s.id = image_scan_predictions.image_scan_id and s.user_id = auth.uid()
  )
);

create policy ai_recommendation_logs_select_own on public.ai_recommendation_logs
for select using (auth.uid() = user_id);
create policy ai_recommendation_logs_insert_own on public.ai_recommendation_logs
for insert with check (auth.uid() = user_id);

-- Private bucket for food scan images.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'food-scans',
  'food-scans',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

create policy storage_food_scans_select_own on storage.objects
for select using (
  bucket_id = 'food-scans'
  and auth.uid()::text = (storage.foldername(name))[1]
);

create policy storage_food_scans_insert_own on storage.objects
for insert with check (
  bucket_id = 'food-scans'
  and auth.uid()::text = (storage.foldername(name))[1]
);

create policy storage_food_scans_update_own on storage.objects
for update using (
  bucket_id = 'food-scans'
  and auth.uid()::text = (storage.foldername(name))[1]
)
with check (
  bucket_id = 'food-scans'
  and auth.uid()::text = (storage.foldername(name))[1]
);

create policy storage_food_scans_delete_own on storage.objects
for delete using (
  bucket_id = 'food-scans'
  and auth.uid()::text = (storage.foldername(name))[1]
);
