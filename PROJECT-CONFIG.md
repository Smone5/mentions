# Project Configuration

## Google Cloud Platform

**Project ID**: `mention001`  
**Project Number**: `666103574212`

### Current Setup
- Using single project for development
- Can add staging/prod projects later if needed
- Terraform state bucket: `mention001-terraform-state`

### Quick Commands

```bash
# Set active project
gcloud config set project mention001

# Check project info
gcloud projects describe mention001

# List enabled APIs
gcloud services list --project=mention001

# Create Terraform state bucket (if not exists)
gcloud storage buckets create gs://mention001-terraform-state \
  --project=mention001 \
  --location=us-central1 \
  --uniform-bucket-level-access

gcloud storage buckets update gs://mention001-terraform-state --versioning
```

### Container Registry
- Images will be stored in: `gcr.io/mention001/`
- Example: `gcr.io/mention001/backend:latest`

### Service Accounts
- Backend service account: `mentions-backend@mention001.iam.gserviceaccount.com`

---

## Next Steps

1. Enable required APIs (see SETUP-GUIDE.md)
2. Create Terraform state bucket
3. Initialize Terraform: `cd mentions_terraform/environments/dev && terraform init`
4. Configure `terraform.tfvars` with your billing account and Supabase URL
5. Apply Terraform: `terraform apply`

