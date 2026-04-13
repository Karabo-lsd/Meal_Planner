from sqlalchemy import Column, Integer, String, DateTime, Boolean, Text, JSON, Float
from sqlalchemy.sql import func
from ..database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=True)
    full_name = Column(String)
    is_active = Column(Boolean, default=True)
    is_superuser = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Profile data
    age = Column(Integer)
    weight_kg = Column(Float)
    height_cm = Column(Float)
    dietary_restrictions = Column(JSON)  # list of restrictions
    allergies = Column(JSON)  # list of allergies
    cuisine_preferences = Column(JSON)  # list of cuisines
    dietary_preferences = Column(JSON)  # e.g., vegetarian, vegan, keto
    fitness_goals = Column(JSON)  # goals like lose weight, gain muscle
    timezone = Column(String, default="UTC")
    
    # Auth0 integration
    auth0_id = Column(String, unique=True, nullable=True)
    social_provider = Column(String, nullable=True)  # google, apple, etc.