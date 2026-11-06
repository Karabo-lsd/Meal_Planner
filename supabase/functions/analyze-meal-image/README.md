# analyze-meal-image

Supabase Edge Function used by the Flutter app via:

- `supabase.functions.invoke('analyze-meal-image', body: {...})`

## Deploy

Run from project root:

```bash
supabase functions deploy analyze-meal-image --no-verify-jwt=false
```

## Local test

```bash
supabase functions serve analyze-meal-image
```

Then call with:

```json
{
  "filename": "chicken_bowl.jpg",
  "image_base64": "..."
}
```

## Current behavior

- Extracts keywords from filename.
- Looks up `foods_master` with authenticated RLS context.
- Returns nutrition from `food_nutrition` in the app-compatible response shape.
- Returns zeroed fallback if no match is found.

## Note

This is a lightweight catalog-based analyzer and not a full CV model. You can later replace the internals with a true ML/Vision provider while keeping the same response schema.
