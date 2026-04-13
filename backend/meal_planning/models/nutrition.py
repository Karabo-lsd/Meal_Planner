from sqlalchemy import Column, Integer, String, DateTime, JSON, Float, ForeignKey, Boolean, Date
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from ..database import Base

class Meal(Base):
    __tablename__ = "meals"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    meal_type = Column(String)  # breakfast, lunch, dinner, snack
    logged_at = Column(DateTime(timezone=True), server_default=func.now())
    image_url = Column(String)  # uploaded image
    manual_entry = Column(Boolean, default=False)
    
    # AI analysis results
    ai_analysis = Column(JSON)  # food items, portions, confidence
    total_calories = Column(Float)
    total_protein = Column(Float)
    total_carbs = Column(Float)
    total_fat = Column(Float)
    
    # Relationships
    food_items = relationship("MealFoodItem", back_populates="meal")

class MealFoodItem(Base):
    __tablename__ = "meal_food_items"

    id = Column(Integer, primary_key=True, index=True)
    meal_id = Column(Integer, ForeignKey("meals.id"))
    ingredient_id = Column(Integer, ForeignKey("ingredients.id"))
    quantity_g = Column(Float)
    confidence_score = Column(Float)
    
    meal = relationship("Meal", back_populates="food_items")
    ingredient = relationship("Ingredient")

class UserNutritionGoal(Base):
    __tablename__ = "user_nutrition_goals"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    date = Column(Date, nullable=False)
    calories_target = Column(Float)
    protein_target = Column(Float)
    carbs_target = Column(Float)
    fat_target = Column(Float)
    created_at = Column(DateTime(timezone=True), server_default=func.now())