# Database Design

## Overview

The system uses PostgreSQL as the primary database with TimescaleDB extension for time-series data. The database is designed for high performance, scalability, and data integrity.

## Schema Design Principles

- **Normalization**: 3NF to reduce redundancy
- **Indexing Strategy**: Composite indexes on frequent query patterns
- **Partitioning**: Time-based partitioning for historical data
- **Constraints**: Foreign keys, check constraints, and triggers
- **Audit Trail**: Automatic timestamp updates and audit logging

## Core Tables

### Users Table

```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    hashed_password VARCHAR(255),
    full_name VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    is_superuser BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Profile data
    age INTEGER,
    weight_kg DECIMAL(5,2),
    height_cm DECIMAL(5,2),
    dietary_restrictions JSONB,
    allergies JSONB,
    cuisine_preferences JSONB,
    dietary_preferences JSONB,
    fitness_goals JSONB,
    timezone VARCHAR(50) DEFAULT 'UTC',

    -- Auth0 integration
    auth0_id VARCHAR(255) UNIQUE,
    social_provider VARCHAR(50)
);

-- Indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_auth0_id ON users(auth0_id);
CREATE INDEX idx_users_active ON users(is_active);
```

### Recipes Table

```sql
CREATE TABLE recipes (
    id SERIAL PRIMARY KEY,
    title VARCHAR(500) NOT NULL,
    description TEXT,
    instructions TEXT,
    prep_time_minutes INTEGER,
    cook_time_minutes INTEGER,
    servings INTEGER DEFAULT 1,
    difficulty VARCHAR(20) CHECK (difficulty IN ('easy', 'medium', 'hard')),
    cuisine VARCHAR(100),
    dietary_tags JSONB,
    created_by INTEGER REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Nutritional info per serving
    calories DECIMAL(7,2),
    protein_g DECIMAL(6,2),
    carbs_g DECIMAL(6,2),
    fat_g DECIMAL(6,2),
    fiber_g DECIMAL(6,2)
);

-- Indexes
CREATE INDEX idx_recipes_created_by ON recipes(created_by);
CREATE INDEX idx_recipes_cuisine ON recipes(cuisine);
CREATE INDEX idx_recipes_dietary_tags ON recipes USING GIN(dietary_tags);
CREATE INDEX idx_recipes_title_trgm ON recipes USING GIN(title gin_trgm_ops);
```

### Ingredients Table

```sql
CREATE TABLE ingredients (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) UNIQUE NOT NULL,
    category VARCHAR(100),
    usda_id VARCHAR(20),
    nutritional_data JSONB,  -- calories, macros, etc. per 100g
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_ingredients_name ON ingredients(name);
CREATE INDEX idx_ingredients_category ON ingredients(category);
CREATE INDEX idx_ingredients_usda_id ON ingredients(usda_id);
```

### Recipe Ingredients Junction Table

```sql
CREATE TABLE recipe_ingredients (
    id SERIAL PRIMARY KEY,
    recipe_id INTEGER REFERENCES recipes(id) ON DELETE CASCADE,
    ingredient_id INTEGER REFERENCES ingredients(id),
    quantity DECIMAL(8,3),
    unit VARCHAR(50),
    UNIQUE(recipe_id, ingredient_id)
);

-- Indexes
CREATE INDEX idx_recipe_ingredients_recipe_id ON recipe_ingredients(recipe_id);
CREATE INDEX idx_recipe_ingredients_ingredient_id ON recipe_ingredients(ingredient_id);
```

### Meals Table (Time-Series)

```sql
CREATE TABLE meals (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    meal_type VARCHAR(20) CHECK (meal_type IN ('breakfast', 'lunch', 'dinner', 'snack')),
    logged_at TIMESTAMPTZ DEFAULT NOW(),
    image_url VARCHAR(500),
    manual_entry BOOLEAN DEFAULT FALSE,

    -- AI analysis results
    ai_analysis JSONB,
    total_calories DECIMAL(7,2),
    total_protein DECIMAL(6,2),
    total_carbs DECIMAL(6,2),
    total_fat DECIMAL(6,2)
) PARTITION BY RANGE (logged_at);

-- Create monthly partitions (example for 2024)
CREATE TABLE meals_2024_01 PARTITION OF meals
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
-- ... create partitions for each month

-- Indexes
CREATE INDEX idx_meals_user_id ON meals(user_id);
CREATE INDEX idx_meals_logged_at ON meals(logged_at);
CREATE INDEX idx_meals_user_logged_at ON meals(user_id, logged_at);
```

### Meal Food Items Table

```sql
CREATE TABLE meal_food_items (
    id SERIAL PRIMARY KEY,
    meal_id INTEGER REFERENCES meals(id) ON DELETE CASCADE,
    ingredient_id INTEGER REFERENCES ingredients(id),
    quantity_g DECIMAL(7,2),
    confidence_score DECIMAL(3,2)
);

-- Indexes
CREATE INDEX idx_meal_food_items_meal_id ON meal_food_items(meal_id);
CREATE INDEX idx_meal_food_items_ingredient_id ON meal_food_items(ingredient_id);
```

### User Nutrition Goals Table

```sql
CREATE TABLE user_nutrition_goals (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    date DATE NOT NULL,
    calories_target DECIMAL(7,2),
    protein_target DECIMAL(6,2),
    carbs_target DECIMAL(6,2),
    fat_target DECIMAL(6,2),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, date)
);

-- Indexes
CREATE INDEX idx_user_nutrition_goals_user_date ON user_nutrition_goals(user_id, date);
```

### Recipe Ratings Table

```sql
CREATE TABLE recipe_ratings (
    id SERIAL PRIMARY KEY,
    recipe_id INTEGER REFERENCES recipes(id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id),
    rating DECIMAL(2,1) CHECK (rating >= 1 AND rating <= 5),
    review TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(recipe_id, user_id)
);

-- Indexes
CREATE INDEX idx_recipe_ratings_recipe_id ON recipe_ratings(recipe_id);
CREATE INDEX idx_recipe_ratings_user_id ON recipe_ratings(user_id);
```

## Performance Optimizations

### Indexing Strategy

1. **Primary Keys**: Automatically indexed
2. **Foreign Keys**: Automatically indexed for referential integrity
3. **Frequently Queried Columns**: Single column indexes
4. **Composite Indexes**: For multi-column WHERE clauses
5. **Partial Indexes**: For filtered queries
6. **GIN Indexes**: For JSONB and full-text search
7. **BRIN Indexes**: For time-series data

### Partitioning Strategy

- **Time-based Partitioning**: Monthly partitions for meals table
- **Range Partitioning**: Based on logged_at timestamp
- **Automatic Partition Creation**: Via triggers or cron jobs
- **Partition Pruning**: Automatic query optimization

### Query Optimization

```sql
-- Example: Get user's meals for date range
SELECT * FROM meals
WHERE user_id = $1 AND logged_at >= $2 AND logged_at < $3
ORDER BY logged_at DESC;

-- Uses composite index: idx_meals_user_logged_at
```

### Connection Pooling

Using PgBouncer for connection pooling:

```
[pgbouncer]
listen_addr = 0.0.0.0
listen_port = 6432
auth_type = md5
auth_file = /etc/pgbouncer/userlist.txt
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 20
reserve_pool_size = 5
```

## Backup and Recovery

### Backup Strategy

1. **Full Backups**: Weekly using pg_dump
2. **Incremental Backups**: Daily WAL archiving
3. **Point-in-Time Recovery**: Enabled via WAL
4. **Replica Backups**: From read replicas

### Recovery Procedures

```bash
# Restore from backup
pg_restore -d meal_planning /backups/full_backup.sql

# Point-in-time recovery
recovery_target_time = '2024-01-01 12:00:00'
```

## Migration Strategy

Using Alembic for schema migrations:

```python
# alembic/env.py
from meal_planning.database import Base
target_metadata = Base.metadata
```

## Monitoring

### Key Metrics

- Query execution time
- Connection count
- Cache hit ratio
- Replication lag
- Table bloat

### Alerts

- Long-running queries (>5s)
- High connection count (>80% of max)
- Replication lag (>30s)
- Disk space usage (>85%)

## Scaling Considerations

### Read Replicas

```sql
-- Create read replica
CREATE PUBLICATION meal_planning_pub FOR ALL TABLES;
CREATE SUBSCRIPTION meal_planning_sub
    CONNECTION 'host=primary_host dbname=meal_planning user=repl_user'
    PUBLICATION meal_planning_pub;
```

### Sharding Strategy

- **Vertical Sharding**: Separate databases for different services
- **Horizontal Sharding**: Hash-based sharding by user_id
- **Federation**: For multi-region deployments

## Security

### Data Protection

- **Encryption at Rest**: Using pgcrypto extension
- **Row Level Security**: For multi-tenant data isolation
- **Audit Logging**: Via audit triggers

### Access Control

```sql
-- Create roles
CREATE ROLE app_user LOGIN PASSWORD 'password';
CREATE ROLE readonly_user LOGIN PASSWORD 'password';

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO app_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;
```