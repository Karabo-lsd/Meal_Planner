# Deployment Strategy

## Infrastructure Overview

The system is deployed on Kubernetes with a microservices architecture, utilizing cloud-native tools for scalability, reliability, and observability.

## Kubernetes Architecture

### Cluster Configuration

**Multi-zone Deployment:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-config
data:
  zones: "us-west1-a,us-west1-b,us-west1-c"
  region: "us-west1"
```

### Namespace Strategy

```
meal-planning-prod/
├── api-gateway
├── auth-service
├── user-service
├── ml-service
├── recipe-service
├── nutrition-service
├── monitoring
└── ingress
```

## Service Deployment

### API Gateway

**Deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  namespace: meal-planning-prod
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api-gateway
  template:
    metadata:
      labels:
        app: api-gateway
    spec:
      containers:
      - name: gateway
        image: meal-planning/api-gateway:v1.0.0
        ports:
        - containerPort: 8000
        envFrom:
        - configMapRef:
            name: api-gateway-config
        - secretRef:
            name: api-gateway-secrets
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
```

**Horizontal Pod Autoscaling:**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-gateway-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-gateway
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### ML Inference Service

**GPU-enabled Deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ml-inference
spec:
  replicas: 2
  template:
    spec:
      nodeSelector:
        accelerator: nvidia-tesla-k80
      containers:
      - name: inference
        image: meal-planning/ml-inference:v1.0.0
        ports:
        - containerPort: 5000
        resources:
          limits:
            nvidia.com/gpu: 1
          requests:
            memory: "4Gi"
            cpu: "2"
        env:
        - name: CUDA_VISIBLE_DEVICES
          value: "0"
```

## Database Deployment

### PostgreSQL with Patroni

**StatefulSet:**
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres
  replicas: 3
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15
        ports:
        - containerPort: 5432
        envFrom:
        - secretRef:
            name: postgres-secret
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
      - name: patroni
        image: patroni:latest
        envFrom:
        - configMapRef:
            name: patroni-config
  volumeClaimTemplates:
  - metadata:
      name: postgres-data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 100Gi
```

### Redis Cluster

**Deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        command: ["redis-server", "/etc/redis/redis.conf"]
        volumeMounts:
        - name: redis-config
          mountPath: /etc/redis
        - name: redis-data
          mountPath: /data
      volumes:
      - name: redis-config
        configMap:
          name: redis-config
      - name: redis-data
        persistentVolumeClaim:
          claimName: redis-pvc
```

## Ingress Configuration

### NGINX Ingress Controller

**Ingress Resource:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: meal-planning-api
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - api.mealplanning.com
    secretName: meal-planning-tls
  rules:
  - host: api.mealplanning.com
    http:
      paths:
      - path: /api/v1
        pathType: Prefix
        backend:
          service:
            name: api-gateway
            port:
              number: 80
      - path: /health
        pathType: Exact
        backend:
          service:
            name: api-gateway
            port:
              number: 80
```

## Service Mesh

### Istio Configuration

**Gateway:**
```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: meal-planning-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    tls:
      mode: SIMPLE
      credentialName: meal-planning-tls
    hosts:
    - api.mealplanning.com
```

**Virtual Service:**
```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: meal-planning-api
spec:
  hosts:
  - api.mealplanning.com
  gateways:
  - meal-planning-gateway
  http:
  - match:
    - uri:
        prefix: /api/v1
    route:
    - destination:
        host: api-gateway
        port:
          number: 80
    timeout: 30s
    retries:
      attempts: 3
      perTryTimeout: 10s
```

## Monitoring Stack

### Prometheus

**Deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
spec:
  replicas: 2
  template:
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
        - name: data
          mountPath: /prometheus
      volumes:
      - name: config
        configMap:
          name: prometheus-config
      - name: data
        persistentVolumeClaim:
          claimName: prometheus-pvc
```

### Grafana

**Dashboard Configuration:**
```yaml
apiVersion: apps/v1
kind: ConfigMap
metadata:
  name: grafana-dashboards
data:
  meal-planning.json: |
    {
      "dashboard": {
        "title": "Meal Planning System",
        "panels": [
          {
            "title": "API Response Time",
            "type": "graph",
            "targets": [
              {
                "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))",
                "legendFormat": "P95"
              }
            ]
          }
        ]
      }
    }
```

### ELK Stack

**Elasticsearch Cluster:**
```yaml
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: meal-planning-logging
spec:
  version: 8.5.0
  nodeSets:
  - name: default
    count: 3
    config:
      node.store.allow_mmap: false
    podTemplate:
      spec:
        containers:
        - name: elasticsearch
          resources:
            requests:
              memory: 4Gi
              cpu: 2
            limits:
              memory: 4Gi
              cpu: 2
```

## CI/CD Pipeline

### GitHub Actions

**Build Pipeline:**
```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.11'
    - name: Install dependencies
      run: |
        pip install -e .
        pip install pytest pytest-cov
    - name: Run tests
      run: pytest --cov=meal_planning tests/
    - name: Upload coverage
      uses: codecov/codecov-action@v3

  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
    - name: Build Docker image
      run: docker build -t meal-planning-backend:${{ github.sha }} .
    - name: Push to registry
      run: docker push meal-planning-backend:${{ github.sha }}

  deploy-staging:
    needs: build
    if: github.ref == 'refs/heads/develop'
    runs-on: ubuntu-latest
    steps:
    - name: Deploy to staging
      run: kubectl set image deployment/api-gateway api-gateway=meal-planning-backend:${{ github.sha }} -n staging

  deploy-prod:
    needs: build
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
    - name: Deploy to production
      run: |
        kubectl set image deployment/api-gateway api-gateway=meal-planning-backend:${{ github.sha }} -n prod
        kubectl rollout status deployment/api-gateway -n prod
```

### ArgoCD

**Application Manifest:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: meal-planning-backend
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/meal-planning/backend
    targetRevision: HEAD
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: meal-planning-prod
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Terraform Infrastructure

### VPC Configuration

```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "meal-planning-vpc"
  }
}

resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "meal-planning-private-${count.index}"
  }
}
```

### EKS Cluster

```hcl
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "meal-planning"
  cluster_version = "1.27"

  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id

  eks_managed_node_groups = {
    general = {
      desired_size = 3
      min_size     = 1
      max_size     = 10

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
    }

    gpu = {
      desired_size = 1
      min_size     = 0
      max_size     = 5

      instance_types = ["g4dn.xlarge"]
      capacity_type  = "ON_DEMAND"

      taints = [
        {
          key    = "nvidia.com/gpu"
          value  = "present"
          effect = "NO_SCHEDULE"
        }
      ]
    }
  }
}
```

### RDS PostgreSQL

```hcl
resource "aws_db_instance" "postgres" {
  identifier             = "meal-planning-postgres"
  engine                 = "postgres"
  engine_version         = "15.4"
  instance_class         = "db.r6g.large"
  allocated_storage      = 100
  max_allocated_storage  = 1000
  storage_encrypted      = true
  kms_key_id             = aws_kms_key.rds.arn

  db_name  = "meal_planning"
  username = "meal_user"
  password = random_password.db_password.result

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  backup_retention_period = 30
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  multi_az = true

  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = {
    Name = "meal-planning-postgres"
  }
}
```

### ElastiCache Redis

```hcl
resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "meal-planning-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.redis.id]

  tags = {
    Name = "meal-planning-redis"
  }
}
```

## Cost Optimization

### Auto Scaling

**Cluster Autoscaler:**
```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: api-gateway-vpa
spec:
  targetRef:
    apiVersion: "apps/v1"
    kind:       "Deployment"
    name:       "api-gateway"
  updatePolicy:
    updateMode: "Auto"
```

### Spot Instances

**Node Group with Spot:**
```hcl
eks_managed_node_groups = {
  spot = {
    desired_size = 5
    min_size     = 0
    max_size     = 20

    instance_types = ["t3.medium", "t3.large"]
    capacity_type  = "SPOT"

    spot_allocation_strategy = "diversified"
  }
}
```

### Reserved Instances

**Compute Savings Plan:**
```hcl
resource "aws_savingsplans_plan" "compute" {
  commitment     = "50.00"
  commitment_unit = "USD"
  plan_type      = "ComputeSavingsPlans"
  term_length    = "1_year"
  offering_id    = "12345678-1234-1234-1234-123456789012"
}
```

## Disaster Recovery

### Multi-region Setup

**Cross-region Replication:**
```hcl
resource "aws_db_instance" "postgres_replica" {
  replicate_source_db = aws_db_instance.postgres.id
  instance_class      = "db.r6g.large"

  # Read replica in different region
  provider = aws.us-east-1
}
```

### Backup Strategy

**Automated Backups:**
```hcl
resource "aws_backup_plan" "meal_planning" {
  name = "meal-planning-backup-plan"

  rule {
    rule_name         = "daily_backups"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 5 ? * * *)"

    lifecycle {
      delete_after = 30
    }
  }
}
```

### Failover Strategy

**Route 53 Health Checks:**
```hcl
resource "aws_route53_health_check" "api" {
  fqdn              = "api.mealplanning.com"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = "3"
  request_interval  = "30"

  tags = {
    Name = "meal-planning-api-health-check"
  }
}
```

## Performance Testing

### Load Testing

**K6 Script:**
```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 100 }, // Ramp up to 100 users
    { duration: '5m', target: 100 }, // Stay at 100 users
    { duration: '2m', target: 200 }, // Ramp up to 200 users
    { duration: '5m', target: 200 }, // Stay at 200 users
    { duration: '2m', target: 0 },   // Ramp down to 0 users
  ],
};

export default function () {
  let response = http.get('https://api.mealplanning.com/api/v1/recipes');
  check(response, { 'status is 200': (r) => r.status === 200 });
  sleep(1);
}
```

### Chaos Engineering

**Pod Chaos:**
```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: api-gateway-pod-kill
spec:
  action: pod-kill
  mode: all
  selector:
    namespaces:
      - meal-planning-prod
    labelSelectors:
      app: api-gateway
  scheduler:
    cron: "@every 30m"
```

## Compliance & Auditing

### CloudTrail

**Audit Logging:**
```hcl
resource "aws_cloudtrail" "main" {
  name                          = "meal-planning-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  s3_key_prefix                 = "cloudtrail"
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::meal-planning-data/*"]
    }
  }
}
```

### Config Rules

**Security Compliance:**
```hcl
resource "aws_config_config_rule" "s3_bucket_versioning" {
  name = "s3-bucket-versioning-enabled"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_VERSIONING_ENABLED"
  }
}
```

This deployment strategy ensures high availability, scalability, and security for the meal planning application, with comprehensive monitoring and automated recovery capabilities.