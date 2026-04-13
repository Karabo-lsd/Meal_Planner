# AI Meal Planning Backend

Production-grade backend for an AI-powered meal planning mobile application built with Flutter.

## Architecture Overview

This backend implements a microservices architecture using FastAPI with the following components:

- **API Gateway**: Request routing, authentication, rate limiting
- **Auth Service**: User management, JWT handling
- **User Profile Service**: Profile data management
- **ML Inference Service**: AI food recognition
- **Recommendation Engine**: Personalized meal suggestions
- **Recipe Service**: Recipe CRUD operations
- **Nutrition Service**: Nutritional calculations
- **Analytics Service**: User behavior tracking

## Tech Stack

- **Framework**: FastAPI (Python)
- **Database**: PostgreSQL with TimescaleDB extension
- **Cache**: Redis
- **Message Queue**: RabbitMQ/Kafka
- **ML**: ONNX Runtime, ResNet-50, EfficientNet
- **Infrastructure**: Kubernetes, Docker
- **Monitoring**: Prometheus, Grafana, ELK Stack

## Features

### Core Functionality
- Secure user authentication (JWT + Auth0 integration)
- AI-powered food image recognition
- Personalized meal recommendations
- Comprehensive recipe database
- Real-time nutrition tracking
- Ingredient-based recipe discovery

### Production Features
- Horizontal scaling with Kubernetes
- Multi-layer caching strategy
- Comprehensive monitoring and observability
- GDPR/CCPA compliance
- Zero-trust security architecture
- Automated CI/CD pipelines

## Quick Start

### Prerequisites
- Docker and Docker Compose
- Python 3.11+

### Local Development

1. Clone the repository
2. Navigate to backend directory
3. Start services:
   ```bash
   docker-compose up -d
   ```
4. Install dependencies:
   ```bash
   pip install -e .
   ```
5. Run the API:
   ```bash
   uvicorn meal_planning.main:app --reload
   ```

### API Documentation

Once running, visit `http://localhost:8000/docs` for interactive API documentation.

## Database Schema

The system uses PostgreSQL with the following key tables:

- `users`: User profiles and authentication
- `recipes`: Recipe data with ingredients
- `meals`: Logged meals with AI analysis
- `ingredients`: Ingredient database with nutritional info
- `user_nutrition_goals`: Daily nutrition targets

## ML Pipeline

### Food Recognition
- **Models**: Ensemble of ResNet-50 and EfficientNet-B3
- **Training Data**: USDA FoodData Central + Food-101 + Recipe1M
- **Inference**: ONNX optimized for edge deployment
- **Accuracy**: Target 90%+ top-5 accuracy

### Recommendation Engine
- Collaborative filtering based on user preferences
- Content-based filtering using nutritional profiles
- Contextual awareness (time, location, weather)
- A/B testing framework for model evaluation

## Security

- **Authentication**: JWT with refresh tokens
- **Authorization**: Role-based access control
- **Data Protection**: AES-256 encryption at rest
- **API Security**: Input validation, rate limiting, CORS
- **Compliance**: GDPR, CCPA data handling

## Deployment

### Production Setup
- Kubernetes manifests in `k8s/` directory
- Terraform scripts for infrastructure
- CI/CD with GitHub Actions
- Blue-green deployment strategy

### Scaling Strategy
- Horizontal pod autoscaling
- Database read replicas
- CDN for static assets
- Global distribution with multi-region setup

## Monitoring

### Metrics
- API response times and error rates
- ML inference latency and accuracy
- Database query performance
- Cache hit ratios

### Logging
- Structured logging with JSON format
- ELK stack for log aggregation
- Error tracking with Sentry

## Development

### Code Structure
```
backend/
├── meal_planning/
│   ├── main.py              # FastAPI app
│   ├── config.py            # Settings
│   ├── database.py          # DB connection
│   ├── models/              # SQLAlchemy models
│   ├── schemas/             # Pydantic schemas
│   ├── services/            # Business logic
│   ├── routers/             # API endpoints
│   └── utils/               # Utilities
├── tests/                   # Unit tests
├── k8s/                     # Kubernetes manifests
├── docker/                  # Docker configs
└── docs/                    # Documentation
```

### Testing
```bash
pytest tests/ -v
```

### Code Quality
- Black for formatting
- Flake8 for linting
- MyPy for type checking
- Pre-commit hooks

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes with tests
4. Submit a pull request

## License

This project is licensed under the MIT License.