import json
import sys
from typing import Callable

import requests

BASE = "http://127.0.0.1:8000"

results = []


def check(name: str, fn: Callable[[], None]) -> None:
    try:
        fn()
        results.append((name, True, "ok"))
    except Exception as exc:
        results.append((name, False, str(exc)))


def assert_status(resp: requests.Response, allowed: tuple[int, ...]) -> None:
    if resp.status_code not in allowed:
        raise AssertionError(f"status={resp.status_code}, body={resp.text}")


check("GET /health", lambda: assert_status(requests.get(f"{BASE}/health", timeout=10), (200,)))
check("GET /", lambda: assert_status(requests.get(f"{BASE}/", timeout=10), (200,)))

# Auth flow

def register_user() -> None:
    resp = requests.post(
        f"{BASE}/v1/auth/register",
        json={"email": "demo@example.com", "password": "DemoPassword123"},
        timeout=10,
    )
    assert_status(resp, (200, 400))


check("POST /v1/auth/register", register_user)


token_holder = {"token": None}


def login_user() -> None:
    resp = requests.post(
        f"{BASE}/v1/auth/login",
        data={"username": "demo@example.com", "password": "DemoPassword123"},
        timeout=10,
    )
    assert_status(resp, (200,))
    body = resp.json()
    token = body.get("access_token")
    if not token:
        raise AssertionError(f"missing access_token in {body}")
    token_holder["token"] = token


check("POST /v1/auth/login", login_user)

headers = {}
if token_holder["token"]:
    headers = {"Authorization": f"Bearer {token_holder['token']}"}

# Users routes
check(
    "GET /v1/users/me",
    lambda: assert_status(requests.get(f"{BASE}/v1/users/me", headers=headers, timeout=10), (200,)),
)
check(
    "PUT /v1/users/me",
    lambda: assert_status(
        requests.put(
            f"{BASE}/v1/users/me",
            headers=headers,
            json={"email": "demo@example.com", "full_name": "Demo User"},
            timeout=10,
        ),
        (200,),
    ),
)

# Meals routes

def analyze_meal() -> None:
    files = {"file": ("meal.jpg", b"fake-jpeg-content", "image/jpeg")}
    resp = requests.post(f"{BASE}/v1/meals/analyze", headers=headers, files=files, timeout=20)
    assert_status(resp, (200,))


check("POST /v1/meals/analyze", analyze_meal)


def log_meal() -> None:
    payload = {
        "meal_type": "lunch",
        "manual_entry": False,
        "analysis_result": {
            "detected_items": [
                {
                    "ingredient_id": 1,
                    "portion_grams": 100,
                    "confidence": 0.8,
                }
            ],
            "total_nutrition": {
                "calories": 100,
                "protein_g": 5,
                "carbs_g": 10,
                "fat_g": 2,
            },
        },
    }
    resp = requests.post(f"{BASE}/v1/meals/", headers=headers, json=payload, timeout=10)
    assert_status(resp, (200,))


check("POST /v1/meals/", log_meal)
check(
    "GET /v1/meals/",
    lambda: assert_status(requests.get(f"{BASE}/v1/meals/", headers=headers, timeout=10), (200,)),
)

# Intelligence routes
check(
    "POST /v1/intelligence/pantry/items",
    lambda: assert_status(
        requests.post(
            f"{BASE}/v1/intelligence/pantry/items",
            json={"ingredient_name_raw": "Tomato", "quantity": 2, "unit": "pcs", "source": "manual"},
            timeout=10,
        ),
        (200,),
    ),
)
check(
    "POST /v1/intelligence/recipes/by-ingredients",
    lambda: assert_status(
        requests.post(
            f"{BASE}/v1/intelligence/recipes/by-ingredients",
            json={"ingredients": ["tomato", "egg"], "limit": 5},
            timeout=10,
        ),
        (200,),
    ),
)
check(
    "POST /v1/intelligence/scans/image/upload-init",
    lambda: assert_status(
        requests.post(
            f"{BASE}/v1/intelligence/scans/image/upload-init",
            json={"filename": "plate.jpg", "mime_type": "image/jpeg"},
            timeout=10,
        ),
        (200,),
    ),
)

# Ingredients routes
created_id = {"id": None}


def create_custom_ingredient() -> None:
    resp = requests.post(
        f"{BASE}/v1/ingredients/custom",
        json={
            "name": "Smoke Ingredient",
            "category": "test",
            "nutritional_data": {"calories": 10, "protein": 1},
        },
        timeout=10,
    )
    assert_status(resp, (200,))
    body = resp.json()
    created_id["id"] = body.get("id")
    if not created_id["id"]:
        raise AssertionError(f"missing id in {body}")


check("POST /v1/ingredients/custom", create_custom_ingredient)
check(
    "GET /v1/ingredients/custom",
    lambda: assert_status(requests.get(f"{BASE}/v1/ingredients/custom", timeout=10), (200,)),
)
check(
    "GET /v1/ingredients",
    lambda: assert_status(requests.get(f"{BASE}/v1/ingredients", params={"q": "Smoke"}, timeout=10), (200,)),
)
check(
    "GET /v1/ingredients/common",
    lambda: assert_status(requests.get(f"{BASE}/v1/ingredients/common", timeout=10), (200,)),
)
check(
    "GET /v1/ingredients/categories",
    lambda: assert_status(requests.get(f"{BASE}/v1/ingredients/categories", timeout=10), (200,)),
)
check(
    "GET /v1/ingredients/nutrition",
    lambda: assert_status(
        requests.get(
            f"{BASE}/v1/ingredients/nutrition",
            params={"name": "Smoke Ingredient", "amount": 1, "unit": "serving"},
            timeout=10,
        ),
        (200,),
    ),
)
check(
    "POST /v1/ingredients/convert",
    lambda: assert_status(
        requests.post(
            f"{BASE}/v1/ingredients/convert",
            json={"ingredient": "Water", "amount": 1000, "from_unit": "ml", "to_unit": "l"},
            timeout=10,
        ),
        (200,),
    ),
)
check(
    "GET /v1/ingredients/seasonal",
    lambda: assert_status(requests.get(f"{BASE}/v1/ingredients/seasonal", timeout=10), (200,)),
)


def get_ingredient_by_id() -> None:
    iid = created_id["id"]
    if not iid:
        raise AssertionError("ingredient id not created")
    resp = requests.get(f"{BASE}/v1/ingredients/{iid}", timeout=10)
    assert_status(resp, (200,))


check("GET /v1/ingredients/{id}", get_ingredient_by_id)


def update_ingredient() -> None:
    iid = created_id["id"]
    if not iid:
        raise AssertionError("ingredient id not created")
    resp = requests.put(
        f"{BASE}/v1/ingredients/custom/{iid}",
        json={"name": "Smoke Ingredient Updated", "category": "test-updated"},
        timeout=10,
    )
    assert_status(resp, (200,))


check("PUT /v1/ingredients/custom/{id}", update_ingredient)


def delete_ingredient() -> None:
    iid = created_id["id"]
    if not iid:
        raise AssertionError("ingredient id not created")
    resp = requests.delete(f"{BASE}/v1/ingredients/custom/{iid}", timeout=10)
    assert_status(resp, (200,))


check("DELETE /v1/ingredients/custom/{id}", delete_ingredient)


failed = [r for r in results if not r[1]]
print("\nAPI Smoke Results")
for name, ok, info in results:
    print(f"{'PASS' if ok else 'FAIL'} - {name} - {info}")

print(f"\nSummary: {len(results) - len(failed)} passed / {len(results)} total")
if failed:
    sys.exit(1)
