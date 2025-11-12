# Variables Setup Checklist

This document lists all variables and secrets that need to be configured for the Mentions project.

---

## 1. Terraform Variables (`terraform.tfvars`)

**Location**: `mentions_terraform/environments/dev/terraform.tfvars`

| Variable | Description | Status | Value |
|----------|-------------|--------|-------|
| `project_id` | GCP Project ID | ✅ Set | `mention001` |
| `region` | GCP Region | ✅ Set | `us-central1` |
| `billing_account` | GCP Billing Account ID | ⏳ **NEEDED** | Get from GCP Console → Billing |
| `org_id` | GCP Organization ID | ⏸️ Optional | Leave empty if not using org |
| `supabase_url` | Supabase project URL | ⏳ **NEEDED** | After creating Supabase project |
| `backend_image` | Container image URL | ✅ Set | `gcr.io/mention001/backend:latest` |

**Action**: Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in missing values.

---

## 2. GCP Secret Manager Secrets

**Location**: Stored in GCP Secret Manager (created by Terraform, values set manually)

| Secret Name | Description | Status | How to Set |
|-------------|-------------|--------|------------|
| `openai-api-key` | OpenAI API key | ⏳ **NEEDED** | `gcloud secrets versions add openai-api-key --data-file=-` |
| `supabase-service-role-key` | Supabase service role key | ⏳ **NEEDED** | Get from Supabase Settings → API |
| `db-connection-string` | PostgreSQL connection string | ⏳ **NEEDED** | Get from Supabase Settings → Database |
| `stripe-secret-key` | Stripe secret key (optional) | ⏸️ Optional | For payment processing |
| `stripe-webhook-secret` | Stripe webhook secret (optional) | ⏸️ Optional | For payment webhooks |

**Commands to set secrets**:
```bash
# Set OpenAI API key
echo -n "sk-..." | gcloud secrets versions add openai-api-key --data-file=-

# Set Supabase service role key
echo -n "eyJ..." | gcloud secrets versions add supabase-service-role-key --data-file=-

# Set database connection string
echo -n "postgresql://postgres:password@db.xxx.supabase.co:5432/postgres" | \
  gcloud secrets versions add db-connection-string --data-file=-
```

---

## 3. Backend Environment Variables (`.env`)

**Location**: `mentions_backend/.env` (for local development)

| Variable | Description | Status | Value |
|----------|-------------|--------|-------|
| `ENV` | Environment name | ✅ Set | `dev` |
| `SUPABASE_URL` | Supabase project URL | ⏳ **NEEDED** | From Supabase dashboard |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase service role key | ⏳ **NEEDED** | From Supabase Settings → API |
| `DB_CONN` | PostgreSQL connection string | ⏳ **NEEDED** | From Supabase Settings → Database |
| `OPENAI_API_KEY` | OpenAI API key | ⏳ **NEEDED** | Your OpenAI API key |
| `GOOGLE_PROJECT_ID` | GCP Project ID | ✅ Set | `mention001` |
| `GOOGLE_LOCATION` | GCP Region | ✅ Set | `us-central1` |
| `KMS_KEYRING` | KMS keyring name | ✅ Set | `reddit-secrets` |
| `KMS_KEY` | KMS key name | ✅ Set | `reddit-token-key` |
| `ALLOW_POSTS` | Enable actual posting | ✅ Set | `false` (dev) |
| `API_HOST` | API host | ✅ Set | `0.0.0.0` |
| `API_PORT` | API port | ✅ Set | `8000` |
| `LOG_LEVEL` | Logging level | ✅ Set | `DEBUG` (dev) |
| `LOG_JSON` | Output logs as JSON | ✅ Set | `false` (local dev) |

**Note**: For Cloud Run deployment, these are set via Terraform (env_vars and secrets).

---

## 4. Frontend Environment Variables (`.env.local`)

**Location**: `mentions_frontend/.env.local` (for local development)

| Variable | Description | Status | Value |
|----------|-------------|--------|-------|
| `NEXT_PUBLIC_ENV` | Environment name | ✅ Set | `dev` |
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase project URL | ⏳ **NEEDED** | From Supabase dashboard |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Supabase anon key (public) | ⏳ **NEEDED** | From Supabase Settings → API |
| `NEXT_PUBLIC_API_URL` | Backend API URL | ⏳ **NEEDED** | `http://localhost:8000` (local) or Cloud Run URL (deployed) |
| `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` | Stripe publishable key (optional) | ⏸️ Optional | For payment UI |

**Note**: Variables prefixed with `NEXT_PUBLIC_` are exposed to the browser.

---

## 5. Vercel Environment Variables

**Location**: Vercel Dashboard → Project Settings → Environment Variables

| Variable | Description | Status | Value |
|----------|-------------|--------|-------|
| `NEXT_PUBLIC_ENV` | Environment name | ⏳ **NEEDED** | `dev`, `staging`, or `prod` |
| `NEXT_PUBLIC_SUPABASE_URL` | Supabase project URL | ⏳ **NEEDED** | From Supabase dashboard |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Supabase anon key | ⏳ **NEEDED** | From Supabase Settings → API |
| `NEXT_PUBLIC_API_URL` | Backend API URL | ⏳ **NEEDED** | Cloud Run service URL (after deployment) |

**Note**: Set these separately for Development, Preview, and Production environments in Vercel.

---

## 6. Supabase Configuration

**Location**: Supabase Dashboard (web interface)

### Required Setup:
- [ ] Create project: `mentions-dev` (or similar)
- [ ] Enable extensions:
  - [ ] `vector` (pgvector)
  - [ ] `uuid-ossp`
- [ ] Get credentials:
  - [ ] Project URL
  - [ ] Anon key (public, for frontend)
  - [ ] Service role key (private, for backend)
- [ ] Get database connection string
- [ ] Configure Auth:
  - [ ] Enable Email provider
  - [ ] Set Site URL: `http://localhost:3000` (dev)
  - [ ] Add redirect URL: `http://localhost:3000/auth/callback` (dev)

---

## 7. GCP Configuration

**Location**: Google Cloud Console

### Required Setup:
- [x] Project created: `mention001`
- [ ] Billing account linked
- [ ] APIs enabled:
  - [ ] Cloud Run API
  - [ ] Cloud Tasks API
  - [ ] Cloud Scheduler API
  - [ ] Secret Manager API
  - [ ] Cloud KMS API
  - [ ] Artifact Registry API
  - [ ] Cloud Build API
  - [ ] Compute Engine API
  - [ ] Cloud Storage API
- [ ] Terraform state bucket created: `mention001-terraform-state`
- [ ] KMS keyring created: `reddit-secrets` (via Terraform)
- [ ] KMS key created: `reddit-token-key` (via Terraform)
- [ ] Service account created: `mentions-backend@mention001.iam.gserviceaccount.com` (via Terraform)
- [ ] Cloud Tasks queues created (via Terraform)

---

## Priority Order for Setup

### Phase 1: Core Infrastructure (Do First)
1. ✅ GCP Project: `mention001` (already exists)
2. ⏳ Enable GCP APIs
3. ⏳ Create Terraform state bucket
4. ⏳ Get GCP billing account ID (for Terraform)

### Phase 2: Supabase Setup
5. ⏳ Create Supabase project
6. ⏳ Enable extensions
7. ⏳ Get Supabase credentials (URL, anon key, service role key)
8. ⏳ Get database connection string

### Phase 3: Terraform & Secrets
9. ⏳ Configure `terraform.tfvars` with billing account and Supabase URL
10. ⏳ Run `terraform apply` to create infrastructure
11. ⏳ Set Secret Manager secrets (OpenAI, Supabase, DB)

### Phase 4: Local Development
12. ⏳ Create `mentions_backend/.env` file
13. ⏳ Create `mentions_frontend/.env.local` file
14. ⏳ Test local development

### Phase 5: Deployment
15. ⏳ Build and deploy backend to Cloud Run
16. ⏳ Configure Vercel environment variables
17. ⏳ Deploy frontend to Vercel

---

## Quick Setup Commands

### Get GCP Billing Account ID
```bash
gcloud billing accounts list
```

### Enable GCP APIs
```bash
gcloud config set project mention001
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

### Create Terraform State Bucket
```bash
gcloud storage buckets create gs://mention001-terraform-state \
  --project=mention001 \
  --location=us-central1 \
  --uniform-bucket-level-access

gcloud storage buckets update gs://mention001-terraform-state --versioning
```

### Initialize Terraform
```bash
cd mentions_terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
../../scripts/init-backend.sh dev
terraform init
terraform plan
terraform apply
```

---

## Status Legend

- ✅ **Set** - Already configured
- ⏳ **NEEDED** - Required, not yet set
- ⏸️ **Optional** - Nice to have, can be added later
- 🔒 **Secret** - Sensitive value, store in Secret Manager

---

## Next Steps

1. Get your GCP billing account ID
2. Create Supabase project
3. Configure `terraform.tfvars`
4. Run Terraform to create infrastructure
5. Set Secret Manager secrets
6. Create local `.env` files for development

See `SETUP-GUIDE.md` for detailed step-by-step instructions.

