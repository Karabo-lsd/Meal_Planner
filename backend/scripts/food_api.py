import requests

from .config import BASE_URL
from .config import SPOONACULAR_KEY


def search_foods(query, offset=0):

    url = f"{BASE_URL}/food/ingredients/search"

    params = {

        "query": query,
        "number": 100,
        "offset": offset,
        "apiKey": SPOONACULAR_KEY

    }

    response = requests.get(url, params=params)

    response.raise_for_status()

    return response.json()


def ingredient_information(id):

    url = f"{BASE_URL}/food/ingredients/{id}/information"

    params = {

        "amount":100,
        "unit":"g",
        "apiKey":SPOONACULAR_KEY

    }

    response = requests.get(url, params=params)

    response.raise_for_status()

    return response.json()