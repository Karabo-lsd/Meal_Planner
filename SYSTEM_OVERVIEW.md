# Smart Meal Planner — System Overview



---

## 1. The 30-second pitch

> A **Flutter** mobile app talks to **Supabase** (login, database, file storage) for most things, and to our own **Python FastAPI backend** for the AI features. The backend reads the user's profile from Supabase, finds real recipes, and asks **OpenAI** to *rank and explain* them — never to invent them. Every user's data is locked to them with **Row Level Security**.

---

## 2. Architecture

```
┌────────────────────────────┐
│  Flutter app (lib/)        │  Android / iOS / Web / Desktop
│  Riverpod + Dio + Hive     │
└───────┬────────────┬───────┘
        │            │
        │ (A) Supabase SDK            (B) HTTPS + Supabase JWT
        │ auth, tables, storage,      /api/recommendations, /api/chat,
        │ edge functions              /api/meal-plans/generate, /api/recipes/{id}/details
        ▼                             ▼
┌──────────────────────┐     ┌──────────────────────────────┐
│ Supabase             │◄────│ FastAPI backend (backend/)   │
│ • Auth (JWT)         │ (C) │ • verifies JWT via Supabase  │
│ • Postgres + RLS     │ REST│ • loads user context         │
│ • Storage            │     │ • builds candidate recipes   │
│ • Edge Function      │     │ • validates AI output        │
└──────────────────────┘     └───────┬──────────────┬───────┘
                                     │ (D)          │ (E)
                                     ▼              ▼
                               OpenAI API      Spoonacular API
                          (rank / plan / chat) (extra recipes, details)
```

**Two paths from the app:**
- **(A) Direct to Supabase** — the everyday CRUD: profile, pantry, food logs, saved recipes, meal plans. Safe because RLS enforces ownership in the database.
- **(B) Through our backend** — anything needing AI or heavy logic. The backend is the only place that holds the OpenAI key and Supabase service key.

---

## 3. Tech stack

| Layer | Technology |
|---|---|
| Mobile/web client | Flutter (Dart SDK ^3.11), Material, `google_fonts`, `fl_chart` |
| State management | `flutter_riverpod` |
| Networking | `dio` (+ retry & auth interceptors), `supabase_flutter` |
| Local storage | `hive` (session/tab cache), `.env` via `flutter_dotenv` |
| Device features | `camera`, `image_picker`, `speech_to_text`, `local_auth`, `google_sign_in`, `sign_in_with_apple` |
| Backend | Python, **FastAPI**, Uvicorn, Pydantic v2, SQLAlchemy 2, `httpx`, `openai` SDK |
| Cloud platform | **Supabase** (Postgres, Auth, Storage, Edge Functions in Deno/TypeScript) |
| AI | **OpenAI** (default model `gpt-4.1-mini`, configurable) |
| Recipe data | Own Supabase catalog + **Spoonacular** API |
| Deploy tooling | Dockerfile, docker-compose, Kubernetes manifest (`backend/k8s`) |
| Tests | `pytest` (backend), `flutter_test` (app) |

---

## 4. Authentication

**What we use: Supabase Auth.**

- Sign-up / sign-in: email + password via `supabase.auth` ([auth_service.dart](lib/services/auth_service.dart)). Google and Apple OAuth methods are also wired in.
- Email confirmation returns to the app via `mealplanner://auth-callback`; after Supabase confirms the account, the app shows an email-verified screen. Add this exact URI to the Supabase project's **Authentication → URL Configuration → Redirect URLs** allowlist.
- On success Supabase issues a **JWT access token**; the SDK stores and refreshes it.
- **App routing** ([main.dart](lib/main.dart)): `AuthGate` → signed out = `LoginScreen`; signed in = `_ProfileGate` → onboarding until profile is complete, then `MainScreen`.
- **Calling our backend:** a Dio interceptor ([api_client.dart](lib/services/api_client.dart)) attaches the Supabase JWT to every request, and on a `401` refreshes the session and retries.
- **Backend verification** ([dependencies.py](backend/meal_planning/routers/dependencies.py)): `get_supabase_user_id` forwards the token to Supabase `/auth/v1/user` and gets back the real user id.
- **Ownership check:** AI endpoints compare the `user_id` in the request body with the verified id; mismatch → `403`. A user cannot ask for someone else's data.

---

## 5. Database & data protection

**Database: Supabase Postgres** (schema in [supabase/migrations](supabase/migrations)).

| Group | Tables |
|---|---|
| Identity & profile | `users` (synced from auth by trigger), `user_profiles` (goal, age, weight, height, activity, calorie/macro targets), `dietary_preferences` (diet, allergies, exclusions, cuisines) |
| Food & recipes | `foods_master`, `food_nutrition`, `recipes`, `recipe_ingredients`, `recipe_nutrition`, `saved_recipes`, `pantry_items` |
| Planning & tracking | `meal_plans`, `meal_plan_items`, `food_logs`, `grocery_lists`, `grocery_list_items` |
| Scans & AI | `image_scans`, `image_scan_predictions`, `ai_recommendation_logs` |

**How user data is protected**
1. **Row Level Security is enabled on every table.** Personal tables have `*_own` policies: users can only select/insert/update/delete rows where `user_id = auth.uid()`.
2. **Shared catalogs** (`foods_master`, `recipes`, nutrition) are read-only for signed-in users; only the service role can write.
3. **Private storage bucket** `food-scans`: policies restrict each user to their own folder (`auth.uid()` = first path segment).
4. **Separate environment files:** the repository-root `.env` is for Flutter and contains only `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `API_BASE_URL`. `backend/.env` is for FastAPI and contains the Supabase service key and OpenAI/Spoonacular API keys.
5. **Passwords** are handled by Supabase Auth (never stored by our app).
6. **Minimised AI exposure:** only a whitelist of fields (`_prompt_context`) goes to OpenAI — goal, targets, diet, allergies, pantry, etc. **No email, name, or user id.**

**What we do with user data (purpose)**
- Personalise recommendations, meal plans and chat answers (goals, allergies, pantry, remaining calories).
- Track nutrition progress (food logs → dashboard/analytics).
- Never used to train models by us; sent to OpenAI only as request context.

---

## 6. Backend (FastAPI) — [backend/meal_planning](backend/meal_planning)

```
main.py            app setup, CORS, router registration, /health
config.py          settings from backend/.env (absolute path)
database.py        SQLAlchemy engine (SQLite fallback at backend/meal_planning.db)
routers/           HTTP endpoints (one file per feature)
schemas/           Pydantic request/response shapes
models/            SQLAlchemy tables (legacy local DB)
services/          business logic
  openai_service.py        all OpenAI calls
  recommendation_service.py candidate search, validation, fallbacks, plan building
  supabase_context.py      reads profile/diet/pantry from Supabase
  recipe_store.py          saves recipes & plans back to Supabase
  recipe_details.py        steps/ingredients/nutrition for a recipe
```

### Endpoints

**Used by the app (Supabase-JWT protected):**

| Method | Path | Purpose |
|---|---|---|
| POST | `/api/recommendations` | Top recipe picks for a request type (breakfast/dinner/search…) |
| POST | `/api/chat` | Grounded nutrition/meal assistant |
| POST | `/api/meal-plans/generate` | Build (and save) a multi-day plan |
| GET | `/api/recipes/{id}/details` | Instructions, exact ingredients, nutrition |
| GET | `/health`, `/` | Health check |

All `/api/*` routes require a valid Supabase access token. `/` and `/health` are public.

---

## 7. How OpenAI fits in

OpenAI is the **ranking & explanation brain**, not the data source. Code: [openai_service.py](backend/meal_planning/services/openai_service.py).

**Flow for a recommendation / plan / chat:**
1. App sends request → backend verifies JWT and ownership.
2. Backend loads trusted user context from Supabase (server data wins over client data).
3. Backend collects recipes from the Supabase catalog, local SQLite fallback, and Spoonacular when the catalog lacks enough nutrition-complete candidates. It excludes catalog rows marked `source_provider=seed` and filters allergens/excluded ingredients.
4. Candidates + whitelisted context go to OpenAI with strict rules: *use only these recipes, never invent IDs or nutrition values, respect allergies, answer in JSON.*
5. Backend **validates** the reply: every `recipe_id` must exist in the candidate list; anything else is discarded.
6. Chosen recipes are stored in Supabase (so they get saveable IDs), and plans are saved to `meal_plans`.
7. Response includes `source: "openai"` or `"fallback"`.

**Three OpenAI jobs:** `rank_candidates` (recommendations), `generate_meal_plan`, `chat`.

**Safety/reliability:** 20s timeout, 1 retry, JSON-only output, if no API key or any failure → **rule-based fallback** so the app still works.

**Not OpenAI:** food-photo scanning. The `analyze-meal-image` Edge Function currently matches filename keywords against `foods_master` — it is not a vision model.

---

## 8. Flutter app structure — [lib/](lib)

| Folder | Why it exists |
|---|---|
| `core/` | App-wide pieces: `providers.dart` (Riverpod state), `models/`, `theme/`, `config/app_config.dart` (API URLs, timeouts), `constants/`, onboarding logic |
| `services/` | Talks to Supabase tables and the backend API. |
| `features/` | One folder per product area (screens) |
| `shared/widgets/` | Reusable UI: buttons, text inputs, glass panel, loader |

**Screens**

| Screen | Purpose |
|---|---|
| `auth/login_screen`, `register_screen` | Sign in / create account |
| `profile/onboarding_profile_sheet` | Mandatory first-run profile (goal, body stats, targets) so AI has context |
| `home/main_screen` | Shell with 5 bottom tabs + AI assistant button; remembers last tab |
| `home/dashboard_screen_premium` (+ `home_screen`, `dashboard_screen`, `coach_screen`) | Home: recommendations, calorie/macro progress |
| `recipes/nutrition_screen`, `recipe_detail_screen` | Browse recipes, view steps/ingredients/nutrition, save |
| `camera/food_scanner_screen` | Scan a meal photo to log it |
| `ingredients/pantry_screen` | Manage what the user has at home (feeds AI) |
| `tracking/meal_logging` | Log meals into `food_logs` |
| `home/training_screen` | Training/goal tab |
| `profile/user_profile_screen`, `dietary_profile_screen` | Edit profile, allergies, diet |
| `assistant/assistant_sheet` | Chat with the AI assistant |

---

## 9. Other pieces

- **`supabase/`** — `migrations/` (schema + RLS), `seed.sql`, `functions/analyze-meal-image` (Edge Function), `config.toml`.
- **`backend/scripts/`** — data import/generation tools (foods, recipes, pantry, logs).
- **`backend/docs/`** — earlier design docs (see caveat below).
- **`test/`, `backend/tests/`** — unit/API tests.

---

## 10. Honest caveats (know these if asked)

- **Two environment files are intentional:** root `.env` configures Flutter; `backend/.env` configures FastAPI. Backend secrets must never be copied into the Flutter file.
- **Seed data:** `supabase/seed.sql` creates demo catalog entries. The recommendation API now excludes rows marked `source_provider=seed`.
- **Hardening needed before production:** CORS defaults to `*`; restrict `CORS_ORIGINS` to trusted browser origins.
- Food-scan accuracy is limited until a real vision model replaces the keyword matcher.

---

## 11. One-paragraph answer for "how is the app connected?"

"The Flutter app signs users in with Supabase Auth and reads/writes its own data straight to Supabase Postgres, where Row Level Security guarantees each user only sees their own rows. For AI features it calls our FastAPI backend with the Supabase token; the backend verifies the user, pulls their profile and pantry from Supabase, gathers real recipes from our catalog and Spoonacular, and uses OpenAI only to rank them, build meal plans and answer questions — with strict validation and a rule-based fallback if the AI is unavailable."
