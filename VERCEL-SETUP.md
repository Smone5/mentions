# Vercel Setup Guide

This guide walks you through setting up Vercel projects for dev, staging, and production environments.

---

## Overview

We'll create **three separate Vercel projects** (or use environment-specific variables in one project):

1. **Development** (`mentions-dev`)
2. **Staging** (`mentions-staging`)
3. **Production** (`mentions-prod`)

**Recommended**: Use separate projects for better isolation and easier management.

---

## Step 1: Connect GitHub Repository

### 1.1 Link Repository to Vercel

1. Go to [vercel.com](https://vercel.com) and sign in
2. Click **"Add New Project"**
3. Import your GitHub repository: `mentions-frontend`
4. Configure project settings:
   - **Framework Preset**: Next.js
   - **Root Directory**: `mentions_frontend` (if frontend is in subdirectory) OR `.` (if package.json is at repo root) ⚠️ **CRITICAL**
   - **Build Command**: `npm run build` (default)
   - **Output Directory**: `.next` (default)
   - **Install Command**: `npm install` (default)

**⚠️ IMPORTANT**: The Root Directory must point to the directory containing your `package.json` file. If your frontend code is in a `mentions_frontend/` subdirectory, set Root Directory to `mentions_frontend`. If `package.json` is at the repository root, use `.` (default).

### 1.2 Create Three Projects

**Option A: Separate Projects (Recommended)**

Create three separate projects:
- `mentions-dev` - Development environment
- `mentions-staging` - Staging/testing environment  
- `mentions-prod` - Production environment

**Option B: Single Project with Environments**

Create one project and use Vercel's environment variables feature:
- Development environment variables
- Preview environment variables (for staging)
- Production environment variables

---

## Step 2: Configure Environment Variables

For each environment, configure these variables in Vercel:

### Development Environment

**Project**: `mentions-dev` (or Development environment)

```
NEXT_PUBLIC_ENV=dev
NEXT_PUBLIC_SUPABASE_URL=https://mjsxwzpxzalhgkekseyo.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1qc3h3enB4emFsaGdrZWtzZXlvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI1Mjc0NTgsImV4cCI6MjA3ODEwMzQ1OH0.GkscZI1pjnM1r_HdX5UaPQKxSNh3hWqOD4NIsrb1fBw
NEXT_PUBLIC_API_URL=http://localhost:8000
```

**Note**: For dev, you might want to use localhost backend or a dev Cloud Run URL.

### Staging Environment

**Project**: `mentions-staging` (or Preview environment)

```
NEXT_PUBLIC_ENV=staging
NEXT_PUBLIC_SUPABASE_URL=https://xxx-staging.supabase.co  # Staging Supabase project
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...  # Staging anon key
NEXT_PUBLIC_API_URL=https://backend-staging-xxx.run.app  # Staging Cloud Run URL
```

### Production Environment

**Project**: `mentions-prod` (or Production environment)

```
NEXT_PUBLIC_ENV=prod
NEXT_PUBLIC_SUPABASE_URL=https://xxx-prod.supabase.co  # Production Supabase project
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...  # Production anon key
NEXT_PUBLIC_API_URL=https://backend-prod-xxx.run.app  # Production Cloud Run URL
```

---

## Step 3: Configure Build Settings

### 3.1 Build Command
```bash
npm run build
```

### 3.2 Output Directory
```
.next
```

### 3.3 Install Command
```bash
npm install
```

### 3.4 Node.js Version
Set to **18.x** or **20.x** (check your `package.json` engines if specified)

---

## Step 4: Branch Configuration (If Using Single Project)

If using a single project with environments:

1. Go to **Settings** → **Git**
2. Configure branch deployments:
   - **Production Branch**: `main` (or `master`)
   - **Preview Branches**: All branches (or specific branches like `staging`, `develop`)

3. Set up environment-specific variables:
   - **Production**: Use for `main` branch
   - **Preview**: Use for all other branches
   - **Development**: Use for specific branches (optional)

---

## Step 5: Domain Configuration (Production Only)

### 5.1 Add Custom Domain

For production project only:

1. Go to **Settings** → **Domains**
2. Add your domain (e.g., `mentions.com` or `app.mentions.com`)
3. Follow DNS configuration instructions
4. Wait for SSL certificate (automatic)

### 5.2 Update Supabase Redirect URLs

After domain is configured, update Supabase Auth settings:

1. Go to Supabase Dashboard → **Authentication** → **URL Configuration**
2. Add production redirect URL:
   ```
   https://yourdomain.com/auth/callback
   ```

---

## Step 6: Deployment Verification

### 6.1 Test Deployment

After first deployment:

1. Visit the deployment URL
2. Check browser console for errors
3. Verify environment variables are loaded:
   ```javascript
   console.log(process.env.NEXT_PUBLIC_ENV)
   ```

### 6.2 Verify Supabase Connection

1. Try to access Supabase from the deployed app
2. Check network tab for API calls
3. Verify CORS is configured in Supabase

---

## Step 7: CI/CD Integration

Vercel automatically deploys on:
- **Push to main** → Production (if configured)
- **Push to other branches** → Preview deployments
- **Pull requests** → Preview deployments

### 7.1 Automatic Deployments

No additional configuration needed - Vercel handles this automatically.

### 7.2 Manual Deployments

You can also trigger deployments manually:
- Via Vercel Dashboard
- Via Vercel CLI: `vercel --prod`

---

## Environment-Specific Configuration

### Development
- **URL**: `mentions-dev.vercel.app` (or custom domain)
- **Backend**: `http://localhost:8000` (local) or dev Cloud Run
- **Supabase**: Dev project
- **Purpose**: Local development and testing

### Staging
- **URL**: `mentions-staging.vercel.app` (or custom domain)
- **Backend**: Staging Cloud Run URL
- **Supabase**: Staging project
- **Purpose**: Pre-production testing

### Production
- **URL**: `mentions-prod.vercel.app` or custom domain
- **Backend**: Production Cloud Run URL
- **Supabase**: Production project
- **Purpose**: Live production environment

---

## Quick Setup Checklist

### For Each Environment:

- [ ] Project created in Vercel
- [ ] GitHub repository connected
- [ ] Environment variables configured:
  - [ ] `NEXT_PUBLIC_ENV`
  - [ ] `NEXT_PUBLIC_SUPABASE_URL`
  - [ ] `NEXT_PUBLIC_SUPABASE_ANON_KEY`
  - [ ] `NEXT_PUBLIC_API_URL`
- [ ] Build settings verified
- [ ] First deployment successful
- [ ] Supabase redirect URLs updated
- [ ] Domain configured (production only)

---

## Vercel CLI (Optional)

Install Vercel CLI for local testing:

```bash
npm install -g vercel

# Login
vercel login

# Link project
cd mentions_frontend
vercel link

# Deploy to preview
vercel

# Deploy to production
vercel --prod
```

---

## Troubleshooting

### Build Fails
- Check Node.js version matches
- Verify all environment variables are set
- Check build logs in Vercel dashboard

### Environment Variables Not Working
- Ensure variables start with `NEXT_PUBLIC_` for client-side access
- Redeploy after adding variables
- Check variable names match exactly

### Supabase Connection Fails
- Verify Supabase URL and keys are correct
- Check CORS settings in Supabase
- Verify redirect URLs are configured

### API Calls Fail
- Check `NEXT_PUBLIC_API_URL` is set correctly
- Verify backend is deployed and accessible
- Check CORS settings on backend

---

## Next Steps After Vercel Setup

1. ✅ Vercel projects configured
2. ⏳ Update Supabase redirect URLs for each environment
3. ⏳ Build authentication system
4. ⏳ Test end-to-end flow

---

## Reference

- Vercel Docs: https://vercel.com/docs
- Next.js Deployment: https://nextjs.org/docs/deployment
- Environment Variables: https://vercel.com/docs/concepts/projects/environment-variables

