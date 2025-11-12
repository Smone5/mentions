# Terraform ↔ Vercel Integration Guide

This guide explains how to sync Cloud Run backend URLs from Terraform to Vercel environment variables.

---

## Overview

**The Problem:**
- Terraform creates Cloud Run services for backend (dev, staging, prod)
- Each Cloud Run service has a public URL
- Vercel frontend needs `NEXT_PUBLIC_API_URL` environment variable pointing to the correct backend
- These URLs need to stay in sync

**The Solution:**
- Terraform outputs Cloud Run URLs
- Scripts help extract and sync these URLs to Vercel
- Manual process (Vercel doesn't have Terraform provider, but we can automate with scripts)

---

## Architecture

```
┌─────────────────┐         ┌──────────────┐         ┌─────────────┐
│   Terraform     │         │  Cloud Run   │         │   Vercel    │
│                 │         │              │         │              │
│ dev/staging/    │───────▶ │ Backend URLs │────────▶│ Environment │
│ prod            │  apply   │              │  sync   │ Variables   │
│                 │         │              │         │             │
└─────────────────┘         └──────────────┘         └─────────────┘
```

---

## Terraform Outputs

Each environment outputs the backend URL:

### Dev Environment
```bash
cd mentions_terraform/environments/dev
terraform output backend_url
# Output: https://mentions-backend-xxx.run.app
```

### Staging Environment
```bash
cd mentions_terraform/environments/staging
terraform output backend_url
# Output: https://mentions-backend-staging-xxx.run.app
```

### Production Environment
```bash
cd mentions_terraform/environments/prod
terraform output backend_url
# Output: https://mentions-backend-prod-xxx.run.app
```

---

## Vercel Environment Variables Mapping

| Terraform Environment | Vercel Environment | Branch | Variable |
|----------------------|-------------------|--------|----------|
| `dev` | Development | `develop` | `NEXT_PUBLIC_API_URL` |
| `staging` | Preview | `staging` | `NEXT_PUBLIC_API_URL` |
| `prod` | Production | `main` | `NEXT_PUBLIC_API_URL` |

---

## Workflow

### Step 1: Deploy Backend with Terraform

```bash
# Deploy dev backend
cd mentions_terraform/environments/dev
terraform init
terraform plan
terraform apply

# Get the URL
terraform output backend_url
```

### Step 2: Get All URLs

Use the helper script to get all URLs at once:

```bash
./scripts/get-terraform-urls.sh
```

This will show:
```
dev:
  Backend URL: https://mentions-backend-xxx.run.app
  Vercel Environment Variable:
    NEXT_PUBLIC_API_URL=https://mentions-backend-xxx.run.app
    Environment: Development

staging:
  Backend URL: https://mentions-backend-staging-xxx.run.app
  ...

prod:
  Backend URL: https://mentions-backend-prod-xxx.run.app
  ...
```

### Step 3: Update Vercel

#### Option A: Manual Update (Recommended)

1. Go to Vercel Dashboard → Your Project → **Settings** → **Environment Variables**
2. For each environment:
   - Find or add `NEXT_PUBLIC_API_URL`
   - Set value to the Terraform output URL
   - Select the appropriate environment (Development/Preview/Production)
   - Click **Save**

#### Option B: Using Vercel CLI

```bash
# Link project first (if not already linked)
cd mentions_frontend
vercel link

# Add environment variable for Development
vercel env add NEXT_PUBLIC_API_URL Development
# When prompted, paste the dev backend URL

# Add for Preview (staging)
vercel env add NEXT_PUBLIC_API_URL Preview
# When prompted, paste the staging backend URL

# Add for Production
vercel env add NEXT_PUBLIC_API_URL Production
# When prompted, paste the prod backend URL
```

### Step 4: Redeploy Vercel

After updating environment variables, redeploy:

```bash
# Via CLI
vercel --prod  # Production
vercel         # Preview

# Or trigger via GitHub push
git push origin main     # Production
git push origin staging  # Staging
git push origin develop  # Development
```

---

## Helper Scripts

### Get All Terraform URLs

```bash
./scripts/get-terraform-urls.sh
```

Shows all backend URLs from all environments in a formatted way.

### Sync Single Environment

```bash
./scripts/sync-terraform-to-vercel.sh [terraform_dir] [environment]

# Examples:
./scripts/sync-terraform-to-vercel.sh mentions_terraform/environments dev
./scripts/sync-terraform-to-vercel.sh mentions_terraform/environments staging
./scripts/sync-terraform-to-vercel.sh mentions_terraform/environments prod
```

This script:
1. Gets Terraform output for the specified environment
2. Shows the backend URL
3. Provides instructions for updating Vercel

---

## Automated Sync (Future)

For now, the sync is manual. Future improvements could include:

1. **GitHub Actions**: Automatically sync after Terraform apply
2. **Vercel API**: Use Vercel API to update environment variables programmatically
3. **Terraform Provider**: If Vercel creates a Terraform provider, use it directly

---

## Example: Complete Workflow

### Initial Setup

```bash
# 1. Deploy dev backend
cd mentions_terraform/environments/dev
terraform apply

# 2. Get the URL
DEV_URL=$(terraform output -raw backend_url)
echo "Dev URL: $DEV_URL"

# 3. Update Vercel manually or via CLI
cd ../../../
cd mentions_frontend
vercel env add NEXT_PUBLIC_API_URL Development
# Paste: $DEV_URL

# 4. Repeat for staging and prod
```

### After Backend Changes

```bash
# 1. Update Terraform
cd mentions_terraform/environments/dev
terraform apply

# 2. Get new URL
terraform output backend_url

# 3. Update Vercel if URL changed
# (Go to Vercel dashboard and update the variable)

# 4. Redeploy Vercel
cd ../../../
cd mentions_frontend
vercel --prod  # or push to trigger auto-deploy
```

---

## Troubleshooting

### Backend URL Not Available

If `terraform output backend_url` shows "Backend not deployed yet":

1. Check if backend module is commented out in `main.tf`
2. Uncomment the backend module
3. Run `terraform apply`
4. Ensure backend image exists in Artifact Registry

### URL Changed After Terraform Apply

If Cloud Run URL changes (rare, but can happen):

1. Get new URL: `terraform output backend_url`
2. Update Vercel environment variable
3. Redeploy Vercel frontend

### Vercel Not Picking Up Changes

After updating environment variables:

1. **Redeploy**: Environment variables only apply to new deployments
2. **Check environment**: Make sure you selected the correct environment (Development/Preview/Production)
3. **Verify variable name**: Must be exactly `NEXT_PUBLIC_API_URL`

---

## Checklist

### Initial Setup
- [ ] Deploy dev backend with Terraform
- [ ] Get dev backend URL
- [ ] Add to Vercel as Development environment variable
- [ ] Deploy staging backend with Terraform
- [ ] Get staging backend URL
- [ ] Add to Vercel as Preview environment variable
- [ ] Deploy prod backend with Terraform
- [ ] Get prod backend URL
- [ ] Add to Vercel as Production environment variable
- [ ] Redeploy Vercel frontend

### After Backend Changes
- [ ] Run `terraform apply` for changed environment
- [ ] Get new backend URL
- [ ] Update Vercel environment variable if URL changed
- [ ] Redeploy Vercel frontend

---

## Quick Reference

```bash
# Get URLs
./scripts/get-terraform-urls.sh

# Sync specific environment
./scripts/sync-terraform-to-vercel.sh mentions_terraform/environments dev

# Terraform outputs
cd mentions_terraform/environments/dev && terraform output backend_url

# Vercel CLI
vercel env ls                    # List environment variables
vercel env add VAR_NAME ENV       # Add environment variable
vercel env rm VAR_NAME ENV        # Remove environment variable
```

---

## Next Steps

1. ✅ Scripts created
2. ⏳ Deploy backend with Terraform
3. ⏳ Sync URLs to Vercel
4. ⏳ Test end-to-end connectivity

