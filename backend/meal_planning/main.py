from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .routers.auth import router as auth_router
from .routers.users import router as users_router
from .routers.meals import router as meals_router
from .routers.intelligence import router as intelligence_router
from .routers.ingredients import router as ingredients_router
from .database import engine, SessionLocal
from .database import Base
from .models.user import User
from .models.recipe import Recipe, Ingredient
from .models.nutrition import Meal
from .services.auth import get_password_hash

# Create database tables
Base.metadata.create_all(bind=engine)

# Seed default test user
def seed_default_user():
    db = SessionLocal()
    try:
        existing_user = db.query(User).filter(User.email == "demo@example.com").first()
        if not existing_user:
            hashed_password = get_password_hash("DemoPassword123")
            default_user = User(
                email="demo@example.com",
                hashed_password=hashed_password,
                full_name="Demo User"
            )
            db.add(default_user)
            db.commit()
            print("✓ Default test user created: demo@example.com / DemoPassword123")
    except Exception as e:
        print(f"Error seeding default user: {e}")
    finally:
        db.close()

seed_default_user()

app = FastAPI(
    title="AI Meal Planning API",
    description="Production-grade meal planning backend with AI food recognition",
    version="1.0.0"
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure properly in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth_router, prefix="/v1/auth", tags=["authentication"])
app.include_router(users_router, prefix="/v1/users", tags=["users"])
app.include_router(meals_router, prefix="/v1/meals", tags=["meals"])
app.include_router(intelligence_router, prefix="/v1/intelligence", tags=["intelligence"])
app.include_router(ingredients_router, prefix="/v1/ingredients", tags=["ingredients"])

@app.get("/")
async def root():
    return {"message": "AI Meal Planning API"}

@app.get("/health")
async def health_check():
    return {"status": "healthy"}