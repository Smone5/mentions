# Environment Setup

## Overview
This document provides step-by-step instructions for setting up development, staging, and production environments.

**IMPORTANT**: All GCP infrastructure should be managed via **Terraform** for consistency across environments. See **[28-TERRAFORM-INFRASTRUCTURE.md](./28-TERRAFORM-INFRASTRUCTURE.md)** for complete Terraform setup.

All Terraform code goes in: `mentions_terraform/`

This document provides manual setup instructions for reference and local development only. For production deployments, always use Terraform.

---

## Prerequisites

### Required Tools
- **Node.js** 18+ and npm/pnpm
- **Python** 3.11+
- **Docker** and Docker Compose
- **Git**
- **gcloud CLI** (Google Cloud SDK)
- **psql** (PostgreSQL client)

### Required Accounts
- **Supabase** account
- **Google Cloud** account with billing enabled
- **OpenAI** API account
- **Reddit** account(s) for testing

---

## 1. GCP Project Setup

**⚠️ RECOMMENDED: Use Terraform Instead**

All GCP infrastructure should be managed via Terraform. See **[28-TERRAFORM-INFRASTRUCTURE.md](./28-TERRAFORM-INFRASTRUCTURE.md)** for the recommended approach.

The following manual commands are provided for reference only:

<details>
<summary>Manual GCP Setup (Click to expand - Not recommended for production)</summary>

### Create Projects
```bash
# Development
gcloud projects create mentions-dev --name="Mentions Dev"

# Staging
gcloud projects create mentions-staging --name="Mentions Staging"

# Production
gcloud projects create mentions-prod --name="Mentions Prod"
```

### Set Active Project
```bash
gcloud config set project mentions-dev
```

### Enable Required APIs
```bash
gcloud services enable \
  run.googleapis.com \
  cloudtasks.googleapis.com \
  cloudscheduler.googleapis.com \
  secretmanager.googleapis.com \
  cloudkms.googleapis.com \
  artifactregistry.googleapis.com
```

### Create KMS Keyring and Key
```bash
# Create keyring
gcloud kms keyrings create reddit-secrets \
  --location=us-central1

# Create encryption key
gcloud kms keys create reddit-token-key \
  --location=us-central1 \
  --keyring=reddit-secrets \
  --purpose=encryption

# Grant Cloud Run service account access
gcloud kms keys add-iam-policy-binding reddit-token-key \
  --location=us-central1 \
  --keyring=reddit-secrets \
  --member="serviceAccount:PROJECT_NUMBER-compute@developer.gserviceaccount.com" \
  --role="roles/cloudkms.cryptoKeyEncrypterDecrypter"
```

### Create Task Queues
```bash
# Create a default queue (per-company queues created dynamically)
gcloud tasks queues create reddit-posts-default \
  --location=us-central1 \
  --max-attempts=3 \
  --max-concurrent-dispatches=10
```

</details>

---

## 2. Supabase Setup

### Create Projects
1. Go to [supabase.com](https://supabase.com)
2. Create three projects:
   - `mentions-dev`
   - `mentions-stg`
   - `mentions-prod`

### Enable Extensions
For each project, run in SQL Editor:

```sql
-- Enable pgvector for RAG
create extension if not exists vector;

-- Enable UUID generation
create extension if not exists "uuid-ossp";
```

### Get Credentials
Save these for each environment:
- **Project URL**: `https://xxx.supabase.co`
- **Anon Key**: Public key for frontend
- **Service Role Key**: Private key for backend (keep secret)

### Configure Auth
1. Go to Authentication → Settings
2. Enable Email provider
3. Configure email templates (optional)
4. Set JWT expiry (default 1 hour is fine)
5. Add redirect URLs for your frontend:
   - Dev: `http://localhost:3000/auth/callback`
   - Prod: `https://yourdomain.com/auth/callback`

---

## 3. Secret Manager Setup

### Store OpenAI API Key
```bash
echo -n "sk-..." | gcloud secrets create openai-api-key \
  --data-file=- \
  --replication-policy="automatic"

# Grant access to Cloud Run
gcloud secrets add-iam-policy-binding openai-api-key \
  --member="serviceAccount:PROJECT_NUMBER-compute@developer.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### Store Supabase Service Role Key
```bash
echo -n "eyJ..." | gcloud secrets create supabase-service-role-key \
  --data-file=- \
  --replication-policy="automatic"

gcloud secrets add-iam-policy-binding supabase-service-role-key \
  --member="serviceAccount:PROJECT_NUMBER-compute@developer.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

---

## 4. Backend Setup

### Clone Repository
```bash
git clone https://github.com/yourorg/mentions.git
cd mentions/mentions_backend
```

### Create Virtual Environment
```bash
python3.11 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### Install Dependencies
```bash
pip install -r requirements.txt
```

### Create `.env` File
```bash
cp .env.example .env
```

Edit `.env`:
```bash
# Environment
ENV=dev

# Supabase
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ...
DB_CONN=postgresql://postgres:password@db.xxx.supabase.co:5432/postgres

# OpenAI
OPENAI_API_KEY=sk-...

# GCP
GOOGLE_PROJECT_ID=mentions-dev
GOOGLE_LOCATION=us-central1
KMS_KEYRING=reddit-secrets
KMS_KEY=reddit-token-key

# Safety
ALLOW_POSTS=false

# API
API_HOST=0.0.0.0
API_PORT=8000
```

### Run Database Migrations
```bash
# Using raw SQL files
psql $DB_CONN -f db/migrations/001_initial_schema.sql
psql $DB_CONN -f db/migrations/002_add_pgvector.sql
# ... etc

# Or use Alembic (if configured)
alembic upgrade head
```

### Start Backend
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Test: `curl http://localhost:8000/health`

---

## 5. Frontend Setup

### Navigate to Frontend
```bash
cd mentions/mentions_frontend
```

### Install Dependencies
```bash
npm install
# or
pnpm install
```

### Create `.env.local` File
```bash
cp .env.example .env.local
```

Edit `.env.local`:
```bash
NEXT_PUBLIC_ENV=dev
NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...
NEXT_PUBLIC_API_URL=http://localhost:8000
```

### Start Frontend
```bash
npm run dev
```

Visit: `http://localhost:3000`

---

## 6. Local Development with Docker Compose

### Create `docker-compose.yml`
```yaml
version: '3.8'

services:
  postgres:
    image: pgvector/pgvector:pg16
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: mentions_dev
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./mentions_backend/db/migrations:/docker-entrypoint-initdb.d

  backend:
    build: ./mentions_backend
    ports:
      - "8000:8000"
    environment:
      - ENV=dev
      - DB_CONN=postgresql://postgres:postgres@postgres:5432/mentions_dev
      - ALLOW_POSTS=false
    env_file:
      - ./mentions_backend/.env
    depends_on:
      - postgres
    volumes:
      - ./mentions_backend:/app
    command: uvicorn main:app --reload --host 0.0.0.0 --port 8000

  frontend:
    build: ./mentions_frontend
    ports:
      - "3000:3000"
    environment:
      - NEXT_PUBLIC_API_URL=http://localhost:8000
    env_file:
      - ./mentions_frontend/.env.local
    volumes:
      - ./mentions_frontend:/app
      - /app/node_modules
    command: npm run dev

volumes:
  postgres_data:
```

### Start All Services
```bash
docker-compose up -d
```

---

## 7. Reddit App Setup (Per Company)

### Create Reddit App
1. Go to [reddit.com/prefs/apps](https://www.reddit.com/prefs/apps)
2. Click "create another app..."
3. Choose "web app"
4. Name: `mentions-{company_name}`
5. Redirect URI: `https://yourdomain.com/api/reddit/callback`
   - Dev: `http://localhost:3000/api/reddit/callback`
6. Save **client_id** and **client_secret**

### Store in Application
- Company admins will enter these in UI
- Backend encrypts with KMS before storing
- See **M1-FOUNDATIONS.md** for implementation details

---

## 8. Environment Variables Reference

### Backend (`.env`)
| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `ENV` | Environment name | Yes | `dev` |
| `SUPABASE_URL` | Supabase project URL | Yes | - |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key | Yes | - |
| `DB_CONN` | PostgreSQL connection string | Yes | - |
| `OPENAI_API_KEY` | OpenAI API key | Yes | - |
| `GOOGLE_PROJECT_ID` | GCP project ID | Yes | - |
| `GOOGLE_LOCATION` | GCP region | Yes | `us-central1` |
| `KMS_KEYRING` | KMS keyring name | Yes | - |
| `KMS_KEY` | KMS key name | Yes | - |
| `ALLOW_POSTS` | Enable actual posting | Yes | `false` |
| `API_HOST` | API host | No | `0.0.0.0` |
| `API_PORT` | API port | No | `8000` |
| `LOG_LEVEL` | Logging level (DEBUG/INFO/WARNING/ERROR) | No | `INFO` |
| `LOG_JSON` | Output logs as JSON (for GCP) | No | `true` |

### Frontend (`.env.local`)
| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `NEXT_PUBLIC_ENV` | Environment name | Yes | `dev` |
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase URL | Yes | - |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Supabase anon key | Yes | - |
| `NEXT_PUBLIC_API_URL` | Backend API URL | Yes | - |

---

## 9. Deployment

### Backend to Cloud Run with Docker

#### Step 1: Create Dockerfile

Create `mentions_backend/Dockerfile`:

```dockerfile
# Use Python 3.11 slim image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first (for better caching)
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create non-root user
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run uvicorn
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

#### Step 2: Create .dockerignore

Create `mentions_backend/.dockerignore`:

```
__pycache__
*.pyc
*.pyo
*.pyd
.Python
env/
venv/
pip-log.txt
pip-delete-this-directory.txt
.tox/
.coverage
.coverage.*
.cache
nosetests.xml
coverage.xml
*.cover
*.log
.git
.gitignore
.mypy_cache
.pytest_cache
.hypothesis
*.db
*.sqlite3
.env
.env.*
*.md
tests/
docs/
```

#### Step 3: Create requirements.txt

Create `mentions_backend/requirements.txt`:

```
fastapi==0.109.0
uvicorn[standard]==0.27.0
pydantic==2.6.0
pydantic-settings==2.1.0
asyncpg==0.29.0
supabase==2.3.0
openai==1.12.0
langchain==0.1.6
langchain-core==0.1.23
langchain-openai==0.0.5
langgraph==0.0.20
asyncpraw==7.7.1
httpx==0.26.0
google-cloud-kms==2.20.0
google-cloud-tasks==2.15.0
google-cloud-secret-manager==2.17.0
python-multipart==0.0.6
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
```

#### Step 4: Test Docker Build Locally

```bash
cd mentions_backend

# Build image locally
docker build -t mentions-backend:test .

# Run container locally
docker run -p 8000:8000 \
  -e ENV=dev \
  -e SUPABASE_URL=https://xxx.supabase.co \
  -e OPENAI_API_KEY=sk-... \
  mentions-backend:test

# Test health endpoint
curl http://localhost:8000/health
```

#### Step 5: Build and Push to GCP

**Option A: Using Cloud Build (Recommended)**

```bash
cd mentions_backend

# Build and push to Container Registry
gcloud builds submit --tag gcr.io/mentions-dev/backend:latest

# Or use Artifact Registry (recommended for new projects)
gcloud builds submit --tag us-central1-docker.pkg.dev/mentions-dev/mentions/backend:latest
```

**Option B: Build Locally and Push**

```bash
cd mentions_backend

# Configure Docker to use gcloud as credential helper
gcloud auth configure-docker

# Build image
docker build -t gcr.io/mentions-dev/backend:latest .

# Push to Container Registry
docker push gcr.io/mentions-dev/backend:latest
```

#### Step 6: Deploy to Cloud Run

**Development Environment:**

```bash
gcloud run deploy mentions-backend \
  --image gcr.io/mentions-dev/backend:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --service-account mentions-backend@mentions-dev.iam.gserviceaccount.com \
  --set-env-vars ENV=dev,ALLOW_POSTS=false \
  --set-env-vars GOOGLE_PROJECT_ID=mentions-dev \
  --set-env-vars GOOGLE_LOCATION=us-central1 \
  --set-env-vars KMS_KEYRING=reddit-secrets \
  --set-env-vars KMS_KEY=reddit-token-key \
  --set-env-vars SUPABASE_URL=https://xxx.supabase.co \
  --set-secrets OPENAI_API_KEY=openai-api-key:latest \
  --set-secrets SUPABASE_SERVICE_ROLE_KEY=supabase-service-role-key:latest \
  --set-secrets DB_CONN=db-connection-string:latest \
  --max-instances 10 \
  --min-instances 0 \
  --memory 1Gi \
  --cpu 1 \
  --concurrency 80 \
  --timeout 300 \
  --port 8000
```

**Production Environment:**

```bash
gcloud run deploy mentions-backend \
  --image gcr.io/mentions-prod/backend:v1.0.0 \
  --platform managed \
  --region us-central1 \
  --no-allow-unauthenticated \
  --service-account mentions-backend@mentions-prod.iam.gserviceaccount.com \
  --set-env-vars ENV=prod,ALLOW_POSTS=true \
  --set-env-vars GOOGLE_PROJECT_ID=mentions-prod \
  --set-env-vars GOOGLE_LOCATION=us-central1 \
  --set-env-vars KMS_KEYRING=reddit-secrets \
  --set-env-vars KMS_KEY=reddit-token-key \
  --set-env-vars SUPABASE_URL=https://yyy.supabase.co \
  --set-secrets OPENAI_API_KEY=openai-api-key:latest \
  --set-secrets SUPABASE_SERVICE_ROLE_KEY=supabase-service-role-key:latest \
  --set-secrets DB_CONN=db-connection-string:latest \
  --max-instances 50 \
  --min-instances 1 \
  --memory 2Gi \
  --cpu 2 \
  --concurrency 80 \
  --timeout 300 \
  --port 8000
```

#### Step 7: Verify Deployment

```bash
# Get service URL
SERVICE_URL=$(gcloud run services describe mentions-backend \
  --region us-central1 \
  --format 'value(status.url)')

echo "Service URL: $SERVICE_URL"

# Test health endpoint
curl $SERVICE_URL/health

# Test with authentication (if not allow-unauthenticated)
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  $SERVICE_URL/health
```

#### Step 8: Set Up CI/CD (Optional)

Create `.github/workflows/deploy-backend.yml`:

```yaml
name: Deploy Backend to Cloud Run

on:
  push:
    branches:
      - main
    paths:
      - 'mentions_backend/**'
  workflow_dispatch:

env:
  PROJECT_ID: mentions-prod
  REGION: us-central1
  SERVICE_NAME: mentions-backend

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v1
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}
      
      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v1
      
      - name: Build and push Docker image
        run: |
          cd mentions_backend
          gcloud builds submit \
            --tag gcr.io/$PROJECT_ID/$SERVICE_NAME:$GITHUB_SHA \
            --tag gcr.io/$PROJECT_ID/$SERVICE_NAME:latest
      
      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy $SERVICE_NAME \
            --image gcr.io/$PROJECT_ID/$SERVICE_NAME:$GITHUB_SHA \
            --region $REGION \
            --platform managed \
            --set-env-vars ENV=prod,ALLOW_POSTS=true \
            --set-secrets OPENAI_API_KEY=openai-api-key:latest \
            --set-secrets SUPABASE_SERVICE_ROLE_KEY=supabase-service-role-key:latest \
            --max-instances 50 \
            --memory 2Gi
      
      - name: Verify deployment
        run: |
          SERVICE_URL=$(gcloud run services describe $SERVICE_NAME \
            --region $REGION \
            --format 'value(status.url)')
          curl -f $SERVICE_URL/health || exit 1
```

#### Deployment Best Practices

**Version Tagging:**
```bash
# Tag with git commit SHA
gcloud builds submit --tag gcr.io/mentions-prod/backend:${GITHUB_SHA}

# Tag with semantic version
gcloud builds submit --tag gcr.io/mentions-prod/backend:v1.2.3

# Always tag latest
gcloud builds submit --tag gcr.io/mentions-prod/backend:latest
```

**Rollback:**
```bash
# List previous revisions
gcloud run revisions list --service mentions-backend --region us-central1

# Rollback to specific revision
gcloud run services update-traffic mentions-backend \
  --region us-central1 \
  --to-revisions mentions-backend-00042-abc=100
```

**Gradual Rollout:**
```bash
# Route 10% traffic to new version, 90% to old
gcloud run services update-traffic mentions-backend \
  --region us-central1 \
  --to-revisions mentions-backend-00043-def=10,mentions-backend-00042-abc=90
```

### Frontend to Vercel (Recommended)

1. Connect GitHub repo to Vercel
2. Set environment variables in Vercel dashboard
3. Deploy automatically on push to main

### Frontend to Cloud Run (Alternative)

```bash
cd mentions_frontend

# Build
gcloud builds submit --tag gcr.io/mentions-dev/frontend:latest

# Deploy
gcloud run deploy mentions-frontend \
  --image gcr.io/mentions-dev/frontend:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars NEXT_PUBLIC_ENV=dev \
  --set-env-vars NEXT_PUBLIC_API_URL=https://backend-xxx.run.app \
  --max-instances 10
```

---

## 10. Verification Checklist

### Backend
- [ ] `/health` endpoint returns 200
- [ ] Can connect to Supabase Postgres
- [ ] Can encrypt/decrypt with KMS
- [ ] OpenAI API key works
- [ ] Logs show correct environment

### Frontend
- [ ] App loads at localhost:3000
- [ ] Can sign up and log in
- [ ] Supabase auth works
- [ ] API calls reach backend
- [ ] No console errors

### Database
- [ ] All migrations applied
- [ ] `pgvector` extension enabled
- [ ] Can query tables
- [ ] RLS policies (after M1)

### GCP
- [ ] Cloud Run services deployed
- [ ] Task queues created
- [ ] Secrets accessible
- [ ] KMS encryption works

---

## 11. Troubleshooting

### Database Connection Fails
- Check `DB_CONN` string format
- Verify Supabase project is active
- Check firewall rules
- Confirm credentials are correct

### KMS Encryption Fails
- Verify service account has `cloudkms.cryptoKeyEncrypterDecrypter` role
- Check key location matches `GOOGLE_LOCATION`
- Confirm key exists: `gcloud kms keys list --keyring=reddit-secrets --location=us-central1`

### Reddit OAuth Fails
- Check redirect URI matches exactly (including trailing slash)
- Verify client_id and client_secret
- Ensure scopes are correct
- Check Reddit app type is "web app"

### Cloud Tasks Not Processing
- Verify queue exists
- Check service account permissions
- Confirm target URL is accessible
- Review task logs in GCP Console

---

## Next Steps
1. Complete this environment setup
2. Run database migrations from **03-DATABASE-SCHEMA.md**
3. Start **M1-FOUNDATIONS.md** milestone

