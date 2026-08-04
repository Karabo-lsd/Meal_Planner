from .database import supabase
from .food_api import search_foods, ingredient_information

SEARCH_TERMS = [
    "chicken",
    "beef",
    "rice",
    "egg",
    "milk",
    "bread",
    "apple",
    "banana",
    "cheese",
    "fish",
    "potato",
    "tomato",
    "onion",
    "carrot",
    "broccoli"
]


def insert_food(food):

    data = {

        "canonical_name": food["name"],

        "food_type": "ingredient",

        "spoonacular_id": str(food["id"]),

        "image_model_label_id": food.get("image"),

        "verification_status": "provider_reported"

    }

    result = (
        supabase.table("foods_master")
        .upsert(
            data,
            on_conflict="spoonacular_id"
        )
        .execute()
    )

    return result.data[0]["id"]


def insert_nutrition(food_uuid, nutrition):

    nutrients = nutrition["nutrition"]["nutrients"]

    values = {}

    for nutrient in nutrients:

        name = nutrient["name"]

        amount = nutrient["amount"]

        if name == "Calories":
            values["per_100g_calories"] = amount

        elif name == "Protein":
            values["per_100g_protein"] = amount

        elif name == "Carbohydrates":
            values["per_100g_carbs"] = amount

        elif name == "Fat":
            values["per_100g_fat"] = amount

        elif name == "Fiber":
            values["per_100g_fiber"] = amount

        elif name == "Sugar":
            values["per_100g_sugar"] = amount

        elif name == "Sodium":
            values["per_100g_sodium"] = amount

    values["food_id"] = food_uuid

    (
        supabase
        .table("food_nutrition")
        .upsert(
            values,
            on_conflict="food_id"
        )
        .execute()
    )


def run():

    print("Importing foods...")

    total = 0

    for search in SEARCH_TERMS:

        print(f"\nSearching: {search}")

        foods = search_foods(search)["results"]

        for food in foods:

            try:

                info = ingredient_information(food["id"])

                uuid = insert_food(info)

                insert_nutrition(uuid, info)

                total += 1

                print("✓", info["name"])

            except Exception as e:

                print("✗", food["name"], e)

    print()

    print("Finished")

    print("Foods Imported:", total)