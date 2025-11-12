# Vercel Branch Configuration

Now that you have dedicated branches (`main`, `staging`, `develop`), here's how to configure Vercel.

---

## Branch Structure

✅ **Branches created in frontend repository** (`mentions-frontend`):
- `main` → Production
- `staging` → Staging/Testing
- `develop` → Development

**Repository**: https://github.com/Smone5/mentions-frontend

**Note**: Vercel deploys from the `mentions-frontend` repository, not the main `mentions` repository.

---

## Vercel Configuration

### Option 1: Single Project with Branch-Based Environments (Recommended)

Configure Vercel to use different environments based on branch:

1. Go to **Settings** → **Git**
2. Set **Production Branch**: `main`
3. **Preview Deployments**: Enable for all branches

### Configure Environment Mapping

In Vercel, you can configure which branch uses which environment:

**For `main` branch:**
- Uses **Production** environment variables

**For `staging` branch:**
- Uses **Preview** environment variables (or configure to use Preview specifically)

**For `develop` branch:**
- Uses **Development** environment variables (or Preview, depending on your preference)

**For feature branches:**
- Uses **Preview** environment variables (default)

---

## Environment Variables Setup

### Shared Variables (All Environments)

Add these once and select **all three environments**:

- `NEXT_PUBLIC_SUPABASE_URL` → ✅ Development ✅ Preview ✅ Production
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` → ✅ Development ✅ Preview ✅ Production

### Development Environment (`develop` branch)

- `NEXT_PUBLIC_ENV=dev` → ✅ Development only
- `NEXT_PUBLIC_API_URL=http://localhost:8000` → ✅ Development only

### Staging Environment (`staging` branch)

- `NEXT_PUBLIC_ENV=staging` → ✅ Preview only
- `NEXT_PUBLIC_API_URL=https://backend-staging-xxx.run.app` → ✅ Preview only

### Production Environment (`main` branch)

- `NEXT_PUBLIC_ENV=prod` → ✅ Production only
- `NEXT_PUBLIC_API_URL=https://backend-prod-xxx.run.app` → ✅ Production only

---

## How It Works

### Deployment Flow

1. **Push to `develop`** → Development deployment → Uses Development vars
2. **Push to `staging`** → Staging deployment → Uses Preview vars
3. **Push to `main`** → Production deployment → Uses Production vars
4. **Create feature branch** → Preview deployment → Uses Preview vars

### Typical Workflow

```
Feature Branch → develop → staging → main
     ↓            ↓         ↓        ↓
   Preview    Dev      Staging   Production
```

---

## Vercel Branch Configuration

### Recommended Setup

**Settings → Git → Branch Configuration:**

- **Production Branch**: `main`
- **Preview Branches**: All branches (or specific: `staging`, feature branches)
- **Development Branch**: `develop` (if Vercel supports it, or use Preview)

**Note**: Vercel's environment mapping:
- Production branch (`main`) → Production environment
- Preview branches (`staging`, feature branches) → Preview environment
- Development branch (`develop`) → Preview environment (or Development if configured)

---

## Update Supabase Redirect URLs

Add all deployment URLs to Supabase:

1. Go to Supabase Dashboard → **Authentication** → **URL Configuration**
2. Set **Site URL**: `http://localhost:3000`
3. Add **Redirect URLs**:
   - `http://localhost:3000/auth/callback` (local dev)
   - `https://mentions-frontend-git-develop-xxx.vercel.app/auth/callback` (develop branch)
   - `https://mentions-frontend-git-staging-xxx.vercel.app/auth/callback` (staging branch)
   - `https://mentions-frontend-xxx.vercel.app/auth/callback` (main/production)

**Note**: After each deployment, Vercel will give you a unique URL. Add those to Supabase.

---

## Git Workflow

### Development Workflow

```bash
# Work on feature
git checkout -b feature/my-feature
# ... make changes ...
git push origin feature/my-feature

# Merge to develop
git checkout develop
git merge feature/my-feature
git push origin develop
# → Triggers Development deployment

# Merge to staging
git checkout staging
git merge develop
git push origin staging
# → Triggers Staging deployment

# Merge to main
git checkout main
git merge staging
git push origin main
# → Triggers Production deployment
```

---

## Checklist

- [x] `develop` branch created and pushed
- [x] `staging` branch created and pushed
- [x] `main` branch exists (production)
- [ ] Vercel project created
- [ ] Environment variables configured:
  - [ ] Shared variables (Supabase URL/key)
  - [ ] Development variables (`develop` branch)
  - [ ] Staging variables (`staging` branch)
  - [ ] Production variables (`main` branch)
- [ ] Git settings configured in Vercel
- [ ] First deployments successful
- [ ] Supabase redirect URLs updated

---

## Next Steps

1. ✅ Branches created
2. ⏳ Configure Vercel project
3. ⏳ Set up environment variables
4. ⏳ Test deployments
5. ⏳ Build authentication system

