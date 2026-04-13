# Supabase + FastAPI Architecture Blueprint

## 1) Project Structure (proposed, incremental)

```
system/
  lib/
    core/
      config/
      models/
      networking/
      contracts/
    features/
      auth/
      profile/
      pantry/
      recipes/
      meal_plan/
      barcode/
      image_scan/
      food_logs/
      grocery/
      ai_assistant/
    services/
      supabase_client_service.dart
      meal_intelligence_service.dart
      image_upload_service.dart

  backend/
    meal_planning/
      main.py
      routers/
        profile.py
        pantry.py
        recipes.py
        meal_plans.py
        food_logs.py
        barcode.py
        image_scans.py
        ai_assistant.py
      schemas/
        canonical.py
        meal_intelligence.py
        provider_contracts.py
      services/
        providers/
          spoonacular_client.py
          edamam_client.py
          usda_client.py
          open_food_facts_client.py
          image_recognition_client.py
          interfaces.py
        normalization/
          canonical_food_mapper.py
          canonical_recipe_mapper.py
        ranking/
          recipe_ranker.py
        planning/
          weekly_planner.py
          grocery_generator.py
        scans/
          image_scan_pipeline.py
          barcode_pipeline.py
        ai/
          explanation_service.py
        cache/
          cache_service.py
        telemetry/
          logger.py

  supabase/
    migrations/
      202603100001_core_identity_profile.sql
      202603100002_foods_recipes_pantry.sql
      202603100003_plans_logs_scans_ai.sql
```

## 2) Provider responsibilities
- Spoonacular: ingredient-to-recipe discovery, pantry utilization, recipe alternatives.
- Edamam: diet-compliance filtering, nutrition-rich candidate retrieval.
- USDA FDC: authoritative nutrition validation and canonical nutrient grounding.
- Open Food Facts: barcode product lookup and ingredients for packaged goods.
- Image recognition provider: label + confidence + optional portion estimate extraction.

## 3) Canonical model ownership
- Frontend never consumes raw provider payloads.
- FastAPI returns only app-owned normalized contracts.
- Canonical food and recipe contracts include confidence, provenance, and estimation flags.

## 4) Ranking pipeline
Weighted final score in [0, 1]:
- ingredient_match_score: 0.24
- dietary_fit_score: 0.20
- calorie_fit_score: 0.14
- macro_fit_score: 0.14
- prep_time_score: 0.10
- user_preference_score: 0.10
- diversity_score: 0.06
- cost_score: 0.02 (only when cost data exists)

Rules:
- Hard fail any allergy violation.
- Penalize estimated nutrition if no USDA validation.
- Penalize repeated recipes in recent history.
- Include explanation metadata for each score term.

## 5) Ingredient-based suggestion flow (enforced)
1. Read profile/targets.
2. Read dietary preferences + allergies + exclusions.
3. Read pantry items.
4. Normalize pantry ingredients to canonical foods.
5. Query Spoonacular + Edamam.
6. Map to canonical recipes.
7. Deduplicate by normalized title + ingredient signature + source IDs.
8. Exclude violating recipes.
9. Validate/enrich nutrition via USDA.
10. Rank via weighted score.
11. Return canonical response + explanation metadata + partial-data flags.

## 6) Image scan flow (enforced)
1. Flutter uploads image to private `food-scans` bucket path:
   `<user_id>/<image_scan_id>/<timestamp>.jpg`.
2. Backend starts scan job and sets status `processing`.
3. Image provider returns labels + confidence + optional portion.
4. Backend maps labels to canonical foods.
5. Backend estimates nutrition with USDA-backed mappings.
6. Store scan, predictions, confidence, estimation flags, uncertainty note.
7. If confidence below threshold, set status `needs_review` and require user confirmation.
8. On confirm, mark predictions `is_user_confirmed=true`, recalculate totals, enable add-to-log.

## 7) Security and trust rules
- Provider API keys only in backend env.
- RLS on all user-owned tables.
- Storage bucket private with path-scoped object policies.
- Estimated values always carry `estimation_flag=true` and confidence values.
- AI layer consumes structured trusted backend records only.
- AI cannot invent numeric nutrition values.

## 8) Caching strategy
- Redis key classes:
  - `recipe_search:{hash}` TTL 30m
  - `nutrition_lookup:{canonical_food_id}` TTL 24h
  - `barcode:{barcode}` TTL 12h
  - `normalized_provider_payload:{provider}:{hash}` TTL 24h
- Never cache user-specific private records in shared keys.
- USDA validated nutrition can have longer TTL than community-source data.

## 9) Backward compatibility strategy
- Keep existing `/v1/auth`, `/v1/users`, `/v1/meals` endpoints untouched initially.
- Introduce new endpoints under `/v1/intelligence/*` and `/v1/scans/*`.
- Migrate Flutter screen-by-screen behind feature flags.
