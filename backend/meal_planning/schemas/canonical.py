from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List, Literal, Optional

from pydantic import BaseModel, Field

VerificationStatus = Literal[
    "provider_reported",
    "validated_with_usda",
    "user_confirmed",
    "estimated_from_image",
    "partially_estimated",
]

FoodType = Literal["ingredient", "packaged_food", "prepared_meal", "recipe"]


class SourceIds(BaseModel):
    spoonacular_id: Optional[str] = None
    edamam_id: Optional[str] = None
    usda_fdc_id: Optional[str] = None
    open_food_facts_id: Optional[str] = None
    image_model_label_id: Optional[str] = None


class NutritionFacts(BaseModel):
    calories: Optional[float] = None
    protein: Optional[float] = None
    carbs: Optional[float] = None
    fat: Optional[float] = None
    fiber: Optional[float] = None
    sugar: Optional[float] = None
    sodium: Optional[float] = None
    micronutrients: Optional[Dict[str, Any]] = None


class ImageRecognitionMetadata(BaseModel):
    provider: Optional[str] = None
    model: Optional[str] = None
    raw_label: Optional[str] = None
    bounding_box: Optional[Dict[str, float]] = None
    segment_id: Optional[str] = None
    portion_confidence: Optional[float] = Field(default=None, ge=0, le=1)


class CanonicalFood(BaseModel):
    canonical_name: str
    aliases: List[str] = Field(default_factory=list)
    food_category: Optional[str] = None
    source_ids: SourceIds
    nutrition_per_100g: NutritionFacts
    nutrition_per_serving: Optional[NutritionFacts] = None
    serving_size: Optional[float] = None
    serving_unit: Optional[str] = None
    allergens: List[str] = Field(default_factory=list)
    dietary_tags: List[str] = Field(default_factory=list)
    cuisine_tags: List[str] = Field(default_factory=list)
    food_type: FoodType
    confidence_score: Optional[float] = Field(default=None, ge=0, le=1)
    estimation_flag: bool = False
    verification_status: VerificationStatus = "provider_reported"
    image_recognition_metadata: Optional[ImageRecognitionMetadata] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class CanonicalRecipeIngredient(BaseModel):
    canonical_food_id: Optional[str] = None
    ingredient_name_raw: str
    ingredient_name_normalized: Optional[str] = None
    quantity: Optional[float] = None
    unit: Optional[str] = None


class RecipeScoreBreakdown(BaseModel):
    ingredient_match_score: float = Field(ge=0, le=1)
    dietary_fit_score: float = Field(ge=0, le=1)
    calorie_fit_score: float = Field(ge=0, le=1)
    macro_fit_score: float = Field(ge=0, le=1)
    prep_time_score: float = Field(ge=0, le=1)
    user_preference_score: float = Field(ge=0, le=1)
    diversity_score: float = Field(ge=0, le=1)
    cost_score: Optional[float] = Field(default=None, ge=0, le=1)
    final_score: float = Field(ge=0, le=1)


class CanonicalRecipe(BaseModel):
    recipe_id: Optional[str] = None
    source_provider: str
    external_recipe_id: Optional[str] = None
    title: str
    image_url: Optional[str] = None
    source_url: Optional[str] = None
    summary: Optional[str] = None
    cuisine: Optional[str] = None
    meal_type: Optional[str] = None
    prep_time_minutes: Optional[int] = None
    cook_time_minutes: Optional[int] = None
    total_time_minutes: Optional[int] = None
    servings: Optional[float] = None
    dietary_tags: List[str] = Field(default_factory=list)
    health_labels: List[str] = Field(default_factory=list)
    ingredients: List[CanonicalRecipeIngredient] = Field(default_factory=list)
    nutrition: NutritionFacts = Field(default_factory=NutritionFacts)
    confidence_score: Optional[float] = Field(default=None, ge=0, le=1)
    estimation_flag: bool = False
    verification_status: VerificationStatus = "provider_reported"
    ranking: Optional[RecipeScoreBreakdown] = None
    explanation_metadata: Dict[str, Any] = Field(default_factory=dict)
    data_completeness: Literal["complete", "partial", "degraded"] = "partial"
