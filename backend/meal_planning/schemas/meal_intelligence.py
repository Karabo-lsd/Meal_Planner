from __future__ import annotations

from typing import Dict, List, Literal, Optional

from pydantic import BaseModel, Field

from .canonical import CanonicalFood, CanonicalRecipe


class PantryIngredientInput(BaseModel):
    ingredient_name_raw: str = Field(min_length=1, max_length=200)
    quantity: float = Field(gt=0)
    unit: str = Field(min_length=1, max_length=50)
    expiry_date: Optional[str] = None
    source: Literal["manual", "image_scan", "imported"] = "manual"


class IngredientSearchRequest(BaseModel):
    ingredients: List[str] = Field(min_length=1)
    limit: int = Field(default=20, ge=1, le=50)


class RecommendationExplanation(BaseModel):
    summary: str
    matched_ingredients: List[str]
    dietary_matches: List[str]
    goal_alignment: List[str]
    uncertainty_notes: List[str]


class IngredientRecipeSearchResponse(BaseModel):
    request_id: str
    status: Literal["ok", "partial", "degraded"]
    recipes: List[CanonicalRecipe]
    missing_provider_data: List[str] = Field(default_factory=list)
    explanation: Dict[str, RecommendationExplanation] = Field(default_factory=dict)


class ImageUploadInitRequest(BaseModel):
    filename: str = Field(min_length=1, max_length=255)
    mime_type: Literal["image/jpeg", "image/png", "image/webp"]


class ImageUploadInitResponse(BaseModel):
    image_scan_id: str
    storage_path: str
    bucket: str = "food-scans"
    signed_upload_url: str
    expires_in_seconds: int


class ImageScanResultResponse(BaseModel):
    image_scan_id: str
    scan_status: Literal["pending", "processing", "completed", "failed", "needs_review", "confirmed"]
    overall_confidence: Optional[float] = Field(default=None, ge=0, le=1)
    estimation_flag: bool
    detected_foods: List[CanonicalFood]
    uncertainty_notes: List[str] = Field(default_factory=list)
