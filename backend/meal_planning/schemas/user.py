from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime

class UserBase(BaseModel):
    email: EmailStr
    full_name: Optional[str] = None
    age: Optional[int] = None
    weight_kg: Optional[float] = None
    height_cm: Optional[float] = None
    dietary_restrictions: Optional[List[str]] = []
    allergies: Optional[List[str]] = []
    cuisine_preferences: Optional[List[str]] = []
    dietary_preferences: Optional[List[str]] = []
    fitness_goals: Optional[List[str]] = []
    timezone: str = "UTC"

class UserCreate(UserBase):
    password: str

class UserUpdate(UserBase):
    pass

class User(UserBase):
    id: int
    is_active: bool
    created_at: datetime
    updated_at: Optional[datetime]
    
    class Config:
        from_attributes = True

class UserInDB(User):
    hashed_password: str