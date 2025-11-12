# Vercel Quick Start Checklist

**Goal**: Set up three Vercel projects (dev, staging, prod) for the Mentions frontend.

---

## ✅ Quick Checklist

### Step 1: Create Projects (5 minutes)

- [ ] Go to https://vercel.com and sign in
- [ ] Click "Add New Project"
- [ ] Import repository: `mentions-frontend` ⚠️ **Use the frontend repo**: `https://github.com/Smone5/mentions-frontend`
- [ ] Create **Project 1**: `mentions-dev`
- [ ] Create **Project 2**: `mentions-staging`  
- [ ] Create **Project 3**: `mentions-prod`

**For each project**:
- Framework: Next.js
- **Root Directory**: `mentions_frontend` (if frontend is in subdirectory) OR `.` (if package.json is at repo root)
- Build Command: `npm run build` (default)
- Output Directory: `.next` (default)

**⚠️ IMPORTANT**: Make sure Root Directory matches where your `package.json` file is located!

---

### Step 2: Configure Development Project

**Project**: `mentions-dev`

**Environment Variables** (Settings → Environment Variables → Add):

**Shared (apply to all environments):**
- `NEXT_PUBLIC_SUPABASE_URL=https://mjsxwzpxzalhgkekseyo.supabase.co` → ✅ Dev ✅ Preview ✅ Production
- `NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1qc3h3enB4emFsaGdrZWtzZXlvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI1Mjc0NTgsImV4cCI6MjA3ODEwMzQ1OH0.GkscZI1pjnM1r_HdX5UaPQKxSNh3hWqOD4NIsrb1fBw` → ✅ Dev ✅ Preview ✅ Production

**Development only:**
- `NEXT_PUBLIC_ENV=dev` → ✅ Development only
- `NEXT_PUBLIC_API_URL=http://localhost:8000` → ✅ Development only

**Deploy**: Click "Deploy" (or it will auto-deploy from GitHub)

**Note**: After deployment, you'll get a URL like `mentions-dev-xxx.vercel.app`

---

### Step 3: Add Staging Variables

**Note**: Supabase URL and anon key are already added (shared across all environments).

**Add these Preview/Staging variables:**
- `NEXT_PUBLIC_ENV=staging` → ✅ Preview only
- `NEXT_PUBLIC_API_URL=https://backend-staging-xxx.run.app` → ✅ Preview only

**Deploy**: Create a feature branch or PR (will use Preview variables automatically)

---

### Step 4: Add Production Variables

**Note**: Supabase URL and anon key are already added (shared across all environments).

**Add these Production variables:**
- `NEXT_PUBLIC_ENV=prod` → ✅ Production only
- `NEXT_PUBLIC_API_URL=https://backend-prod-xxx.run.app` → ✅ Production only

**Production Branch**: Set to `main` (Settings → Git)

**Deploy**: Push to `main` branch (auto-deploys)

---

### Step 5: Update Supabase Redirect URLs

Since you have one Supabase project for all environments, add all Vercel URLs:

1. Go to Supabase Dashboard → Authentication → URL Configuration
2. Set Site URL: `http://localhost:3000` (for local dev)
3. Add Redirect URLs:
   - `http://localhost:3000/auth/callback` (local dev)
   - `https://mentions-frontend-xxx.vercel.app/auth/callback` (production - from `main` branch)
   - `https://mentions-frontend-git-xxx-xxx.vercel.app/auth/callback` (preview - from feature branches/PRs)

**Note**: After each Vercel deployment, you'll get a unique URL. Add those to Supabase redirect URLs.

---

## 🎯 Current Status

**You can set up everything now**:
- ✅ Single Supabase project (used for all environments)
- ✅ Development environment variables
- ✅ Staging environment variables (Preview)
- ✅ Production environment variables

**Setup steps**:
1. Create Vercel project
2. Add shared Supabase variables (all environments)
3. Add environment-specific variables (dev/staging/prod)
4. Deploy and get URLs
5. Update Supabase redirect URLs with all Vercel URLs

---

## 📝 Notes

- **Staging/Prod Supabase**: You can create these later when ready
- **Backend URLs**: Will be Cloud Run URLs after backend is deployed
- **For now**: Dev can use `http://localhost:8000` or we'll deploy backend to Cloud Run first

---

## 🚀 After Vercel Setup

Once Vercel is configured:
1. ✅ Frontend deployed to Vercel
2. ⏳ Build authentication system
3. ⏳ Test auth flow end-to-end
4. ⏳ Deploy backend to Cloud Run
5. ⏳ Connect frontend to backend

---

## Quick Reference

**Vercel Dashboard**: https://vercel.com/dashboard  
**Project Settings**: Settings → Environment Variables  
**Deployment URLs**: Will be shown after first deployment

**Current Dev Values** (from your setup):
- Supabase URL: `https://mjsxwzpxzalhgkekseyo.supabase.co`
- Anon Key: (in your .env.local file)

