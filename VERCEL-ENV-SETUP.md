# Vercel Environment Setup - Step by Step

This guide shows you exactly how to set up dev, staging, and production environments in Vercel.

---

## Option 1: Single Project with Three Environments (Recommended)

This is the **simplest approach** - one Vercel project with environment-specific variables.

### Step 1: Create the Project

1. Go to [vercel.com](https://vercel.com) and sign in
2. Click **"Add New Project"** (or "New Project")
3. Import your GitHub repository: `mentions-frontend`
4. Configure:
   - **Project Name**: `mentions-frontend` (or `mentions`)
   - **Framework Preset**: Next.js
   - **Root Directory**: `mentions_frontend` (if package.json is in subdirectory) OR `.` (if at root)
   - **Build Command**: `npm run build` (default)
   - **Output Directory**: `.next` (default)
5. Click **"Deploy"** (or "Create Project")

### Step 2: Configure Environment Variables

After the project is created:

1. Go to your project dashboard
2. Click **Settings** (top right)
3. Click **Environment Variables** (left sidebar)

#### Add Development Variables

1. Click **"Add New"**
2. Add each variable one by one:

**Variable 1:**
- **Key**: `NEXT_PUBLIC_ENV`
- **Value**: `dev`
- **Environment**: Select **Development** only
- Click **Save**

**Variable 2:**
- **Key**: `NEXT_PUBLIC_SUPABASE_URL`
- **Value**: `https://mjsxwzpxzalhgkekseyo.supabase.co` (same for all environments)
- **Environment**: Select **Development**, **Preview**, and **Production** (all three)
- Click **Save**

**Variable 3:**
- **Key**: `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- **Value**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1qc3h3enB4emFsaGdrZWtzZXlvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI1Mjc0NTgsImV4cCI6MjA3ODEwMzQ1OH0.GkscZI1pjnM1r_HdX5UaPQKxSNh3hWqOD4NIsrb1fBw` (same for all environments)
- **Environment**: Select **Development**, **Preview**, and **Production** (all three)
- Click **Save**

**Variable 4:**
- **Key**: `NEXT_PUBLIC_API_URL`
- **Value**: `http://localhost:8000` (or your dev Cloud Run URL)
- **Environment**: Select **Development** only
- Click **Save**

#### Add Staging Variables

**Note**: Supabase URL and anon key are the same for all environments (already added above). Only add these staging-specific variables:

**Variable 1:**
- **Key**: `NEXT_PUBLIC_ENV`
- **Value**: `staging`
- **Environment**: Select **Preview** only
- Click **Save**

**Variable 2:**
- **Key**: `NEXT_PUBLIC_API_URL`
- **Value**: `https://backend-staging-xxx.run.app` (your staging backend URL)
- **Environment**: Select **Preview** only
- Click **Save**

#### Add Production Variables

**Note**: Supabase URL and anon key are the same for all environments (already added above). Only add these production-specific variables:

**Variable 1:**
- **Key**: `NEXT_PUBLIC_ENV`
- **Value**: `prod`
- **Environment**: Select **Production** only
- Click **Save**

**Variable 2:**
- **Key**: `NEXT_PUBLIC_API_URL`
- **Value**: `https://backend-prod-xxx.run.app` (your production backend URL)
- **Environment**: Select **Production** only
- Click **Save**

### Step 3: Configure Branch Deployments

1. Still in **Settings**, click **Git** (left sidebar)
2. Configure:
   - **Production Branch**: `main` (or `master`)
   - **Preview Deployments**: Enable for all branches (or specific branches)

### Step 4: How It Works (With Only Main Branch)

- **Production**: Deploys from `main` branch → Uses Production environment variables (`NEXT_PUBLIC_ENV=prod`)
- **Preview**: Deploys from feature branches or Pull Requests → Uses Preview environment variables (`NEXT_PUBLIC_ENV=staging`)
- **Development**: Used for local development (via `.env.local`) → Uses Development environment variables (`NEXT_PUBLIC_ENV=dev`)

**Note**: By default, Vercel uses:
- **Production** environment for the production branch (`main`)
- **Preview** environment for all other branches and PRs
- **Development** environment is mainly for local dev (can be configured for specific branches if needed)

**Current Setup**: Since you only have `main` branch:
- Push to `main` → Production deployment
- Create a feature branch → Preview deployment (staging/testing)
- Create a PR → Preview deployment (staging/testing)
- Local dev → Uses `.env.local` file

---

## Option 2: Three Separate Projects

If you prefer complete isolation, create three separate projects.

### Project 1: Development (`mentions-dev`)

1. Go to [vercel.com/new](https://vercel.com/new)
2. Import repository: `mentions-frontend`
3. Configure:
   - **Project Name**: `mentions-dev`
   - **Root Directory**: `mentions_frontend` (or `.`)
   - **Framework**: Next.js
4. Add Environment Variables (Settings → Environment Variables):
   ```
   NEXT_PUBLIC_ENV=dev
   NEXT_PUBLIC_SUPABASE_URL=https://mjsxwzpxzalhgkekseyo.supabase.co
   NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   NEXT_PUBLIC_API_URL=http://localhost:8000
   ```
   - Apply to: **All Environments** (or just Development)
5. Deploy

### Project 2: Staging (`mentions-staging`)

1. Repeat steps 1-3, but name it `mentions-staging`
2. Add Environment Variables:
   ```
   NEXT_PUBLIC_ENV=staging
   NEXT_PUBLIC_SUPABASE_URL=https://xxx-staging.supabase.co
   NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...
   NEXT_PUBLIC_API_URL=https://backend-staging-xxx.run.app
   ```
3. Configure branch (optional):
   - Settings → Git → Production Branch: `staging`
4. Deploy

### Project 3: Production (`mentions-prod`)

1. Repeat steps 1-3, but name it `mentions-prod`
2. Add Environment Variables:
   ```
   NEXT_PUBLIC_ENV=prod
   NEXT_PUBLIC_SUPABASE_URL=https://xxx-prod.supabase.co
   NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...
   NEXT_PUBLIC_API_URL=https://backend-prod-xxx.run.app
   ```
3. Configure:
   - Production Branch: `main`
   - Add custom domain (if applicable)
4. Deploy

---

## Quick Comparison

| Feature | Single Project | Three Projects |
|---------|---------------|----------------|
| **Setup Complexity** | ⭐ Simple | ⭐⭐⭐ More steps |
| **Management** | One project to manage | Three projects |
| **Isolation** | Environment-based | Complete isolation |
| **Cost** | Same | Same |
| **Recommended** | ✅ Yes | For strict separation |

---

## Recommended: Single Project Approach

**Why?**
- ✅ Simpler setup
- ✅ Easier to manage
- ✅ One place for all deployments
- ✅ Environment variables automatically applied based on branch
- ✅ Less configuration overhead

**How it works:**
- Push to `main` → Production deployment (uses Production vars)
- Push to `staging` branch → Preview deployment (uses Preview vars)
- Push to `develop` branch → Preview deployment (uses Preview vars)
- Create PR → Preview deployment (uses Preview vars)

---

## Step-by-Step: Single Project (Recommended)

### 1. Create Project (5 minutes)

```
1. Go to vercel.com → Add New Project
2. Import: mentions-frontend
3. Name: mentions-frontend
4. Root Directory: mentions_frontend (or .)
5. Deploy
```

### 2. Add Environment Variables (10 minutes)

```
1. Settings → Environment Variables
2. Add 4 variables for Development (select Development only)
3. Add 4 variables for Preview (select Preview only)
4. Add 4 variables for Production (select Production only)
```

### 3. Configure Git (2 minutes)

```
1. Settings → Git
2. Production Branch: main
3. Preview: All branches (or specific)
```

### 4. Test

```
1. Push to main → Should deploy with Production vars
2. Push to staging branch → Should deploy with Preview vars
3. Check deployment URLs
```

---

## Current Status Checklist

### For Development (Can do now):
- [ ] Create Vercel project
- [ ] Add Development environment variables
- [ ] Deploy from any branch (will use Preview vars) OR create `develop` branch
- [ ] Get deployment URL
- [ ] Update Supabase redirect URLs

### For Staging (Need staging Supabase):
- [ ] Create staging Supabase project (later)
- [ ] Add Preview environment variables
- [ ] Deploy from `staging` branch

### For Production (Need production Supabase):
- [ ] Create production Supabase project (later)
- [ ] Add Production environment variables
- [ ] Deploy from `main` branch
- [ ] Configure custom domain (optional)

---

## Next Steps After Setup

1. ✅ Vercel project created
2. ✅ Environment variables configured
3. ⏳ Update Supabase redirect URLs for each environment
4. ⏳ Build authentication system
5. ⏳ Test deployments

---

## Troubleshooting

### Variables Not Applied
- Make sure you selected the correct environment when adding variables
- Redeploy after adding variables
- Check deployment logs to verify variables are loaded

### Wrong Environment Used
- Check which branch triggered the deployment
- Verify Git settings (Production Branch)
- Preview deployments use Preview variables
- Production deployments use Production variables

### Can't See Environment Selection
- Make sure you're in Settings → Environment Variables
- Click "Add New" to see environment checkboxes
- You can select multiple environments per variable if needed

