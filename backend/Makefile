.PHONY: help install run test clean docker-build docker-run

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install: ## Install Python dependencies
	pip install -e .

run: ## Run the FastAPI server
	uvicorn meal_planning.main:app --reload

test: ## Run tests
	pytest tests/ -v

test-cov: ## Run tests with coverage
	pytest --cov=meal_planning --cov-report=html

lint: ## Run linting
	flake8 meal_planning tests
	black --check meal_planning tests
	mypy meal_planning

format: ## Format code
	black meal_planning tests

docker-build: ## Build Docker image
	docker build -t meal-planning-backend .

docker-run: ## Run with Docker Compose
	docker-compose up -d

docker-stop: ## Stop Docker Compose
	docker-compose down

clean: ## Clean up
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -delete
	rm -rf .coverage htmlcov

migrate: ## Run database migrations
	alembic upgrade head

migrate-create: ## Create new migration
	alembic revision --autogenerate -m "$(msg)"