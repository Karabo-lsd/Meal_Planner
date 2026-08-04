import os
from dotenv import load_dotenv
from pathlib import Path

load_dotenv(Path(__file__).resolve().parents[1] / ".env")

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_KEY")

SPOONACULAR_KEY = os.getenv("SPOONACULAR_API_KEY")

BASE_URL = "https://api.spoonacular.com"