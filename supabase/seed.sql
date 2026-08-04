-- Supabase seed data for local/remote bootstrap
-- Idempotent inserts using fixed UUIDs so reseeding is safe.

-- -----------------------------------------------------------------------------
-- Canonical foods
-- -----------------------------------------------------------------------------
insert into public.foods_master (
  id,
  canonical_name,
  aliases,
  food_category,
  food_type,
  default_serving_size,
  default_serving_unit,
  dietary_tags,
  verification_status
)
values
  ('11111111-1111-1111-1111-111111111111', 'Greek Yogurt', array['yogurt', 'plain yogurt'], 'dairy', 'ingredient', 170, 'g', array['high-protein', 'breakfast'], 'provider_reported'),
  ('22222222-2222-2222-2222-222222222222', 'Rolled Oats', array['oats', 'oatmeal'], 'grains', 'ingredient', 40, 'g', array['breakfast', 'whole-grain'], 'provider_reported'),
  ('33333333-3333-3333-3333-333333333333', 'Blueberries', array['berries', 'blue berry'], 'fruit', 'ingredient', 100, 'g', array['antioxidant', 'vegan'], 'provider_reported'),
  ('44444444-4444-4444-4444-444444444444', 'Chicken Breast', array['chicken'], 'protein', 'ingredient', 120, 'g', array['high-protein', 'low-carb'], 'provider_reported'),
  ('55555555-5555-5555-5555-555555555555', 'Quinoa', array['white quinoa', 'grain quinoa'], 'grains', 'ingredient', 100, 'g', array['gluten-free', 'vegan'], 'provider_reported'),
  ('66666666-6666-6666-6666-666666666666', 'Salmon Fillet', array['salmon'], 'protein', 'ingredient', 120, 'g', array['omega-3', 'high-protein'], 'provider_reported')
on conflict (id) do update
set
  canonical_name = excluded.canonical_name,
  aliases = excluded.aliases,
  food_category = excluded.food_category,
  food_type = excluded.food_type,
  default_serving_size = excluded.default_serving_size,
  default_serving_unit = excluded.default_serving_unit,
  dietary_tags = excluded.dietary_tags,
  verification_status = excluded.verification_status,
  updated_at = now();

-- -----------------------------------------------------------------------------
-- Food nutrition (per 100g)
-- -----------------------------------------------------------------------------
insert into public.food_nutrition (
  id,
  food_id,
  per_100g_calories,
  per_100g_protein,
  per_100g_carbs,
  per_100g_fat,
  per_100g_fiber,
  per_100g_sugar,
  per_100g_sodium,
  validated_by
)
values
  ('a1111111-1111-1111-1111-111111111111', '11111111-1111-1111-1111-111111111111', 59, 10.0, 3.6, 0.4, 0.0, 3.2, 36, 'seed'),
  ('a2222222-2222-2222-2222-222222222222', '22222222-2222-2222-2222-222222222222', 389, 16.9, 66.3, 6.9, 10.6, 0.9, 2, 'seed'),
  ('a3333333-3333-3333-3333-333333333333', '33333333-3333-3333-3333-333333333333', 57, 0.7, 14.5, 0.3, 2.4, 10.0, 1, 'seed'),
  ('a4444444-4444-4444-4444-444444444444', '44444444-4444-4444-4444-444444444444', 165, 31.0, 0.0, 3.6, 0.0, 0.0, 74, 'seed'),
  ('a5555555-5555-5555-5555-555555555555', '55555555-5555-5555-5555-555555555555', 120, 4.4, 21.3, 1.9, 2.8, 0.9, 7, 'seed'),
  ('a6666666-6666-6666-6666-666666666666', '66666666-6666-6666-6666-666666666666', 208, 20.4, 0.0, 13.4, 0.0, 0.0, 59, 'seed')
on conflict (food_id) do update
set
  per_100g_calories = excluded.per_100g_calories,
  per_100g_protein = excluded.per_100g_protein,
  per_100g_carbs = excluded.per_100g_carbs,
  per_100g_fat = excluded.per_100g_fat,
  per_100g_fiber = excluded.per_100g_fiber,
  per_100g_sugar = excluded.per_100g_sugar,
  per_100g_sodium = excluded.per_100g_sodium,
  validated_by = excluded.validated_by,
  updated_at = now();

-- -----------------------------------------------------------------------------
-- Recipe catalog
-- -----------------------------------------------------------------------------
insert into public.recipes (
  id,
  source_provider,
  external_recipe_id,
  title,
  summary,
  cuisine,
  meal_type,
  prep_time_minutes,
  cook_time_minutes,
  total_time_minutes,
  servings,
  dietary_tags,
  verification_status
)
values
  ('77777777-7777-7777-7777-777777777777', 'seed', 'seed-greek-yogurt-bowl', 'Greek Yogurt Berry Bowl', 'Greek yogurt with oats and blueberries.', 'International', 'breakfast', 8, 0, 8, 1, array['high-protein', 'breakfast'], 'provider_reported'),
  ('88888888-8888-8888-8888-888888888888', 'seed', 'seed-chicken-quinoa', 'Chicken Quinoa Plate', 'Grilled chicken breast served over quinoa.', 'International', 'lunch', 15, 20, 35, 2, array['high-protein', 'meal-prep'], 'provider_reported'),
  ('99999999-9999-9999-9999-999999999999', 'seed', 'seed-salmon-bowl', 'Salmon Quinoa Bowl', 'Salmon fillet with quinoa and fresh berries.', 'International', 'dinner', 10, 18, 28, 2, array['omega-3', 'high-protein'], 'provider_reported')
on conflict (id) do update
set
  source_provider = excluded.source_provider,
  external_recipe_id = excluded.external_recipe_id,
  title = excluded.title,
  summary = excluded.summary,
  cuisine = excluded.cuisine,
  meal_type = excluded.meal_type,
  prep_time_minutes = excluded.prep_time_minutes,
  cook_time_minutes = excluded.cook_time_minutes,
  total_time_minutes = excluded.total_time_minutes,
  servings = excluded.servings,
  dietary_tags = excluded.dietary_tags,
  verification_status = excluded.verification_status,
  updated_at = now();

insert into public.recipe_nutrition (
  id,
  recipe_id,
  calories,
  protein,
  carbs,
  fat,
  fiber,
  sugar,
  sodium,
  validation_status,
  source_reference
)
values
  ('b7777777-7777-7777-7777-777777777777', '77777777-7777-7777-7777-777777777777', 410, 28, 43, 11, 8, 13, 85, 'provider_reported', 'seed'),
  ('b8888888-8888-8888-8888-888888888888', '88888888-8888-8888-8888-888888888888', 560, 46, 45, 17, 5, 3, 220, 'provider_reported', 'seed'),
  ('b9999999-9999-9999-9999-999999999999', '99999999-9999-9999-9999-999999999999', 610, 42, 40, 28, 6, 5, 190, 'provider_reported', 'seed')
on conflict (recipe_id) do update
set
  calories = excluded.calories,
  protein = excluded.protein,
  carbs = excluded.carbs,
  fat = excluded.fat,
  fiber = excluded.fiber,
  sugar = excluded.sugar,
  sodium = excluded.sodium,
  validation_status = excluded.validation_status,
  source_reference = excluded.source_reference,
  updated_at = now();

-- Reset ingredient rows for deterministic reseed.
delete from public.recipe_ingredients
where recipe_id in (
  '77777777-7777-7777-7777-777777777777',
  '88888888-8888-8888-8888-888888888888',
  '99999999-9999-9999-9999-999999999999'
);

insert into public.recipe_ingredients (
  id,
  recipe_id,
  canonical_food_id,
  ingredient_name_raw,
  ingredient_name_normalized,
  quantity,
  unit
)
values
  ('c1000000-0000-0000-0000-000000000001', '77777777-7777-7777-7777-777777777777', '11111111-1111-1111-1111-111111111111', 'Greek Yogurt', 'greek yogurt', 170, 'g'),
  ('c1000000-0000-0000-0000-000000000002', '77777777-7777-7777-7777-777777777777', '22222222-2222-2222-2222-222222222222', 'Rolled Oats', 'rolled oats', 40, 'g'),
  ('c1000000-0000-0000-0000-000000000003', '77777777-7777-7777-7777-777777777777', '33333333-3333-3333-3333-333333333333', 'Blueberries', 'blueberries', 100, 'g'),
  ('c1000000-0000-0000-0000-000000000004', '88888888-8888-8888-8888-888888888888', '44444444-4444-4444-4444-444444444444', 'Chicken Breast', 'chicken breast', 240, 'g'),
  ('c1000000-0000-0000-0000-000000000005', '88888888-8888-8888-8888-888888888888', '55555555-5555-5555-5555-555555555555', 'Quinoa', 'quinoa', 200, 'g'),
  ('c1000000-0000-0000-0000-000000000006', '99999999-9999-9999-9999-999999999999', '66666666-6666-6666-6666-666666666666', 'Salmon Fillet', 'salmon fillet', 240, 'g'),
  ('c1000000-0000-0000-0000-000000000007', '99999999-9999-9999-9999-999999999999', '55555555-5555-5555-5555-555555555555', 'Quinoa', 'quinoa', 200, 'g'),
  ('c1000000-0000-0000-0000-000000000008', '99999999-9999-9999-9999-999999999999', '33333333-3333-3333-3333-333333333333', 'Blueberries', 'blueberries', 60, 'g')
on conflict (id) do update
set
  recipe_id = excluded.recipe_id,
  canonical_food_id = excluded.canonical_food_id,
  ingredient_name_raw = excluded.ingredient_name_raw,
  ingredient_name_normalized = excluded.ingredient_name_normalized,
  quantity = excluded.quantity,
  unit = excluded.unit,
  updated_at = now();
