# Google Cloud Platform Setup Guide

**Project**: `mention001` (Project Number: 666103574212)

---

## Quick Setup Checklist

- [ ] Get billing account ID
- [ ] Enable required APIs
- [ ] Create Terraform state bucket
- [ ] Initialize Terraform backend
- [ ] Configure Terraform variables
- [ ] Apply Terraform infrastructure
- [ ] Verify resources created

---

## Step 1: Get Billing Account ID

```bash
gcloud billing accounts list
```

Copy the `ACCOUNT_ID` (format: `XXXXX-XXXXX-XXXXX`)

---

## Step 2: Enable Required APIs

```bash
# Set active project
gcloud config set project mention001

# Enable all required APIs
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

# Verify APIs are enabled
gcloud services list --enabled
```

---

## Step 3: Create Terraform State Bucket

```bash
# Create bucket
gcloud storage buckets create gs://mention001-terraform-state \
  --project=mention001 \
  --location=us-central1 \
  --uniform-bucket-level-access

# Enable versioning (for state rollback)
gcloud storage buckets update gs://mention001-terraform-state --versioning

# Verify bucket exists
gcloud storage buckets describe gs://mention001-terraform-state
```

---

## Step 4: Configure Terraform Variables

```bash
cd mentions_terraform/environments/dev

# Copy example file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars (add your billing_account)
# You can use: nano terraform.tfvars or your preferred editor
```

**Required values in `terraform.tfvars`**:
```hcl
project_id      = "mention001"
region          = "us-central1"
billing_account = "YOUR_BILLING_ACCOUNT_ID"  # From Step 1
org_id          = ""  # Leave empty if not using org
supabase_url    = "https://xxx.supabase.co"  # Can add later
backend_image   = "gcr.io/mention001/backend:latest"
```

---

## Step 5: Initialize Terraform Backend

```bash
# From mentions_terraform/environments/dev directory
../../scripts/init-backend.sh dev

# Or manually:
terraform init
```

---

## Step 6: Plan Terraform Changes

```bash
terraform plan
```

This will show what resources will be created:
- KMS keyring (`reddit-secrets`)
- KMS key (`reddit-token-key`)
- Service account (`mentions-backend@mention001.iam.gserviceaccount.com`)
- Secret Manager secrets (empty, you'll add values later)
- Cloud Tasks queues

---

## Step 7: Apply Terraform Infrastructure

```bash
terraform apply
```

Type `yes` when prompted. This will create all GCP resources.

---

## Step 8: Verify Resources Created

```bash
# Check KMS keyring
gcloud kms keyrings list --location=us-central1

# Check KMS key
gcloud kms keys list --keyring=reddit-secrets --location=us-central1

# Check service account
gcloud iam service-accounts list

# Check secrets (should exist but empty)
gcloud secrets list

# Check Cloud Tasks queues
gcloud tasks queues list --location=us-central1
```

---

## Step 9: Set Secret Values (Later)

After you have Supabase and OpenAI credentials, set secret values:

```bash
# Set OpenAI API key
echo -n "sk-..." | gcloud secrets versions add openai-api-key --data-file=-

# Set Supabase service role key
echo -n "eyJ..." | gcloud secrets versions add supabase-service-role-key --data-file=-

# Set database connection string
echo -n "postgresql://..." | gcloud secrets versions add db-connection-string --data-file=-
```

---

## Troubleshooting

### APIs Not Enabling
- Ensure billing is linked: `gcloud billing projects describe mention001`
- Check permissions: You need `roles/owner` or `roles/editor`

### Terraform Backend Init Fails
- Ensure bucket exists: `gcloud storage buckets list`
- Check bucket permissions
- Verify project is set: `gcloud config get-value project`

### Terraform Apply Fails
- Check error message for specific resource
- Ensure APIs are enabled: `gcloud services list --enabled`
- Verify billing account is correct in `terraform.tfvars`

---

## What Gets Created

### KMS (Key Management Service)
- **Keyring**: `reddit-secrets`
- **Key**: `reddit-token-key`
- **Purpose**: Encrypt Reddit OAuth tokens and client secrets

### Service Account
- **Name**: `mentions-backend@mention001.iam.gserviceaccount.com`
- **Permissions**:
  - KMS Encrypter/Decrypter
  - Secret Manager Secret Accessor
  - Cloud Tasks Enqueuer
  - Cloud Run Invoker

### Secret Manager Secrets
- `openai-api-key` (empty - add value later)
- `supabase-service-role-key` (empty - add value later)
- `db-connection-string` (empty - add value later)
- `stripe-secret-key` (optional)
- `stripe-webhook-secret` (optional)

### Cloud Tasks Queues
- `reddit-posts-default` - Default posting queue
- `generate-drafts` - Draft generation queue
- `verify-posts` - Post verification queue

---

## Next Steps After GCP Setup

1. ✅ GCP infrastructure ready
2. ⏳ Create Supabase project
3. ⏳ Set Secret Manager secret values
4. ⏳ Build and deploy backend to Cloud Run
5. ⏳ Deploy frontend to Vercel

---

## Quick Reference Commands

```bash
# Set project
gcloud config set project mention001

# Check project info
gcloud projects describe mention001

# List enabled APIs
gcloud services list --enabled

# Check Terraform state
cd mentions_terraform/environments/dev
terraform state list

# View Terraform outputs
terraform output
```

