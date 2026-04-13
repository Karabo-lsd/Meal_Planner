from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    # Database
    database_url: str = "sqlite:///./meal_planning.db"
    
    # Redis
    redis_url: str = "redis://localhost:6379"
    
    # JWT
    secret_key: str = "your-secret-key"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    
    # Auth0
    auth0_domain: str = ""
    auth0_api_audience: str = ""
    auth0_issuer: str = ""
    auth0_algorithms: list = ["RS256"]
    
    # ML
    ml_model_path: str = "/models"
    onnx_model_path: str = "/models/food_classifier.onnx"
    
    # External APIs
    usda_api_key: Optional[str] = None
    spoonacular_api_key: Optional[str] = None
    
    # Email
    smtp_server: str = ""
    smtp_port: int = 587
    smtp_username: str = ""
    smtp_password: str = ""
    
    # Notifications
    fcm_server_key: str = ""
    
    # Environment
    environment: str = "development"
    debug: bool = True
    
    class Config:
        env_file = ".env"

settings = Settings()