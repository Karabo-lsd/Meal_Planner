from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime, date


class IngredientRef(BaseModel):
    id: int
    name: Optional[str] = None
    category: Optional[str] = None
    usda_id: Optional[str] = None

    class Config:
        from_attributes = True

class MealFoodItemBase(BaseModel):
    ingredient_id: int
    quantity_g: float
    confidence_score: Optional[float] = None

class MealFoodItem(MealFoodItemBase):
    id: int
    ingredient: Optional[IngredientRef] = None
    
    class Config:
        from_attributes = True

class MealBase(BaseModel):
    meal_type: str
    image_url: Optional[str] = None
    manual_entry: bool = False

class MealCreate(MealBase):
    analysis_result: Optional[dict] = None

class Meal(MealBase):
    id: int
    user_id: int
    logged_at: datetime
    ai_analysis: Optional[dict] = None
    total_calories: Optional[float] = None
    total_protein: Optional[float] = None
    total_carbs: Optional[float] = None
    total_fat: Optional[float] = None
    food_items: List[MealFoodItem] = []
    
    class Config:
        from_attributes = True

class NutritionGoalBase(BaseModel):
    date: date
    calories_target: float
    protein_target: Optional[float] = None
    carbs_target: Optional[float] = None
    fat_target: Optional[float] = None

class NutritionGoal(NutritionGoalBase):
    id: int
    user_id: int
    
    class Config:
        from_attributes = True