from fastapi.testclient import TestClient

from meal_planning.main import app

client = TestClient(app)


def test_add_and_list_custom_ingredient():
    create = client.post(
        "/v1/ingredients/custom",
        json={
            "name": "Test Tomato",
            "category": "vegetable",
            "nutritional_data": {"calories": 18, "protein": 0.9},
        },
    )
    assert create.status_code == 200
    body = create.json()
    assert body["name"] == "Test Tomato"

    listing = client.get("/v1/ingredients/custom")
    assert listing.status_code == 200
    items = listing.json()["items"]
    assert any(i["name"] == "Test Tomato" for i in items)


def test_search_ingredients_endpoint():
    response = client.get("/v1/ingredients", params={"q": "tom", "limit": 10})
    assert response.status_code == 200
    assert isinstance(response.json(), list)


def test_get_categories_endpoint():
    response = client.get("/v1/ingredients/categories")
    assert response.status_code == 200
    assert isinstance(response.json(), list)
