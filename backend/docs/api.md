# API Specifications

## Overview

The API follows RESTful principles with JSON request/response formats. All endpoints require authentication except for health checks and authentication endpoints.

## Authentication

### JWT Token Authentication

All protected endpoints require a Bearer token in the Authorization header:

```
Authorization: Bearer <jwt_token>
```

### Token Refresh

Tokens expire after 30 minutes. Use refresh tokens for seamless authentication.

## Base URL

```
https://api.mealplanning.com/v1
```

## Endpoints

### Authentication

#### POST /auth/login
Login with email and password.

**Request:**
```json
{
  "username": "user@example.com",
  "password": "password123"
}
```

**Response:**
```json
{
  "access_token": "eyJ0eXAi...",
  "token_type": "bearer"
}
```

#### POST /auth/register
Register a new user.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "password123",
  "full_name": "John Doe",
  "age": 30,
  "weight_kg": 75.5,
  "height_cm": 175.0,
  "dietary_restrictions": ["gluten-free"],
  "allergies": ["nuts"],
  "cuisine_preferences": ["italian", "mexican"],
  "dietary_preferences": ["vegetarian"],
  "fitness_goals": ["weight_loss"]
}
```

### Users

#### GET /users/me
Get current user profile.

**Response:**
```json
{
  "id": 1,
  "email": "user@example.com",
  "full_name": "John Doe",
  "age": 30,
  "weight_kg": 75.5,
  "height_cm": 175.0,
  "dietary_restrictions": ["gluten-free"],
  "allergies": ["nuts"],
  "cuisine_preferences": ["italian", "mexican"],
  "dietary_preferences": ["vegetarian"],
  "fitness_goals": ["weight_loss"],
  "created_at": "2024-01-01T00:00:00Z"
}
```

#### PUT /users/me
Update user profile.

### Meals

#### POST /meals/analyze
Analyze food image.

**Request:** Multipart form data with image file.

**Response:**
```json
{
  "detected_items": [
    {
      "name": "Grilled Chicken",
      "confidence": 0.95,
      "portion_grams": 150,
      "nutrition": {
        "calories": 231,
        "protein_g": 43,
        "carbs_g": 0,
        "fat_g": 5
      }
    }
  ],
  "total_nutrition": {
    "calories": 231,
    "protein_g": 43,
    "carbs_g": 0,
    "fat_g": 5
  },
  "processing_time_ms": 450
}
```

#### POST /meals/
Log a meal.

**Request:**
```json
{
  "meal_type": "lunch",
  "image_url": "https://...",
  "manual_entry": false
}
```

**Response:**
```json
{
  "id": 123,
  "user_id": 1,
  "meal_type": "lunch",
  "logged_at": "2024-01-01T12:00:00Z",
  "ai_analysis": {...},
  "total_calories": 231,
  "total_protein": 43,
  "total_carbs": 0,
  "total_fat": 5,
  "food_items": [...]
}
```

#### GET /meals/
Get user's meals.

**Query Parameters:**
- `skip`: Number of meals to skip (default: 0)
- `limit`: Maximum number of meals to return (default: 100)

### Recipes

#### GET /recipes/
Search recipes.

**Query Parameters:**
- `q`: Search query
- `cuisine`: Filter by cuisine
- `dietary_tags`: Filter by dietary tags (comma-separated)
- `max_calories`: Maximum calories per serving
- `ingredients`: Available ingredients (comma-separated)

#### GET /recipes/{id}
Get recipe details.

#### POST /recipes/
Create new recipe.

#### PUT /recipes/{id}
Update recipe.

#### DELETE /recipes/{id}
Delete recipe.

### Nutrition Goals

#### GET /nutrition/goals
Get user's nutrition goals.

#### POST /nutrition/goals
Set nutrition goals.

**Request:**
```json
{
  "date": "2024-01-01",
  "calories_target": 2000,
  "protein_target": 150,
  "carbs_target": 250,
  "fat_target": 67
}
```

## Rate Limiting

- **Authenticated requests**: 1000 requests per hour
- **Image analysis**: 50 requests per hour
- **Search requests**: 500 requests per hour

Rate limit headers are included in responses:
```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1609459200
```

## Error Responses

All errors follow this format:

```json
{
  "detail": "Error message",
  "type": "error_type",
  "code": "ERROR_CODE"
}
```

### Common Error Codes

- `VALIDATION_ERROR`: Invalid request data
- `AUTHENTICATION_ERROR`: Invalid or missing credentials
- `AUTHORIZATION_ERROR`: Insufficient permissions
- `NOT_FOUND`: Resource not found
- `RATE_LIMITED`: Too many requests
- `INTERNAL_ERROR`: Server error

## WebSocket Endpoints

### Real-time Nutrition Tracking

```
ws://api.mealplanning.com/v1/ws/nutrition/{user_id}
```

**Messages:**

**Server → Client:**
```json
{
  "type": "nutrition_update",
  "data": {
    "date": "2024-01-01",
    "current_calories": 1200,
    "target_calories": 2000,
    "meals_logged": 2
  }
}
```

**Client → Server:**
```json
{
  "type": "subscribe",
  "channels": ["nutrition", "recommendations"]
}
```

## Pagination

List endpoints support pagination:

```json
{
  "items": [...],
  "total": 100,
  "page": 1,
  "size": 20,
  "pages": 5
}
```

## Versioning

API versioning is done via URL path:

- `/v1/` - Current stable version
- `/v2/` - Next version (when available)

## Content Types

- **Request**: `application/json`
- **Response**: `application/json`
- **File Upload**: `multipart/form-data`

## CORS

CORS is enabled for the Flutter app origins. Preflight requests are handled automatically.

## Compression

Responses are compressed using gzip for requests accepting `gzip` encoding.

## Caching

- **GET requests**: Cached for 5 minutes
- **Static assets**: Cached for 1 hour with CDN
- **Cache headers**: `Cache-Control`, `ETag`, `Last-Modified`