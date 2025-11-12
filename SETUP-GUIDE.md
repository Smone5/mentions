# Environment Setup Guide

This guide walks you through setting up all required environments for the Mentions project.

## Prerequisites

Before starting, ensure you have:

1. **Google Cloud Account** with billing enabled
   - Get your billing account ID from GCP Console → Billing
2. **Supabase Account** (free tier is fine for dev)
3. **Vercel Account** (free tier is fine)
4. **OpenAI API Key** (for LLM functionality)
5. **GitHub Account** (repositories already created)

## Quick Start

Run the automated setup script:

```bash
cd /Users/amelton/mentions
./scripts/setup-environments.sh
```

Or follow the manual steps below.

---

## Step 1: Google Cloud Platform Setup

### 1.1 Create GCP Projects

You need three projects: `mentions-dev`, `mentions-staging`, `mentions-prod`

**Option A: Using the setup script**
```bash
./scripts/setup-environments.sh
# Choose option 1: Google Cloud Projects
```

**Option B: Manual creation**
```bash
# Get your billing account ID first
gcloud billing accounts list

# Create projects
gcloud projects create mentions-dev --name="Mentions Dev"
gcloud projects create mentions-staging --name="Mentions Staging"
gcloud projects create mentions-prod --name="Mentions Prod"

# Link billing (replace BILLING_ACCOUNT_ID)
gcloud billing projects link mentions-dev --billing-account=BILLING_ACCOUNT_ID
gcloud billing projects link mentions-staging --billing-account=BILLING_ACCOUNT_ID
gcloud billing projects link mentions-prod --billing-account=BILLING_ACCOUNT_ID
```

### 1.2 Enable Required APIs

For each project (dev, staging, prod):

```bash
gcloud config set project mentions-dev  # or mentions-staging, mentions-prod

gcloud services enable \
  run.googleapis.com \
  cloudtasks.googleapis.com \
  cloudscheduler.googleapis.com \
  secretmanager.googleapis.com \
  cloudkms.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  compute.googleapis.com \
  storage.googleapis.com
```

### 1.3 Create Terraform State Buckets

```bash
# Dev
gcloud storage buckets create gs://mentions-terraform-state-dev \
  --project=mentions-dev \
  --location=us-central1 \
  --uniform-bucket-level-access

gcloud storage buckets update gs://mentions-terraform-state-dev --versioning

# Staging
gcloud storage buckets create gs://mentions-terraform-state-staging \
  --project=mentions-staging \
  --location=us-central1 \
  --uniform-bucket-level-access

gcloud storage buckets update gs://mentions-terraform-state-staging --versioning

# Prod
gcloud storage buckets create gs://mentions-terraform-state-prod \
  --project=mentions-prod \
  --location=us-central1 \
  --uniform-bucket-level-access

gcloud storage buckets update gs://mentions-terraform-state-prod --versioning
```

### 1.4 Initialize Terraform

```bash
cd mentions_terraform/environments/dev

# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values:
# - billing_account
# - supabase_url (after Step 2)
# - project_id (should be mentions-dev)

# Initialize Terraform backend
../../scripts/init-backend.sh dev

# Plan and apply
terraform init
terraform plan
terraform apply
```

**Repeat for staging and prod environments.**

---

## Step 2: Supabase Setup

### 2.1 Create Projects

1. Go to [supabase.com](https://supabase.com) and sign in
2. Click "New Project"
3. Create three projects:
   - **mentions-dev** (Development)
   - **mentions-stg** (Staging)
   - **mentions-prod** (Production)

For each project:
- Choose a strong database password (save it!)
- Select a region close to your users
- Wait for project to finish provisioning (~2 minutes)

### 2.2 Enable Extensions

For each project, go to **SQL Editor** and run:

```sql
-- Enable pgvector for RAG
CREATE EXTENSION IF NOT EXISTS vector;

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
```

### 2.3 Get Credentials

For each project, go to **Settings → API**:

1. **Project URL**: `https://xxx.supabase.co`
2. **Anon Key**: Public key (safe for frontend)
3. **Service Role Key**: Private key (keep secret! Backend only)

Save these credentials - you'll need them for:
- Terraform variables (`supabase_url`)
- Secret Manager (service role key)
- Frontend environment variables (anon key)

### 2.4 Configure Authentication

For each project, go to **Authentication → Settings**:

1. Enable **Email** provider
2. Configure **Site URL**:
   - Dev: `http://localhost:3000`
   - Prod: `https://yourdomain.com`
3. Add **Redirect URLs**:
   - Dev: `http://localhost:3000/auth/callback`
   - Prod: `https://yourdomain.com/auth/callback`

### 2.5 Get Database Connection String

For each project, go to **Settings → Database**:

1. Find **Connection string** section
2. Copy the **URI** format connection string
3. Format: `postgresql://postgres:[PASSWORD]@db.xxx.supabase.co:5432/postgres`
4. Replace `[PASSWORD]` with your database password

**Save this for Secret Manager** (Step 4.3)

---

## Step 3: Vercel Setup

### 3.1 Connect Repository

1. Go to [vercel.com](https://vercel.com) and sign in
2. Click **Add New Project**
3. Import GitHub repository: `mentions-frontend`
4. Configure project:
   - Framework Preset: **Next.js**
   - Root Directory: `./` (default)
   - Build Command: `npm run build` (default)
   - Output Directory: `.next` (default)

### 3.2 Configure Environment Variables

For each environment (Development, Preview, Production), add:

```
NEXT_PUBLIC_ENV=dev  # or staging, prod
NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...
NEXT_PUBLIC_API_URL=https://backend-xxx.run.app  # After backend is deployed
```

**Note**: You can create separate Vercel projects for dev/staging/prod, or use environment-specific variables in one project.

### 3.3 Deploy

Click **Deploy** - Vercel will build and deploy automatically.

---

## Step 4: Configure Secrets

### 4.1 Store OpenAI API Key

```bash
# Set active project
gcloud config set project mentions-dev

# Create secret (if not created by Terraform)
echo -n "sk-..." | gcloud secrets create openai-api-key \
  --data-file=- \
  --replication-policy="automatic"

# Or add new version to existing secret
echo -n "sk-..." | gcloud secrets versions add openai-api-key --data-file=-
```

**Repeat for staging and prod.**

### 4.2 Store Supabase Service Role Key

```bash
gcloud config set project mentions-dev

echo -n "eyJ..." | gcloud secrets create supabase-service-role-key \
  --data-file=- \
  --replication-policy="automatic"

# Or add version
echo -n "eyJ..." | gcloud secrets versions add supabase-service-role-key --data-file=-
```

**Repeat for staging and prod with their respective keys.**

### 4.3 Store Database Connection String

```bash
gcloud config set project mentions-dev

echo -n "postgresql://postgres:password@db.xxx.supabase.co:5432/postgres" | \
  gcloud secrets create db-connection-string \
    --data-file=- \
    --replication-policy="automatic"

# Or add version
echo -n "postgresql://..." | gcloud secrets versions add db-connection-string --data-file=-
```

**Repeat for staging and prod.**

---

## Step 5: Apply Terraform Infrastructure

### 5.1 Development Environment

```bash
cd mentions_terraform/environments/dev

# Ensure terraform.tfvars is configured
# Then apply
terraform init
terraform plan
terraform apply
```

This will create:
- ✅ KMS keyring and keys
- ✅ Service accounts
- ✅ Secret Manager secrets (empty - you set values manually)
- ✅ Cloud Tasks queues
- ⏳ Cloud Run service (commented out until backend image exists)

### 5.2 Staging Environment

```bash
cd ../staging
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars
../../scripts/init-backend.sh staging
terraform init
terraform plan
terraform apply
```

### 5.3 Production Environment

```bash
cd ../prod
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars
../../scripts/init-backend.sh prod
terraform init
terraform plan
terraform apply
```

---

## Step 6: Verify Setup

### 6.1 Check GCP Resources

```bash
# List projects
gcloud projects list | grep mentions

# Check APIs enabled
gcloud services list --project=mentions-dev

# Check KMS keys
gcloud kms keyrings list --location=us-central1 --project=mentions-dev
gcloud kms keys list --keyring=reddit-secrets --location=us-central1 --project=mentions-dev

# Check secrets
gcloud secrets list --project=mentions-dev

# Check service accounts
gcloud iam service-accounts list --project=mentions-dev

# Check Cloud Tasks queues
gcloud tasks queues list --location=us-central1 --project=mentions-dev
```

### 6.2 Check Supabase

- [ ] All three projects created
- [ ] Extensions enabled (vector, uuid-ossp)
- [ ] Auth configured
- [ ] Credentials saved

### 6.3 Check Vercel

- [ ] Project connected to GitHub
- [ ] Environment variables configured
- [ ] Deployment successful

---

## Step 7: Update Progress Tracker

Update `ENVIRONMENT-SETUP-PROGRESS.md` with your completed steps.

---

## Next Steps

After environment setup:

1. **Run Database Migrations**
   - See `docs/03-DATABASE-SCHEMA.md`
   - Connect to Supabase and run migration SQL files

2. **Build and Deploy Backend**
   - See `docs/02-ENVIRONMENT-SETUP.md` section 9
   - Build Docker image
   - Deploy to Cloud Run

3. **Test End-to-End**
   - Verify health endpoints
   - Test authentication flow
   - Test API connectivity

---

## Troubleshooting

### GCP Project Creation Fails

- Ensure billing account is active
- Check project ID is globally unique
- Verify you have proper permissions

### Terraform Backend Init Fails

- Ensure state bucket exists
- Check bucket permissions
- Verify project is set correctly

### Supabase Extensions Fail

- Ensure you're using the SQL Editor
- Check you have proper permissions
- Verify PostgreSQL version supports extensions

### Secrets Not Accessible

- Check service account has `secretmanager.secretAccessor` role
- Verify secret exists: `gcloud secrets list`
- Check secret version: `gcloud secrets versions list SECRET_NAME`

---

## Quick Reference

### GCP Projects
- Dev: `mentions-dev`
- Staging: `mentions-staging`
- Prod: `mentions-prod`

### Supabase Projects
- Dev: `mentions-dev`
- Staging: `mentions-stg`
- Prod: `mentions-prod`

### Terraform State Buckets
- Dev: `gs://mentions-terraform-state-dev`
- Staging: `gs://mentions-terraform-state-staging`
- Prod: `gs://mentions-terraform-state-prod`

### Key Resources
- KMS Keyring: `reddit-secrets`
- KMS Key: `reddit-token-key`
- Service Account: `mentions-backend@{project}.iam.gserviceaccount.com`

---

## Support

- See `docs/02-ENVIRONMENT-SETUP.md` for detailed instructions
- See `docs/28-TERRAFORM-INFRASTRUCTURE.md` for Terraform details
- See `ENVIRONMENT-SETUP-PROGRESS.md` to track your progress


