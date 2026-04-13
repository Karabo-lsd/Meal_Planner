from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime

class IngredientBase(BaseModel):
    name: str
    category: Optional[str] = None
    usda_id: Optional[str] = None

class Ingredient(IngredientBase):
    id: int
    
    class Config:
        from_attributes = True

class RecipeIngredientBase(BaseModel):
    ingredient_id: int
    quantity: float
    unit: str

class RecipeIngredient(RecipeIngredientBase):
    id: int
    ingredient: Ingredient
    
    class Config:
        from_attributes = True

class RecipeBase(BaseModel):
    title: str
    description: Optional[str] = None
    instructions: str
    prep_time_minutes: Optional[int] = None
    cook_time_minutes: Optional[int] = None
    servings: int = 1
    difficulty: Optional[str] = None
    cuisine: Optional[str] = None
    dietary_tags: Optional[List[str]] = []

class RecipeCreate(RecipeBase):
    ingredients: List[RecipeIngredientBase]

class RecipeUpdate(RecipeBase):
    pass

class Recipe(RecipeBase):
    id: int
    created_by: int
    created_at: datetime
    updated_at: Optional[datetime]
    ingredients: List[RecipeIngredient]
    average_rating: Optional[float] = None
    
    class Config:
        from_attributes = True

class RecipeRatingBase(BaseModel):
    rating: float
    review: Optional[str] = None

class RecipeRating(RecipeRatingBase):
    id: int
    recipe_id: int
    user_id: int
    created_at: datetime
    
    class Config:
        from_attributes = True