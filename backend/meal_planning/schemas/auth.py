from pydantic import BaseModel
from typing import Any, Dict, Optional

class Token(BaseModel):
    access_token: str
    token_type: str
    user: Optional[Dict[str, Any]] = None

class TokenData(BaseModel):
    email: Optional[str] = None

class UserLogin(BaseModel):
    email: str
    password: str

class SocialLogin(BaseModel):
    provider: str  # google, apple
    token: str