# Deploying Backend with Terraform

This guide explains how to deploy the backend Cloud Run service and sync its URL to Vercel.

---

## Current Status

✅ **Terraform Configuration**: Valid and ready  
⏸️ **Backend Module**: Commented out (waiting for Docker image)  
⏸️ **Cloud Run Service**: Not deployed yet  

---

## Step-by-Step: Deploy Backend

### Step 1: Build and Push Docker Image

Before deploying with Terraform, you need to build and push the backend Docker image:

```bash
# Build the backend image
cd mentions_backend
docker build -t gcr.io/mention001/backend:latest .

# Push to Artifact Registry
docker push gcr.io/mention001/backend:latest
```

**Note**: Make sure Artifact Registry is set up and you're authenticated:
```bash
gcloud auth configure-docker
```

### Step 2: Enable Backend Module in Terraform

Edit `mentions_terraform/environments/dev/main.tf`:

1. **Uncomment the backend module** (lines 104-142):
   ```terraform
   module "backend" {
     source = "../../modules/cloud-run"
     # ... rest of config
   }
   ```

2. **Replace placeholder outputs** (lines 164-168) with real outputs:
   ```terraform
   output "backend_url" {
     description = "Cloud Run backend service URL (for NEXT_PUBLIC_API_URL in Vercel)"
     value       = module.backend.service_url
   }
   
   output "backend_service_name" {
     description = "Cloud Run backend service name"
     value       = module.backend.service_name
   }
   
   output "vercel_api_url" {
     description = "Formatted output for Vercel NEXT_PUBLIC_API_URL environment variable"
     value       = module.backend.service_url
   }
   ```

### Step 3: Apply Terraform

```bash
cd mentions_terraform/environments/dev
terraform init  # If not already initialized
terraform plan  # Review changes
terraform apply # Deploy
```

### Step 4: Get Backend URL

```bash
terraform output backend_url
# Output: https://mentions-backend-xxx.run.app
```

### Step 5: Update Vercel

**Option A: Via Dashboard**
1. Go to Vercel Dashboard → Your Project → Settings → Environment Variables
2. Add/Update: `NEXT_PUBLIC_API_URL`
3. Value: `<terraform-output-url>`
4. Environment: **Development** (for dev)
5. Save and redeploy

**Option B: Via CLI**
```bash
cd mentions_frontend
vercel env add NEXT_PUBLIC_API_URL Development
# When prompted, paste the backend URL from terraform output
```

### Step 6: Repeat for Staging and Production

1. Create `staging/main.tf` and `prod/main.tf` (copy from `dev/main.tf`)
2. Update variables (project_id, backend_image, etc.)
3. Deploy: `terraform apply`
4. Get URL: `terraform output backend_url`
5. Update Vercel: Add to **Preview** (staging) or **Production** (prod) environment

---

## Helper Scripts

### Get All Backend URLs

```bash
./scripts/get-terraform-urls.sh
```

Shows backend URLs from all environments (or "Not deployed yet" if not deployed).

### Sync to Vercel

```bash
./scripts/sync-terraform-to-vercel.sh mentions_terraform/environments dev
```

Provides step-by-step instructions for updating Vercel.

---

## Troubleshooting

### Error: "Reference to undeclared module"

**Problem**: Outputs reference `module.backend` but module is commented out.

**Solution**: 
- Keep placeholder output until backend module is uncommented
- When ready, replace placeholder with real outputs that reference the module

### Error: "Image not found"

**Problem**: Docker image doesn't exist in Artifact Registry.

**Solution**:
1. Build and push the image first
2. Verify: `gcloud artifacts docker images list gcr.io/mention001/backend`

### Error: "Service account not found"

**Problem**: Service account doesn't exist.

**Solution**:
- Make sure `module.service_accounts` is applied first
- Check: `terraform output service_account_email`

---

## Quick Reference

```bash
# Deploy backend
cd mentions_terraform/environments/dev
terraform apply

# Get URL
terraform output backend_url

# Update Vercel
# (Use dashboard or CLI - see Step 5 above)

# Verify
curl $(terraform output -raw backend_url)/health
```

---

## Next Steps

1. ⏳ Build backend Docker image
2. ⏳ Push to Artifact Registry
3. ⏳ Uncomment backend module in Terraform
4. ⏳ Run `terraform apply`
5. ⏳ Get backend URL
6. ⏳ Update Vercel environment variables
7. ⏳ Test end-to-end

