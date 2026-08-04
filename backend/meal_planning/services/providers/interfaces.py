from __future__ import annotations

from typing import Any, Dict, List, Optional, Protocol


class SpoonacularClientInterface(Protocol):
    async def discover_by_ingredients(
        self,
        ingredients: List[str],
        diet_type: Optional[str],
        max_prep_time_minutes: Optional[int],
        limit: int,
    ) -> List[Dict[str, Any]]:
        ...


class EdamamClientInterface(Protocol):
    async def search_diet_aware_recipes(
        self,
        ingredients: List[str],
        diet_labels: List[str],
        health_labels: List[str],
        calories_min: Optional[int],
        calories_max: Optional[int],
        limit: int,
    ) -> List[Dict[str, Any]]:
        ...


class UsdaClientInterface(Protocol):
    async def lookup_food_nutrition(self, query: str) -> Optional[Dict[str, Any]]:
        ...

    async def lookup_by_fdc_id(self, fdc_id: str) -> Optional[Dict[str, Any]]:
        ...


class ImageRecognitionClientInterface(Protocol):
    async def analyze_food_image(self, image_bytes: bytes) -> Dict[str, Any]:
        """
        Returns provider payload with labels, confidence scores,
        and optional portion estimates.
        """
        ...
