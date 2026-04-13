# System Architecture

## High-Level Architecture

```mermaid
graph TB
    A[Flutter Mobile App] --> B[API Gateway]
    B --> C[Auth Service]
    B --> D[User Service]
    B --> E[ML Inference Service]
    B --> F[Recommendation Service]
    B --> G[Recipe Service]
    B --> H[Nutrition Service]

    C --> I[(PostgreSQL)]
    D --> I
    F --> I
    G --> I
    H --> I

    E --> J[Redis Cache]
    F --> J
    G --> J

    E --> K[ML Models]
    F --> K

    L[Message Queue] --> M[Background Worker]
    M --> I
    M --> J

    N[Monitoring Stack] --> B
    N --> C
    N --> D
    N --> E
    N --> F
    N --> G
    N --> H
```

## Component Diagram

```mermaid
graph TB
    subgraph "Client Layer"
        A[Flutter App]
    end

    subgraph "API Gateway Layer"
        B[FastAPI Gateway]
        B1[Rate Limiting]
        B2[Authentication]
        B3[Request Routing]
    end

    subgraph "Service Layer"
        C[Auth Service]
        D[User Profile Service]
        E[ML Inference Service]
        F[Recommendation Engine]
        G[Recipe Service]
        H[Nutrition Service]
        I[Notification Service]
        J[Analytics Service]
    end

    subgraph "Data Layer"
        K[(PostgreSQL)]
        L[(Redis)]
        M[(S3/Minio)]
    end

    subgraph "Infrastructure"
        N[Kubernetes]
        O[Prometheus]
        P[Grafana]
        Q[ELK Stack]
    end

    A --> B
    B --> B1
    B --> B2
    B --> B3
    B3 --> C
    B3 --> D
    B3 --> E
    B3 --> F
    B3 --> G
    B3 --> H
    B3 --> I
    B3 --> J

    C --> K
    D --> K
    F --> K
    G --> K
    H --> K
    J --> K

    E --> L
    F --> L
    G --> L

    E --> M
    G --> M

    N --> O
    N --> P
    N --> Q
```

## Data Flow Diagram

```mermaid
sequenceDiagram
    participant U as User
    participant A as Flutter App
    participant G as API Gateway
    participant M as ML Service
    participant D as Database
    participant C as Cache

    U->>A: Take food photo
    A->>G: Upload image + auth token
    G->>G: Validate token
    G->>M: Send image for analysis
    M->>M: Preprocess image
    M->>M: Run inference
    M->>C: Check cache for nutrition data
    C-->>M: Return cached data
    M->>D: Query ingredient database
    D-->>M: Return nutritional info
    M->>M: Calculate totals
    M-->>G: Return analysis results
    G-->>A: Return food analysis
    A->>G: Log meal with analysis
    G->>D: Store meal data
    D-->>G: Confirm storage
    G-->>A: Success response
```

## Database Schema

```mermaid
erDiagram
    USERS ||--o{ MEALS : logs
    USERS ||--o{ RECIPES : creates
    USERS ||--o{ RECIPE_RATINGS : rates
    USERS ||--o{ USER_NUTRITION_GOALS : sets

    RECIPES ||--o{ RECIPE_INGREDIENTS : contains
    RECIPES ||--o{ RECIPE_RATINGS : receives

    INGREDIENTS ||--o{ RECIPE_INGREDIENTS : used_in
    INGREDIENTS ||--o{ MEAL_FOOD_ITEMS : detected_in

    MEALS ||--o{ MEAL_FOOD_ITEMS : contains

    USERS {
        integer id PK
        string email UK
        string hashed_password
        string full_name
        boolean is_active
        json dietary_restrictions
        json allergies
        json cuisine_preferences
        json dietary_preferences
        json fitness_goals
        string timezone
    }

    RECIPES {
        integer id PK
        string title
        text description
        text instructions
        integer prep_time_minutes
        integer cook_time_minutes
        integer servings
        string difficulty
        string cuisine
        json dietary_tags
        integer created_by FK
        float calories
        float protein_g
        float carbs_g
        float fat_g
    }

    INGREDIENTS {
        integer id PK
        string name UK
        string category
        string usda_id
        json nutritional_data
    }

    MEALS {
        integer id PK
        integer user_id FK
        string meal_type
        datetime logged_at
        string image_url
        json ai_analysis
        float total_calories
        float total_protein
        float total_carbs
        float total_fat
    }
```

## ML Pipeline Architecture

```mermaid
graph LR
    A[Training Data] --> B[Data Preprocessing]
    B --> C[Model Training]
    C --> D[Model Validation]
    D --> E[Model Registry]
    E --> F[Model Deployment]
    F --> G[Inference Service]

    H[User Feedback] --> I[Data Collection]
    I --> J[Model Retraining]
    J --> E

    G --> K[Performance Monitoring]
    K --> L[Drift Detection]
    L --> J

    M[A/B Testing] --> N[Model Comparison]
    N --> O[Model Selection]
    O --> F
```

## Security Architecture

```mermaid
graph TB
    subgraph "External"
        A[Internet]
    end

    subgraph "Edge Security"
        B[WAF]
        C[Load Balancer]
        D[API Gateway]
    end

    subgraph "Application Security"
        E[JWT Validation]
        F[Input Validation]
        G[Rate Limiting]
        H[CORS]
    end

    subgraph "Service Security"
        I[mTLS]
        J[RBAC]
        K[Secrets Management]
    end

    subgraph "Data Security"
        L[Encryption at Rest]
        M[Encryption in Transit]
        N[Data Masking]
    end

    A --> B
    B --> C
    C --> D
    D --> E
    D --> F
    D --> G
    D --> H
    E --> I
    F --> I
    G --> I
    H --> I
    I --> J
    I --> K
    J --> L
    J --> M
    J --> N
```

## Deployment Architecture

```mermaid
graph TB
    subgraph "CI/CD Pipeline"
        A[Git Push] --> B[Build]
        B --> C[Test]
        C --> D[Security Scan]
        D --> E[Docker Build]
        E --> F[Push to Registry]
        F --> G[Deploy to Staging]
        G --> H[Integration Tests]
        H --> I[Deploy to Production]
    end

    subgraph "Kubernetes Cluster"
        J[Ingress Controller]
        K[API Gateway Pod]
        L[Service Pods]
        M[Database]
        N[Redis]
        O[Monitoring]
    end

    I --> J
    J --> K
    K --> L
    L --> M
    L --> N
    L --> O
```