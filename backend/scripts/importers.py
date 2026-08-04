import string

from tqdm import tqdm

from .food_api import search_foods
from .food_api import ingredient_information

from .database import supabase

from .logger import info
from .logger import success

from .helpers import wait


def food_exists(spoonacular_id):

    result = supabase.table("foods_master") \
        .select("id") \
        .eq("spoonacular_id", str(spoonacular_id)) \
        .execute()

    return len(result.data) > 0


def insert_food(food):

    response = supabase.table("foods_master").insert({

        "canonical_name": food["name"],

        "food_type": "ingredient",

        "spoonacular_id": str(food["id"]),

        "verification_status": "provider_reported"

    }).execute()

    return response.data[0]["id"]


def insert_nutrition(food_id, nutrients):

    nutrition = {}

    for nutrient in nutrients:

        name = nutrient["name"]

        amount = nutrient["amount"]

        if name == "Calories":
            nutrition["per_100g_calories"] = amount

        elif name == "Protein":
            nutrition["per_100g_protein"] = amount

        elif name == "Carbohydrates":
            nutrition["per_100g_carbs"] = amount

        elif name == "Fat":
            nutrition["per_100g_fat"] = amount

        elif name == "Fiber":
            nutrition["per_100g_fiber"] = amount

        elif name == "Sugar":
            nutrition["per_100g_sugar"] = amount

        elif name == "Sodium":
            nutrition["per_100g_sodium"] = amount

    nutrition["food_id"] = food_id

    supabase.table("food_nutrition").insert(nutrition).execute()


def run():

    for letter in string.ascii_lowercase:

        info(f"Searching {letter}")

        offset = 0

        while True:

            data = search_foods(letter, offset)

            results = data["results"]

            if len(results) == 0:
                break

            for food in tqdm(results):

                if food_exists(food["id"]):
                    continue

                details = ingredient_information(food["id"])

                food_id = insert_food(details)

                insert_nutrition(
                    food_id,
                    details["nutrition"]["nutrients"]
                )

                success(details["name"])

                wait()

            offset += 100