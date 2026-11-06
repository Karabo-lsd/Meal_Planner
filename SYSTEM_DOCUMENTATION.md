# AI Meal Planner – System Documentation

## 1. What the system is

AI Meal Planner is a mobile app (Flutter) with a secure backend (FastAPI) that helps a person decide **what to eat**, based on their body goals, diet, allergies and what they have at home. It combines real recipe and nutrition data (Spoonacular, USDA FoodData Central and our own Supabase food database) with AI ranking and vision (OpenAI) to give personalised recipes, meal plans, grocery lists and food-photo nutrition analysis.

### Why it was created / the problem it solves
- People struggle to choose meals that fit a goal (lose weight, gain muscle, maintain), a diet (vegan, halal, etc.) and allergies, and to know the nutrition in what they eat.
- Generic recipe sites ignore personal context; calorie trackers are tedious to log.
- This system **personalises** recipes from a profile, **automates logging** by photographing food, **plans the week** and builds a **grocery list**, while keeping health data private (POPIA notice, per-user isolation, delete-account).

### Why third-party APIs instead of our own models
| Reason | Explanation |
|---|---|
| Data | Training a recipe/nutrition/vision model needs large labelled datasets we do not have. |
| Cost and time | Training and hosting GPUs is far more expensive than pay-per-use APIs. |
| Quality | OpenAI models give strong language and vision ability; USDA and Spoonacular give verified nutrition data. |
| Grounding | Recipes come from real data sources, and the AI only ranks/explains them, which reduces made-up content. |
| Maintainability | Providers improve their models without us retraining. |

Downsides: running cost and quotas, network latency, dependence on third-party uptime and pricing, and data leaving our system (mitigated by sending only what is needed and by the POPIA notice).

---

## 2. Architecture overview

```
Flutter app (Android)
  |  Supabase SDK: sign-in, profile/pantry/saved recipes (protected by RLS)
  |  Dio HTTP + Bearer token
  v
FastAPI backend (Docker)  --->  Redis (rate limiting)
  |        |        |
  |        |        +--> OpenAI (ranking, chat, meal plan, vision)
  |        +-----------> Spoonacular (recipes), USDA FDC (nutrition)
  +--------------------> Supabase (Auth validation, Postgres via REST with service key)
```

Two paths from the app:
1. **Direct to Supabase** for simple per-user data (profile, pantry, saved recipes, logs). Row Level Security (RLS) ensures a user can only touch their own rows.
2. **Through our backend** for anything needing secrets or AI/third-party calls (recommendations, chat, meal plans, image analysis, recipe details, account deletion). API keys never ship in the app.

---

## 3. Technologies, why we chose them, alternatives, pros and cons

### Frontend
| Tool | Role | Why chosen | Alternatives | Advantages | Limitations |
|---|---|---|---|---|---|
| **Flutter / Dart** | The whole app UI | One codebase, fast UI, good camera/plugin ecosystem | React Native, native Kotlin/Swift | Fast development, consistent look, hot reload | Larger app size; some plugins need native setup |
| **Riverpod** | State management (auth, profile, recipes, paging) | Testable, compile-safe, easy async providers | Bloc, Provider, GetX | Clean dependency graph, easy to test | Learning curve |
| **Dio** | HTTP client to the backend | Interceptors (auth token, failover, retry), timeouts | `http` package | Powerful interceptors | More setup than `http` |
| **supabase_flutter** | Auth + direct DB access | Same SDK handles sessions, refresh and RLS queries | Firebase | Secure by default with RLS | Vendor tie-in |
| **Hive** (SessionStorage) | Local per-user cache (e.g. last tab, cached data) | Fast, offline-friendly, no native SQL | SharedPreferences, SQLite | Very quick | Not for complex queries |
| **cached_network_image** | Recipe images cache | Saves data and speeds scrolling | Image.network | Smooth lists | Disk usage |
| **camera / image_picker / image_compress** | Food scanner | Capture and shrink photos before upload | – | Smaller uploads | Device-dependent |
| **fl_chart / syncfusion charts** | Progress and analytics | Rich charts | – | Good visuals | Syncfusion has licensing terms |
| **google_sign_in, sign_in_with_apple, local_auth** | Social/biometric sign-in | Convenience | – | Fewer passwords | Needs provider configuration |

### Backend
| Tool | Role | Why chosen | Alternatives | Advantages | Limitations |
|---|---|---|---|---|---|
| **FastAPI (Python)** | REST API | Async, fast, automatic validation (Pydantic), great AI/HTTP libraries | Django, Flask, Node/Express | Typed schemas, async I/O for slow AI calls | Python is slower than compiled languages for CPU work |
| **Pydantic** | Request/response validation | Rejects bad input early (e.g. `limit` max 100, `page` max 8) | Manual checks | Safe by construction | – |
| **httpx** | Calls to Supabase, Spoonacular, USDA | Async client | requests | Non-blocking | – |
| **OpenAI API** | Ranking, assistant chat, weekly plan, food photo recognition | Strong language + vision with no training | Gemini, Claude, local models | Fast to ship, high quality | Cost, latency, rate limits, privacy considerations |
| **SQLAlchemy + Postgres** | Local fallback recipe store | Keeps recommendations working if external sources are empty | – | Resilient | Extra data to maintain |
| **Supabase (Postgres + Auth)** | Identity, user data, our food/recipe DB | Managed auth, RLS, REST API | Firebase, custom auth | Secure auth without building it | Reliance on the Supabase service |
| **Spoonacular** | Recipes and recipe details | Large recipe catalogue with nutrition | Edamam, TheMealDB | Rich data | Quota/cost; paging limited |
| **USDA FoodData Central** | Nutrition for recognised foods | Authoritative, free | Nutritionix, Open Food Facts | Trusted data | Generic foods, not brands |
| **Redis** | Rate limiting | See section 8 | In-memory dict, DB counters | Atomic, shared, fast | Extra service to run |
| **Docker / Compose** | Packaging and running API, Postgres, Redis | See section 9 | Manual installs, VMs | Reproducible | Needs Docker installed |
| **pytest** | Backend tests | Standard | unittest | – | – |

TheMealDB was deliberately **excluded**: recipes come only from Spoonacular, USDA and our own Supabase food database.

---

## 4. User workflow (point A to point B)

1. **Install / open the app.** Startup initialises Supabase and local storage. If the backend is unreachable the user sees a friendly "try again" message (no hosts or ports).
2. **Register.** Email + password (or Google/Apple). Supabase sends a confirmation email; the link returns via the deep link `mealplanner://auth-callback`. A row is created for the user in `users`.
3. **Login.** Supabase returns an access token and refresh token, stored securely by the SDK. The app opens `/home` through a profile gate.
4. **Privacy notice.** A POPIA notice explains what personal data is processed and why.
5. **Onboarding.** If the profile is incomplete (first name, age, height, weight, goal, daily calorie target, diet type), the onboarding sheet asks for it. Dietary preferences (diet, allergies, foods to avoid) are set in the Dietary Profile.
6. **Home feed.** The app calls `/api/recommendations` with the profile. The backend collects candidates, filters by allergies/diet/search, ranks with AI, and returns up to 100 recipes per page. The user can search, filter, **refresh**, and use **Previous / Next** for further pages (up to 9 pages).
7. **Recipe detail.** Tapping a card calls `/api/recipes/{id}/details` (ingredients, steps, nutrition). The user can save it.
8. **Saved recipes.** Same card layout as home; reachable from the Recipes tab or from Profile (with a back button).
9. **Scan food.** The user photographs a meal; the backend sends it to OpenAI vision, looks up nutrition in USDA, and returns an estimate to log.
10. **Meal logging and progress.** Logged meals feed calorie/nutrition summaries and charts.
11. **Planner.** Weekly meal plan generation (`/api/meal-plans/generate`) and an auto-built grocery list (tabs: Meal plan, Groceries).
12. **Pantry.** The user lists ingredients they have to guide suggestions.
13. **Assistant chat.** An AI sheet answers food questions and can trigger a weekly plan.
14. **Profile and account.** Edit name/email, reset password, help and support, notifications, and **delete account** (removes the Supabase user and their data).
15. **Forgot password.** Email link -> deep link -> reset-password screen -> new password.
16. **Logout.** The session is cleared; local caches are keyed per user so another account never sees old data.

---

## 5. Features: what, how, and the vision

| Feature | What it does | Implemented with | Vision |
|---|---|---|---|
| Authentication | Register, login, social login, forgot/reset password | Supabase Auth, deep links | Secure without building our own auth |
| Onboarding and profile | Captures goal, body metrics, calorie target, diet | Flutter forms, `user_profiles` table | Personalisation from the first minute |
| Dietary profile | Diet, allergies, foods to avoid | `dietary_preferences` table + backend filter | Safety first: allergens are filtered before AI ranking |
| Recommendations | Personalised recipes, 100 per page, pagination | Backend collects from Supabase/Spoonacular/fallback, filters, OpenAI ranks, deterministic fallback ranker if AI fails | Relevant, grounded, reliable even if AI is down |
| Pagination | Previous/Next pages (offset `page*100`) | `page` field, `recipePageProvider` | Explore beyond the first 100 without endless scrolling |
| Recipe detail | Ingredients, steps, nutrition | Spoonacular via backend; `recipe_store` saves to Supabase | One consistent recipe record with a UUID |
| Saved recipes | Personal library | `saved_recipes` + shared `RecipeCard` | Consistent look across screens |
| Food scanner | Photo -> foods -> nutrition | OpenAI vision + USDA | Make logging effortless |
| Meal plan and groceries | Weekly plan, shopping list | OpenAI + `meal_plans`, `grocery_lists` | Reduce daily decision fatigue |
| Pantry | Ingredients on hand | `pantry_items` | Cook what you already have |
| AI assistant | Chat help | OpenAI | Quick answers in context |
| Progress/analytics | Charts of intake | fl_chart | Motivation and feedback |
| Notifications | In-app notices | Flutter | Keep users engaged |
| Privacy (POPIA) | Notice, delete account | `privacy_notice.dart`, `DELETE /api/account` | Legal compliance and user control |
| Friendly errors | Plain-language messages, no hosts/ports | `friendly_error.dart` | Do not leak internals; keep users calm |
| USB + Wi-Fi failover | App tries `127.0.0.1:8000` (adb reverse), then the Wi-Fi URL | Dio `_FailoverInterceptor` | Reliable demos on any network |

---

## 6. How services work together

- **Flutter app** -> authenticates with Supabase, then calls our API with the token.
- **FastAPI** -> validates the token, enforces rate limits (Redis), loads the trusted profile from Supabase, gathers recipes (Supabase, Spoonacular, local DB), filters, calls OpenAI, and returns JSON.
- **Supabase** -> source of truth for users and their data, protected by RLS.
- **Redis** -> counters only.
- **Docker Compose** -> runs API, Postgres and Redis together.

### Recommendation pipeline (simplified)
1. Validate request (`limit` <= 100, `page` 0-8).
2. Load the **trusted** profile from Supabase (not from the client payload).
3. Collect up to 100 candidates (page > 0 skips the local fallback and uses popularity sorting to avoid repeats).
4. Filter allergies, diet and search text.
5. Rank with OpenAI; if it fails, use the deterministic ranker.
6. Persist provider recipes so each has a UUID; return results.

---

## 7. Authentication and user identification

1. The app signs in via Supabase Auth and receives a JWT access token.
2. Dio's `_SupabaseAuthInterceptor` adds `Authorization: Bearer <token>` to every backend request. On a 401 it refreshes the session once and retries.
3. The backend dependency `get_supabase_user_id` calls Supabase `/auth/v1/user` to validate the token and obtain the user id. Invalid -> 401; Supabase not configured -> 503.
4. If a request body contains a `user_id` that differs from the token's, the backend returns **403**. The user id comes from the token, never from trust in the client.
5. The backend uses the Supabase **service key** only on the server for trusted reads/writes. The app only has the public **anon key**; RLS (`auth.uid() = user_id`) isolates data per user.
6. Public endpoints: only `/` and `/health` (rate limited per IP).
7. Local caches (Hive) are keyed by user id.

Secrets (OpenAI, Spoonacular, USDA, Supabase service key, DB password) live only in `backend/.env` (git-ignored). The Flutter `.env` is bundled in the app, so it must contain only public values (Supabase URL/anon key, API URLs).

---

## 8. Rate limiting and Redis

Limits are **per user** (identified by token), and each endpoint also counts toward the general limit. Exceeding returns **HTTP 429** with a `Retry-After` header.

| Scope | Limit | Window |
|---|---|---|
| General (all authenticated endpoints) | 120 requests | 60 s |
| AI recommendations | 10 | 60 s |
| AI chat | 10 | 60 s |
| AI weekly meal plan | 3 | 60 s |
| AI image analysis | 5 | 60 s |
| AI substitution | 10 | 60 s |
| Shared AI pool (recommendations + chat + plan + image) | 20 | 60 s |
| Recipe search / details | 30 | 60 s |
| Account deletion | 5 | 5 min |
| `/` and `/health` (per IP) | 30 | 60 s |

**Why limit?** Every AI/third-party call costs money and quota. Limits stop abuse, runaway loops and brute force, and protect availability.

**Why Redis?**
- Counters live **outside** the API process, so they are shared if there are several API instances and survive API restarts.
- A Lua script does `INCR` + `EXPIRE` **atomically**, so concurrent requests cannot slip past the limit.
- It is extremely fast, and keys expire automatically.
- Alternatives: in-memory counters (not shared, reset on restart) or Postgres (slower, heavier).

**Fail-closed:** if Redis is down the API answers 503 "Rate limiter is temporarily unavailable" instead of allowing unlimited traffic. This is safe for cost control but means Redis downtime blocks the API (configurable via `RATE_LIMIT_FAIL_CLOSED`).

Redis is used **only** for rate limiting. There is no server-side recipe cache; the client caches with Hive and `cached_network_image`.

Client IP is taken from `X-Forwarded-For` only when the request comes from a trusted proxy.

---

## 9. Why Docker

- **Reproducibility:** the same environment on every machine (Python 3.11-slim image, non-root user, port 8000).
- **One command** (`docker compose up`) starts the API, Postgres 15 and Redis 7 with health checks and the right start order.
- **Isolation and security:** Postgres and Redis bind to `127.0.0.1` only; the DB password is required from `backend/.env`.
- **Deployability:** the same image can be deployed to any cloud.
- Alternatives: manual installs (error-prone), VMs (heavy), serverless (awkward for Redis and long AI calls).

---

## 10. Connectivity (USB and Wi-Fi)

- **USB:** `adb reverse tcp:8000 tcp:8000`; the app uses `http://127.0.0.1:8000`. Use `scripts\run_android_usb.ps1` (`-TunnelOnly` to rebuild the tunnel).
- **Wi-Fi:** set `API_WIFI_URL` to the PC's LAN address; Windows Firewall must allow inbound TCP 8000.
- The app tries USB first, then Wi-Fi, and remembers whichever works. Timeouts: connect 10 s, receive 60 s, one retry.

---

## 11. Data model (Supabase, RLS on all tables)

Identity: `users`, `user_profiles`, `dietary_preferences`. Food: `foods_master`, `food_nutrition`, `recipes`, `recipe_ingredients`, `recipe_nutrition`, `saved_recipes`, `pantry_items`. Planning and logs: `meal_plans`, `meal_plan_items`, `food_logs`, `grocery_lists`, `grocery_list_items`, `image_scans`, `image_scan_predictions`, `ai_recommendation_logs`. User tables allow access only where `auth.uid() = user_id`; shared food/recipe tables are readable by authenticated users and writable only by the service role.

---

## 12. Advantages of the system
- Personalised and allergy-aware; recipes grounded in real data.
- Secure by design: tokens, RLS, server-side secrets, rate limits, per-user isolation, delete account.
- Resilient: AI ranking falls back to a deterministic ranker; USB/Wi-Fi failover.
- Cost-controlled through limits and a candidate cap.
- Quick to build and maintain thanks to managed services.

## 13. Limitations and what we could do better
- **Third-party dependence:** OpenAI, Spoonacular, USDA and Supabase outages, quotas, price changes.
- **AI accuracy:** food photo recognition is an estimate; portion sizes are hard.
- **Paging cap:** about 9 pages (page 8 max) because of provider offset limits.
- **No server-side recipe cache:** repeated requests re-hit providers; a Redis response cache would cut cost and latency.
- **Single backend instance:** no load balancer, autoscaling or CDN yet.
- **Fail-closed Redis:** Redis downtime blocks the API.
- **CORS** defaults to `*` (acceptable for a mobile client; tighten for any web client).
- **Manual network setup:** the Wi-Fi IP changes per network; USB needs `adb reverse` re-run after reconnecting.
- **Bundled `.env`** means only public values can go in the app.
- **Voice search** is a placeholder; some unused code still triggers analyzer warnings.
- **Platform scope:** tested mainly on Android.
- **Better next steps:** CI with deployment, monitoring/alerts, structured logging, response caching, offline mode, more automated UI tests, optional self-hosted models for cheap tasks, HTTPS deployment with a domain, and admin tooling.

---

## 14. Running and testing
- Backend: `docker compose up` in `backend/` (needs `backend/.env`), or `uvicorn` locally. Tests: `python -m pytest backend/tests`.
- App: `scripts\run_android_usb.ps1` or `flutter run`. Tests: `flutter test`.
- Never commit `.env` files; rotate keys immediately if one leaks.
