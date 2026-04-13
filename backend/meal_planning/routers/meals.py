from fastapi import APIRouter, Depends, UploadFile, File, HTTPException
from sqlalchemy.orm import Session
from typing import List
from ..database import get_db
from ..models.user import User
from ..models.nutrition import Meal, MealFoodItem
from ..schemas.nutrition import Meal as MealSchema, MealCreate
from ..services.ml_inference import ml_service
from .auth import get_current_user
import aiofiles

router = APIRouter()

@router.post("/analyze", response_model=dict)
async def analyze_meal_image(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user)
):
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")
    
    # Read image bytes
    image_bytes = await file.read()
    
    # Analyze with ML service
    result = await ml_service.analyze_food_image(image_bytes)
    
    return result

@router.post("/", response_model=MealSchema)
async def log_meal(
    meal_data: MealCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Create meal record
    meal = Meal(
        user_id=current_user.id,
        meal_type=meal_data.meal_type,
        image_url=meal_data.image_url,
        manual_entry=meal_data.manual_entry
    )
    
    analysis_result = meal_data.analysis_result

    if analysis_result:
        meal.ai_analysis = analysis_result
        meal.total_calories = analysis_result.get("total_nutrition", {}).get("calories")
        meal.total_protein = analysis_result.get("total_nutrition", {}).get("protein_g")
        meal.total_carbs = analysis_result.get("total_nutrition", {}).get("carbs_g")
        meal.total_fat = analysis_result.get("total_nutrition", {}).get("fat_g")
        
        # Add food items
        for item in analysis_result.get("detected_items", []):
            ingredient_id = item.get("ingredient_id")
            if ingredient_id is None:
                continue
            food_item = MealFoodItem(
                ingredient_id=ingredient_id,
                quantity_g=item.get("portion_grams"),
                confidence_score=item.get("confidence")
            )
            meal.food_items.append(food_item)
    
    db.add(meal)
    db.commit()
    db.refresh(meal)
    return meal

@router.get("/", response_model=List[MealSchema])
async def get_user_meals(
    skip: int = 0,
    limit: int = 100,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    meals = db.query(Meal).filter(Meal.user_id == current_user.id).offset(skip).limit(limit).all()
    return meals