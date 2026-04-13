from fastapi.testclient import TestClient

from meal_planning.main import app

client = TestClient(app)


def test_add_pantry_item_contract():
    payload = {
        "ingredient_name_raw": "Tomato",
        "quantity": 2,
        "unit": "pcs",
        "source": "manual",
    }
    response = client.post("/v1/intelligence/pantry/items", json=payload)
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "accepted"
    assert body["item"]["ingredient_name_normalized"] == "tomato"


def test_recipe_search_contract_degraded():
    payload = {
        "ingredients": ["tomato", "egg"],
        "limit": 5,
    }
    response = client.post("/v1/intelligence/recipes/by-ingredients", json=payload)
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "degraded"
    assert "spoonacular" in body["missing_provider_data"]


def test_image_upload_init_validation_error():
    payload = {
        "filename": "food.txt",
        "mime_type": "image/jpeg",
    }
    response = client.post("/v1/intelligence/scans/image/upload-init", json=payload)
    assert response.status_code == 400


def test_image_upload_init_contract_ok():
    payload = {
        "filename": "food.jpg",
        "mime_type": "image/jpeg",
    }
    response = client.post("/v1/intelligence/scans/image/upload-init", json=payload)
    assert response.status_code == 200
    body = response.json()
    assert body["bucket"] == "food-scans"
    assert body["signed_upload_url"] == "NOT_CONFIGURED"
