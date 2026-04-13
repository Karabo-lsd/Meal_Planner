from __future__ import annotations

from uuid import uuid4

from fastapi import APIRouter, HTTPException, status

from ..schemas.meal_intelligence import (
    ImageUploadInitRequest,
    ImageUploadInitResponse,
    IngredientRecipeSearchResponse,
    IngredientSearchRequest,
    PantryIngredientInput,
)

router = APIRouter()


@router.post("/pantry/items", response_model=dict)
async def add_pantry_item(payload: PantryIngredientInput):
    """
    Phase-1 safe endpoint: validates pantry input and returns normalized payload.
    Persistence to Supabase pantry_items will be enabled after DB integration layer.
    """
    normalized_name = payload.ingredient_name_raw.strip().lower()
    return {
        "status": "accepted",
        "item": {
            "ingredient_name_raw": payload.ingredient_name_raw,
            "ingredient_name_normalized": normalized_name,
            "quantity": payload.quantity,
            "unit": payload.unit,
            "expiry_date": payload.expiry_date,
            "source": payload.source,
        },
        "persistence": "pending_supabase_integration",
    }


@router.post("/recipes/by-ingredients", response_model=IngredientRecipeSearchResponse)
async def search_recipes_by_ingredients(payload: IngredientSearchRequest):
    """
    Phase-1 safe endpoint: contract-first merged response.
    Provider orchestration is intentionally deferred until provider clients are wired.
    """
    request_id = str(uuid4())
    return IngredientRecipeSearchResponse(
        request_id=request_id,
        status="degraded",
        recipes=[],
        missing_provider_data=["spoonacular", "edamam", "usda"],
        explanation={},
    )


@router.post("/scans/image/upload-init", response_model=ImageUploadInitResponse)
async def init_image_upload(payload: ImageUploadInitRequest):
    """
    Phase-1 safe endpoint: returns deterministic private storage path contract.
    Signed URL generation is not enabled until Supabase storage client integration.
    """
    if not payload.filename.lower().endswith((".jpg", ".jpeg", ".png", ".webp")):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="filename extension must be one of .jpg, .jpeg, .png, .webp",
        )

    image_scan_id = str(uuid4())
    storage_path = f"placeholder-user/{image_scan_id}/{payload.filename}"
    return ImageUploadInitResponse(
        image_scan_id=image_scan_id,
        storage_path=storage_path,
        signed_upload_url="NOT_CONFIGURED",
        expires_in_seconds=0,
    )
