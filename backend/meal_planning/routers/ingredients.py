from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from ..database import get_db
from ..models.recipe import Ingredient

router = APIRouter()


def _ingredient_to_dict(item: Ingredient) -> dict:
    return {
        "id": item.id,
        "name": item.name,
        "category": item.category,
        "usda_id": item.usda_id,
        "nutritional_data": item.nutritional_data or {},
    }


@router.get("")
async def search_ingredients(
    q: str = Query("", max_length=100),
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
):
    query = db.query(Ingredient)
    if q:
        query = query.filter(Ingredient.name.ilike(f"%{q}%"))
    items = query.order_by(Ingredient.name.asc()).limit(limit).all()
    return [_ingredient_to_dict(item) for item in items]


@router.get("/nutrition")
async def get_ingredient_nutrition(
    name: str = Query(..., min_length=1, max_length=200),
    amount: float = Query(1.0, gt=0),
    unit: str = Query("serving", min_length=1, max_length=50),
    db: Session = Depends(get_db),
):
    item = db.query(Ingredient).filter(Ingredient.name.ilike(name)).first()
    if not item:
        raise HTTPException(status_code=404, detail="Ingredient not found")

    nutrition = item.nutritional_data or {}
    return {
        "ingredient": item.name,
        "amount": amount,
        "unit": unit,
        **nutrition,
    }


@router.get("/barcode/{barcode}")
async def analyze_barcode(barcode: str):
    if not barcode.isdigit() or not (8 <= len(barcode) <= 14):
        raise HTTPException(status_code=400, detail="Invalid barcode format")

    return {
        "barcode": barcode,
        "status": "not_found",
        "message": "Barcode integration is not wired yet",
    }


@router.get("/common")
async def get_common_ingredients(
    category: str | None = Query(None, max_length=100),
    limit: int = Query(50, ge=1, le=200),
    db: Session = Depends(get_db),
):
    query = db.query(Ingredient)
    if category:
        query = query.filter(Ingredient.category == category)
    items = query.order_by(Ingredient.name.asc()).limit(limit).all()
    return [_ingredient_to_dict(item) for item in items]


@router.get("/categories")
async def get_ingredient_categories(db: Session = Depends(get_db)):
    rows = (
        db.query(Ingredient.category)
        .filter(Ingredient.category.isnot(None))
        .distinct()
        .all()
    )
    return sorted([r[0] for r in rows if r[0]])


@router.post("/custom")
async def add_custom_ingredient(payload: dict, db: Session = Depends(get_db)):
    name = str(payload.get("name", "")).strip()
    if not name:
        raise HTTPException(status_code=400, detail="Ingredient name is required")

    existing = db.query(Ingredient).filter(Ingredient.name.ilike(name)).first()
    if existing:
        return _ingredient_to_dict(existing)

    ingredient = Ingredient(
        name=name,
        category=payload.get("category"),
        usda_id=payload.get("usda_id"),
        nutritional_data=payload.get("nutritional_data") or {},
    )
    db.add(ingredient)
    db.commit()
    db.refresh(ingredient)
    return _ingredient_to_dict(ingredient)


@router.get("/custom")
async def get_custom_ingredients(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=200),
    db: Session = Depends(get_db),
):
    items = db.query(Ingredient).order_by(Ingredient.id.desc()).offset(skip).limit(limit).all()
    return {
        "items": [_ingredient_to_dict(item) for item in items],
        "skip": skip,
        "limit": limit,
    }


@router.put("/custom/{ingredient_id}")
async def update_custom_ingredient(ingredient_id: int, payload: dict, db: Session = Depends(get_db)):
    item = db.query(Ingredient).filter(Ingredient.id == ingredient_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Ingredient not found")

    if "name" in payload:
        name = str(payload.get("name", "")).strip()
        if not name:
            raise HTTPException(status_code=400, detail="Ingredient name cannot be empty")
        item.name = name

    if "category" in payload:
        item.category = payload.get("category")
    if "usda_id" in payload:
        item.usda_id = payload.get("usda_id")
    if "nutritional_data" in payload:
        item.nutritional_data = payload.get("nutritional_data") or {}

    db.commit()
    db.refresh(item)
    return _ingredient_to_dict(item)


@router.delete("/custom/{ingredient_id}")
async def delete_custom_ingredient(ingredient_id: int, db: Session = Depends(get_db)):
    item = db.query(Ingredient).filter(Ingredient.id == ingredient_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Ingredient not found")

    db.delete(item)
    db.commit()
    return {"status": "deleted", "id": ingredient_id}


@router.post("/convert")
async def convert_units(payload: dict):
    amount = float(payload.get("amount", 0))
    from_unit = str(payload.get("from_unit", "")).strip().lower()
    to_unit = str(payload.get("to_unit", "")).strip().lower()
    ingredient = str(payload.get("ingredient", "")).strip()

    if amount <= 0 or not from_unit or not to_unit or not ingredient:
        raise HTTPException(status_code=400, detail="ingredient, amount, from_unit and to_unit are required")

    conversion = {
        ("g", "kg"): 0.001,
        ("kg", "g"): 1000.0,
        ("ml", "l"): 0.001,
        ("l", "ml"): 1000.0,
    }
    ratio = conversion.get((from_unit, to_unit), 1.0)
    converted = amount * ratio

    return {
        "ingredient": ingredient,
        "amount": amount,
        "from_unit": from_unit,
        "to_unit": to_unit,
        "converted_amount": converted,
        "approximate": (from_unit, to_unit) not in conversion,
    }


@router.get("/seasonal")
async def get_seasonal_ingredients(
    season: str | None = Query(None, max_length=30),
    location: str | None = Query(None, max_length=100),
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
):
    # Placeholder seasonal logic until provider integration is added.
    items = db.query(Ingredient).order_by(Ingredient.name.asc()).limit(limit).all()
    return [
        {
            **_ingredient_to_dict(item),
            "season": season or "all",
            "location": location or "global",
        }
        for item in items
    ]


@router.get("/{ingredient_id}")
async def get_ingredient_by_id(ingredient_id: int, db: Session = Depends(get_db)):
    item = db.query(Ingredient).filter(Ingredient.id == ingredient_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Ingredient not found")
    return _ingredient_to_dict(item)
