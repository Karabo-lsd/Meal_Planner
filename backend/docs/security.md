# Security Implementation

## Zero-Trust Architecture

The system implements a comprehensive zero-trust security model with defense-in-depth strategies.

## Authentication & Authorization

### JWT Implementation

**Token Generation:**
```python
from jose import jwt
from datetime import datetime, timedelta

def create_access_token(data: dict):
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=30)
    to_encode.update({"exp": expire, "iat": datetime.utcnow()})
    encoded_jwt = jwt.encode(
        to_encode,
        settings.secret_key,
        algorithm=settings.algorithm
    )
    return encoded_jwt
```

**Token Validation:**
```python
def verify_token(token: str):
    try:
        payload = jwt.decode(
            token,
            settings.secret_key,
            algorithms=[settings.algorithm]
        )
        # Additional validation
        if payload.get("exp") < datetime.utcnow():
            raise HTTPException(status_code=401, detail="Token expired")
        return payload
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")
```

### Auth0 Integration

**Configuration:**
```python
auth0_config = {
    'domain': 'mealplanning.auth0.com',
    'api_audience': 'https://api.mealplanning.com',
    'issuer': 'https://mealplanning.auth0.com/',
    'algorithms': ['RS256']
}
```

**Social Login Flow:**
1. Client initiates OAuth flow
2. Auth0 handles authentication
3. JWT returned to client
4. Backend validates JWT with Auth0 public keys

### MFA Implementation

**TOTP Setup:**
```python
import pyotp

def generate_totp_secret():
    return pyotp.random_base32()

def verify_totp(secret, token):
    totp = pyotp.TOTP(secret)
    return totp.verify(token)
```

## Data Protection

### Encryption at Rest

**Database Encryption:**
```sql
-- Enable pgcrypto extension
CREATE EXTENSION pgcrypto;

-- Encrypt sensitive data
UPDATE users
SET encrypted_data = pgp_sym_encrypt(
    sensitive_data,
    'encryption_key'
);
```

**File Storage Encryption:**
```python
from cryptography.fernet import Fernet

def encrypt_file(file_path, key):
    fernet = Fernet(key)
    with open(file_path, 'rb') as f:
        data = f.read()
    encrypted = fernet.encrypt(data)
    with open(file_path + '.encrypted', 'wb') as f:
        f.write(encrypted)
```

### Encryption in Transit

**TLS Configuration:**
```nginx
server {
    listen 443 ssl http2;
    server_name api.mealplanning.com;

    ssl_certificate /etc/ssl/certs/mealplanning.crt;
    ssl_certificate_key /etc/ssl/private/mealplanning.key;
    ssl_protocols TLSv1.3 TLSv1.2;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
    ssl_prefer_server_ciphers off;
}
```

### PII Data Handling

**Data Anonymization:**
```python
def anonymize_user_data(user_data):
    # Remove PII
    anonymized = user_data.copy()
    anonymized.pop('email', None)
    anonymized.pop('full_name', None)

    # Hash identifiers
    anonymized['user_hash'] = hashlib.sha256(
        str(user_data['id']).encode()
    ).hexdigest()

    return anonymized
```

## API Security

### Input Validation

**Pydantic Models:**
```python
from pydantic import BaseModel, validator
from typing import Optional

class UserCreate(BaseModel):
    email: EmailStr
    password: str

    @validator('password')
    def password_strength(cls, v):
        if len(v) < 8:
            raise ValueError('Password too short')
        return v
```

**SQL Injection Prevention:**
```python
# Using SQLAlchemy ORM (safe by default)
user = session.query(User).filter(User.email == email).first()

# Parameterized queries
cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
```

### Rate Limiting

**Redis-based Rate Limiting:**
```python
import redis
from fastapi import Request, HTTPException

redis_client = redis.Redis()

def rate_limit(request: Request, limit: int = 100):
    client_ip = request.client.host
    key = f"rate_limit:{client_ip}"

    current = redis_client.get(key)
    if current and int(current) >= limit:
        raise HTTPException(status_code=429, detail="Rate limit exceeded")

    redis_client.incr(key)
    redis_client.expire(key, 3600)  # 1 hour
```

### CORS Configuration

**Secure CORS Setup:**
```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://app.mealplanning.com",
        "https://www.mealplanning.com"
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
    max_age=86400  # 24 hours
)
```

## Infrastructure Security

### Network Security

**Security Groups (AWS):**
```terraform
resource "aws_security_group" "api" {
  name_prefix = "meal-planning-api"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

### Container Security

**Docker Security Best Practices:**
```dockerfile
# Use distroless base image
FROM gcr.io/distroless/python3

# Non-root user
USER appuser

# Minimal attack surface
RUN apt-get remove --purge -y curl wget && \
    apt-get autoremove -y && \
    apt-get clean

# Read-only filesystem
VOLUME ["/tmp"]
```

### Secrets Management

**HashiCorp Vault Integration:**
```python
import hvac

client = hvac.Client(url='https://vault.mealplanning.com')

def get_secret(path):
    response = client.secrets.kv.v2.read_secret_version(path=path)
    return response['data']['data']
```

**AWS KMS for Encryption:**
```python
import boto3

kms = boto3.client('kms')

def encrypt_data(data):
    response = kms.encrypt(
        KeyId='alias/meal-planning-key',
        Plaintext=data.encode()
    )
    return response['CiphertextBlob']

def decrypt_data(encrypted_data):
    response = kms.decrypt(
        CiphertextBlob=encrypted_data
    )
    return response['Plaintext'].decode()
```

## Monitoring & Auditing

### Security Event Logging

**Structured Security Logs:**
```python
import structlog

def log_security_event(event_type, user_id, details):
    structlog.get_logger().info(
        "security_event",
        event_type=event_type,
        user_id=user_id,
        details=details,
        timestamp=datetime.utcnow().isoformat()
    )
```

### Audit Trail

**Database Audit Triggers:**
```sql
CREATE TABLE audit_log (
    id SERIAL PRIMARY KEY,
    table_name TEXT,
    operation TEXT,
    old_values JSONB,
    new_values JSONB,
    user_id INTEGER,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION audit_trigger_func() RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_log (table_name, operation, old_values, new_values, user_id)
    VALUES (TG_TABLE_NAME, TG_OP, row_to_json(OLD), row_to_json(NEW), current_user_id());
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_audit_trigger
    AFTER INSERT OR UPDATE OR DELETE ON users
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_func();
```

### Intrusion Detection

**Fail2Ban Configuration:**
```ini
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
```

## Compliance

### GDPR Implementation

**Data Subject Rights:**
```python
def handle_data_deletion(user_id):
    # Anonymize user data
    session.query(User).filter(User.id == user_id).update({
        'email': None,
        'full_name': f'anonymized_{user_id}',
        'is_active': False
    })

    # Delete associated data
    session.query(Meal).filter(Meal.user_id == user_id).delete()
    session.query(RecipeRating).filter(RecipeRating.user_id == user_id).delete()

    session.commit()
```

**Consent Management:**
```python
class ConsentRecord(Base):
    __tablename__ = "consent_records"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    consent_type = Column(String)  # marketing, analytics, etc.
    consented = Column(Boolean)
    timestamp = Column(DateTime, default=datetime.utcnow)
```

### CCPA Compliance

**Data Sale Opt-out:**
```python
def process_ccpa_request(user_id, request_type):
    if request_type == "do_not_sell":
        # Opt out of data sales
        update_user_preferences(user_id, {'data_sales_opt_out': True})
    elif request_type == "delete_data":
        # Delete all user data
        delete_user_data(user_id)
```

## Incident Response

### Security Incident Playbook

1. **Detection**
   - Monitor security alerts
   - Review access logs
   - Check for anomalies

2. **Assessment**
   - Determine scope of breach
   - Assess data exposure
   - Notify legal/compliance

3. **Containment**
   - Disable compromised accounts
   - Block malicious IPs
   - Isolate affected systems

4. **Recovery**
   - Restore from clean backups
   - Rotate credentials
   - Update security measures

5. **Lessons Learned**
   - Post-mortem analysis
   - Update security policies
   - Implement preventive measures

### Communication Plan

**Stakeholder Notification:**
- **Immediate (< 24h)**: Internal security team
- **Within 72h**: Affected users (if PII exposed)
- **As required**: Regulatory authorities

## Penetration Testing

### Regular Testing Schedule

- **Quarterly**: Automated vulnerability scans
- **Bi-annually**: External penetration testing
- **Annually**: Red team exercises

### Common Test Cases

```python
# SQL Injection Test
def test_sql_injection():
    payload = "'; DROP TABLE users; --"
    response = client.post("/api/login", json={"email": payload})
    assert response.status_code == 400

# XSS Test
def test_xss():
    payload = "<script>alert('xss')</script>"
    response = client.post("/api/recipes", json={"title": payload})
    assert "<script>" not in response.text
```

## Security Headers

**Helmet.js Configuration:**
```javascript
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
}));
```

## Future Security Enhancements

### Advanced Threats

1. **AI-powered Threat Detection**: ML models for anomaly detection
2. **Behavioral Analysis**: User behavior profiling
3. **Zero-day Protection**: Advanced endpoint protection
4. **Supply Chain Security**: SBOM and dependency scanning

### Emerging Technologies

1. **Homomorphic Encryption**: Privacy-preserving computation
2. **Confidential Computing**: TEE-based data protection
3. **Blockchain**: Immutable audit trails
4. **Quantum-resistant Crypto**: Post-quantum cryptography