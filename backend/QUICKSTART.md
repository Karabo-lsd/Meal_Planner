# Meal Planning Backend - Quick Start

## Prerequisites

- Python 3.11+
- pip

## Installation

1. Install dependencies:
```bash
pip install fastapi uvicorn sqlalchemy pydantic pydantic-settings python-jose cryptography passlib email-validator numpy aiofiles requests
```

## Running the Application

1. Start the server:
```bash
cd backend
python -m uvicorn meal_planning.main:app --host 127.0.0.1 --port 8000 --reload
```

2. Test the API:
```bash
python test_api.py
```

## API Endpoints

- **GET** `/` - API information
- **GET** `/health` - Health check
- **GET** `/docs` - Interactive API documentation
- **POST** `/auth/login` - User login
- **POST** `/auth/register` - User registration
- **GET** `/users/me` - Get current user profile
- **PUT** `/users/me` - Update user profile
- **POST** `/meals/analyze` - Analyze food image
- **POST** `/meals/` - Log a meal
- **GET** `/meals/` - Get user meals

## Database

The application uses SQLite (`meal_planning.db`) for development. For production, configure PostgreSQL in `meal_planning/config.py`.

## Testing

Run the test script:
```bash
python test_api.py
```

## Development

The backend is structured as follows:
- `meal_planning/main.py` - FastAPI application
- `meal_planning/models/` - SQLAlchemy models
- `meal_planning/schemas/` - Pydantic schemas
- `meal_planning/routers/` - API endpoints
- `meal_planning/services/` - Business logic
- `docs/` - Documentation

## Production Deployment

For production deployment, see the Kubernetes manifests in `k8s/` and Docker configuration in `Dockerfile`.