from supabase import create_client
from faker import Faker
import random
from .config import SUPABASE_URL, SUPABASE_KEY as SUPABASE_SERVICE_KEY

if not SUPABASE_URL:
    raise Exception("SUPABASE_URL not found.")

if not SUPABASE_SERVICE_KEY:
    raise Exception("SUPABASE_SERVICE_KEY not found.")

supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

fake = Faker()

NUMBER_OF_USERS = 50

activity_levels = [
    "Sedentary",
    "Lightly Active",
    "Moderately Active",
    "Very Active"
]

goals = [
    "Lose Weight",
    "Maintain Weight",
    "Gain Muscle"
]

diet_types = [
    "None",
    "Vegetarian",
    "Vegan",
    "Keto",
    "Paleo",
    "Halal"
]

budget_preferences = [
    "Low",
    "Medium",
    "High"
]

cuisines = [
    "Italian",
    "Mexican",
    "Indian",
    "Chinese",
    "Mediterranean",
    "Japanese",
    "Thai",
    "American"
]

possible_allergies = [
    "Milk",
    "Eggs",
    "Peanuts",
    "Tree Nuts",
    "Soy",
    "Fish",
    "Shellfish",
    "Gluten"
]

excluded_foods = [
    "Broccoli",
    "Spinach",
    "Onions",
    "Mushrooms",
    "Tofu",
    "Seafood"
]

created = 0
skipped = 0
failed = 0

print("=" * 60)
print("Creating users...")
print("=" * 60)

for i in range(NUMBER_OF_USERS):

    email = f"testuser{i+1}@mealplanner.com"
    password = "Password123!"

    first_name = fake.first_name()
    last_name = fake.last_name()

    age = random.randint(18, 60)
    sex = random.choice(["male", "female"])

    weight = round(random.uniform(50, 100), 1)
    height = round(random.uniform(150, 200), 1)

    activity = random.choice(activity_levels)
    goal = random.choice(goals)

    calories = random.randint(1800, 3200)
    protein = random.randint(90, 180)
    carbs = random.randint(180, 350)
    fat = random.randint(40, 90)

    allergies = random.sample(
        possible_allergies,
        random.randint(0, 2)
    )

    excluded = random.sample(
        excluded_foods,
        random.randint(0, 2)
    )

    cuisines_selected = random.sample(
        cuisines,
        random.randint(1, 3)
    )

    disliked_foods = random.sample(
        excluded_foods,
        random.randint(0, 2)
    )

    try:

        # -------------------------------
        # Create Auth User
        # -------------------------------

        response = supabase.auth.admin.create_user(
            {
                "email": email,
                "password": password,
                "email_confirm": True,
            }
        )

        user = response.user

        print(f"✓ {email}")

        # -------------------------------
        # User Profile
        # -------------------------------

        supabase.table("user_profiles").insert(
            {
                "user_id": user.id,
                "first_name": first_name,
                "last_name": last_name,
                "age": age,
                "sex": sex,
                "weight": weight,
                "height": height,
                "activity_level": activity,
                "goal": goal,
                "daily_calorie_target": calories,
                "daily_protein_target": protein,
                "daily_carb_target": carbs,
                "daily_fat_target": fat,
            }
        ).execute()

        # -------------------------------
        # Dietary Preferences
        # -------------------------------

        supabase.table("dietary_preferences").insert(
            {
                "user_id": user.id,
                "diet_type": random.choice(diet_types),
                "allergies": allergies,
                "excluded_ingredients": excluded,
                "preferred_cuisines": cuisines_selected,
                "disliked_foods": disliked_foods,
                "budget_preference": random.choice(budget_preferences),
                "max_prep_time_minutes": random.randint(10, 90),
            }
        ).execute()

        created += 1

    except Exception as e:

        message = str(e)

        if "already been registered" in message.lower():
            print(f"⚠ {email} already exists.")
            skipped += 1
        else:
            print(f"✗ Failed creating {email}")
            print(message)
            failed += 1

print()
print("=" * 60)
print("Finished")
print("=" * 60)
print(f"Created : {created}")
print(f"Skipped : {skipped}")
print(f"Failed  : {failed}")