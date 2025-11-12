# Vercel Setup - Actual Setup (Main Branch Only)

Since you only have a `main` branch, here's how to set up Vercel environments.

---

## How Vercel Environments Work

With a single project and only `main` branch:

- **Production**: Deploys from `main` branch → Uses **Production** environment variables
- **Preview**: Deploys from any other branch or Pull Request → Uses **Preview** environment variables  
- **Development**: Used for local development or can be configured for a specific branch

---

## Step 1: Create Vercel Project

1. Go to [vercel.com/new](https://vercel.com/new)
2. Import repository: `mentions-frontend` (or `Smone5/mentions-frontend`)
3. Configure:
   - **Project Name**: `mentions-frontend`
   - **Root Directory**: `mentions_frontend` (or `.` if package.json is at root)
   - **Framework**: Next.js
4. Click **Deploy**

---

## Step 2: Configure Environment Variables

Go to **Settings** → **Environment Variables**

### Shared Variables (All Environments)

Add these once and select **all three environments**:

**Variable 1:**
- **Key**: `NEXT_PUBLIC_SUPABASE_URL`
- **Value**: `https://mjsxwzpxzalhgkekseyo.supabase.co`
- **Environment**: ✅ Development ✅ Preview ✅ Production
- Click **Save**

**Variable 2:**
- **Key**: `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- **Value**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1qc3h3enB4emFsaGdrZWtzZXlvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI1Mjc0NTgsImV4cCI6MjA3ODEwMzQ1OH0.GkscZI1pjnM1r_HdX5UaPQKxSNh3hWqOD4NIsrb1fBw`
- **Environment**: ✅ Development ✅ Preview ✅ Production
- Click **Save**

### Production Variables (Main Branch)

**Variable 1:**
- **Key**: `NEXT_PUBLIC_ENV`
- **Value**: `prod`
- **Environment**: ✅ Production only
- Click **Save**

**Variable 2:**
- **Key**: `NEXT_PUBLIC_API_URL`
- **Value**: `https://backend-prod-xxx.run.app` (your production backend URL)
- **Environment**: ✅ Production only
- Click **Save**

### Preview/Staging Variables (Other Branches & PRs)

**Variable 1:**
- **Key**: `NEXT_PUBLIC_ENV`
- **Value**: `staging`
- **Environment**: ✅ Preview only
- Click **Save**

**Variable 2:**
- **Key**: `NEXT_PUBLIC_API_URL`
- **Value**: `https://backend-staging-xxx.run.app` (or same as prod for now)
- **Environment**: ✅ Preview only
- Click **Save**

### Development Variables (Local Dev)

**Variable 1:**
- **Key**: `NEXT_PUBLIC_ENV`
- **Value**: `dev`
- **Environment**: ✅ Development only
- Click **Save**

**Variable 2:**
- **Key**: `NEXT_PUBLIC_API_URL`
- **Value**: `http://localhost:8000`
- **Environment**: ✅ Development only
- Click **Save**

**Note**: Development variables are mainly for local development. Vercel won't use them unless you specifically configure a branch to use Development environment.

---

## Step 3: Configure Git Settings

1. Go to **Settings** → **Git**
2. Set **Production Branch**: `main`
3. **Preview Deployments**: Enable for all branches (default)

---

## How It Works

### Current Setup (With Dedicated Branches)

- **Push to `main`** → Production deployment → Uses Production variables (`NEXT_PUBLIC_ENV=prod`)
- **Push to `staging`** → Staging deployment → Uses Preview variables (`NEXT_PUBLIC_ENV=staging`)
- **Push to `develop`** → Development deployment → Uses Development variables (`NEXT_PUBLIC_ENV=dev`)
- **Create a feature branch** → Preview deployment → Uses Preview variables (`NEXT_PUBLIC_ENV=staging`)
- **Local development** → Uses `.env.local` file → Can set `NEXT_PUBLIC_ENV=dev`

### Branch Structure

✅ **Branches created:**
- `main` → Production
- `staging` → Staging/Testing  
- `develop` → Development

### Vercel Configuration

In Vercel Settings → Git:
- **Production Branch**: `main`
- **Preview Deployments**: All branches (includes `staging` and `develop`)
- **Development Branch**: `develop` (if supported, otherwise uses Preview)

---

## Summary

**What you have:**
- ✅ `main` branch → Production
- ✅ Feature branches → Preview (staging/testing)
- ✅ Local dev → Development (via `.env.local`)

**Environment Variables:**
- ✅ Supabase URL/Key → Same for all (shared)
- ✅ `NEXT_PUBLIC_ENV` → Different per environment (prod/staging/dev)
- ✅ `NEXT_PUBLIC_API_URL` → Different per environment

---

## Update Supabase Redirect URLs

Since all environments use the same Supabase project:

1. Go to Supabase Dashboard → **Authentication** → **URL Configuration**
2. Set **Site URL**: `http://localhost:3000`
3. Add **Redirect URLs**:
   - `http://localhost:3000/auth/callback` (local dev)
   - `https://mentions-frontend-xxx.vercel.app/auth/callback` (production - from `main`)
   - `https://mentions-frontend-git-xxx-xxx.vercel.app/auth/callback` (preview - from feature branches)

**Note**: After each Vercel deployment, add the new URL to Supabase redirect URLs.

---

## Checklist

- [ ] Vercel project created
- [ ] Root Directory set correctly (`mentions_frontend` or `.`)
- [ ] Supabase URL added (all environments)
- [ ] Supabase anon key added (all environments)
- [ ] Production variables added (`NEXT_PUBLIC_ENV=prod`, prod API URL)
- [ ] Preview variables added (`NEXT_PUBLIC_ENV=staging`, staging API URL)
- [ ] Development variables added (`NEXT_PUBLIC_ENV=dev`, localhost API URL)
- [ ] Git configured (Production branch: `main`)
- [ ] First deployment successful
- [ ] Supabase redirect URLs updated

---

## Next Steps

1. ✅ Vercel configured
2. ⏳ Update Supabase redirect URLs after first deployment
3. ⏳ Build authentication system
4. ⏳ Test deployments

