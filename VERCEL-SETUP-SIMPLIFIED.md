# Vercel Setup - Simplified (Single Supabase)

Since you have **one Supabase project** for all environments, here's the simplified setup.

---

## Quick Setup

### Step 1: Create Vercel Project

1. Go to [vercel.com/new](https://vercel.com/new)
2. Import repository: `mentions-frontend` ⚠️ **Important**: Use the frontend repository, not the main repo!
   - Repository URL: `https://github.com/Smone5/mentions-frontend`
3. Configure:
   - **Project Name**: `mentions-frontend`
   - **Root Directory**: `.` (package.json is at root of frontend repo)
   - **Framework**: Next.js
   - **Production Branch**: `main`
4. Click **Deploy**

### Step 2: Add Environment Variables

Go to **Settings** → **Environment Variables** and add:

#### Shared Variables (All Environments)

These are the same for dev, staging, and prod:

**Variable 1:**
- **Key**: `NEXT_PUBLIC_SUPABASE_URL`
- **Value**: `https://mjsxwzpxzalhgkekseyo.supabase.co`
- **Environment**: ✅ Development ✅ Preview ✅ Production (select all three)
- Click **Save**

**Variable 2:**
- **Key**: `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- **Value**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1qc3h3enB4emFsaGdrZWtzZXlvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI1Mjc0NTgsImV4cCI6MjA3ODEwMzQ1OH0.GkscZI1pjnM1r_HdX5UaPQKxSNh3hWqOD4NIsrb1fBw`
- **Environment**: ✅ Development ✅ Preview ✅ Production (select all three)
- Click **Save**

#### Environment-Specific Variables

**Development:**
- **Key**: `NEXT_PUBLIC_ENV` → **Value**: `dev` → **Environment**: Development only
- **Key**: `NEXT_PUBLIC_API_URL` → **Value**: `http://localhost:8000` → **Environment**: Development only

**Staging (Preview):**
- **Key**: `NEXT_PUBLIC_ENV` → **Value**: `staging` → **Environment**: Preview only
- **Key**: `NEXT_PUBLIC_API_URL` → **Value**: `https://backend-staging-xxx.run.app` → **Environment**: Preview only

**Production:**
- **Key**: `NEXT_PUBLIC_ENV` → **Value**: `prod` → **Environment**: Production only
- **Key**: `NEXT_PUBLIC_API_URL` → **Value**: `https://backend-prod-xxx.run.app` → **Environment**: Production only

### Step 3: Configure Git

1. Go to **Settings** → **Git**
2. Set **Production Branch**: `main`
3. **Preview Deployments**: Enable for all branches (default)

---

## Summary

**Same for all environments:**
- ✅ Supabase URL
- ✅ Supabase Anon Key

**Different per environment:**
- 🔄 `NEXT_PUBLIC_ENV` (dev/staging/prod)
- 🔄 `NEXT_PUBLIC_API_URL` (different backend URLs)

---

## Update Supabase Redirect URLs

Since all environments use the same Supabase project, add all Vercel URLs:

1. Go to Supabase Dashboard → **Authentication** → **URL Configuration**
2. Set **Site URL**: `http://localhost:3000` (for local dev)
3. Add **Redirect URLs**:
   - `http://localhost:3000/auth/callback` (local dev)
   - `https://mentions-frontend-git-develop-xxx.vercel.app/auth/callback` (develop branch)
   - `https://mentions-frontend-git-staging-xxx.vercel.app/auth/callback` (staging branch)
   - `https://mentions-frontend-xxx.vercel.app/auth/callback` (production - from `main` branch)
   - `https://mentions-frontend-git-xxx-xxx.vercel.app/auth/callback` (preview - from feature branches/PRs)

**Note**: After each deployment, Vercel will give you a unique URL. Add those to Supabase redirect URLs.

---

## How It Works (With Dedicated Branches)

- **Push to `main`** → Production deployment → Uses Production vars (`NEXT_PUBLIC_ENV=prod`, production API URL)
- **Push to `staging`** → Staging deployment → Uses Preview vars (`NEXT_PUBLIC_ENV=staging`, staging API URL)
- **Push to `develop`** → Development deployment → Uses Development vars (`NEXT_PUBLIC_ENV=dev`, localhost API URL)
- **Create feature branch** → Preview deployment → Uses Preview vars (`NEXT_PUBLIC_ENV=staging`, staging API URL)
- **Local development** → Uses `.env.local` → Can set `NEXT_PUBLIC_ENV=dev`
- **All environments** → Use the same Supabase project (same URL and anon key)

**Branch Structure:**
- ✅ `main` → Production
- ✅ `staging` → Staging/Testing
- ✅ `develop` → Development

---

## Checklist

- [ ] Vercel project created
- [ ] Supabase URL added (all environments)
- [ ] Supabase anon key added (all environments)
- [ ] Development variables added (`NEXT_PUBLIC_ENV=dev`, dev API URL)
- [ ] Staging variables added (`NEXT_PUBLIC_ENV=staging`, staging API URL)
- [ ] Production variables added (`NEXT_PUBLIC_ENV=prod`, prod API URL)
- [ ] Git configured (Production branch: `main`)
- [ ] First deployment successful
- [ ] Supabase redirect URLs updated with Vercel deployment URLs

---

## Next Steps

1. ✅ Vercel configured
2. ⏳ Update Supabase redirect URLs after first deployment
3. ⏳ Build authentication system
4. ⏳ Test auth flow

