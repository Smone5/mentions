# Vercel Environments Configuration

Quick reference for setting up dev, staging, and production environments in Vercel.

---

## Option 1: Three Separate Projects (Recommended)

### Advantages
- Complete isolation between environments
- Independent deployment pipelines
- Easier to manage permissions
- Clear separation of concerns

### Setup

#### 1. Development Project (`mentions-dev`)

**Project Settings**:
- **Name**: `mentions-dev`
- **Framework**: Next.js
- **Root Directory**: `./`
- **Branch**: `develop` or `dev` (optional)

**Environment Variables**:
```
NEXT_PUBLIC_ENV=dev
NEXT_PUBLIC_SUPABASE_URL=https://mjsxwzpxzalhgkekseyo.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1qc3h3enB4emFsaGdrZWtzZXlvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI1Mjc0NTgsImV4cCI6MjA3ODEwMzQ1OH0.GkscZI1pjnM1r_HdX5UaPQKxSNh3hWqOD4NIsrb1fBw
NEXT_PUBLIC_API_URL=http://localhost:8000
```

**Deployment**:
- Auto-deploy from `develop` branch (or manual)
- Preview URLs: `mentions-dev-xxx.vercel.app`

#### 2. Staging Project (`mentions-staging`)

**Project Settings**:
- **Name**: `mentions-staging`
- **Framework**: Next.js
- **Root Directory**: `./`
- **Branch**: `staging` (optional)

**Environment Variables**:
```
NEXT_PUBLIC_ENV=staging
NEXT_PUBLIC_SUPABASE_URL=https://xxx-staging.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...  # Staging anon key
NEXT_PUBLIC_API_URL=https://backend-staging-xxx.run.app
```

**Deployment**:
- Auto-deploy from `staging` branch
- Preview URLs: `mentions-staging-xxx.vercel.app`

#### 3. Production Project (`mentions-prod`)

**Project Settings**:
- **Name**: `mentions-prod`
- **Framework**: Next.js
- **Root Directory**: `./`
- **Production Branch**: `main`

**Environment Variables**:
```
NEXT_PUBLIC_ENV=prod
NEXT_PUBLIC_SUPABASE_URL=https://xxx-prod.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...  # Production anon key
NEXT_PUBLIC_API_URL=https://backend-prod-xxx.run.app
```

**Deployment**:
- Auto-deploy from `main` branch
- Production URL: `mentions-prod.vercel.app` or custom domain

---

## Option 2: Single Project with Environments

### Advantages
- Single project to manage
- Shared build settings
- Environment-specific variables

### Setup

**Project Settings**:
- **Name**: `mentions-frontend`
- **Framework**: Next.js
- **Production Branch**: `main`

**Environment Variables** (Set per environment):

**Development**:
- Applied to: Development environment
- Variables: Same as dev project above

**Preview** (for staging):
- Applied to: Preview deployments
- Variables: Same as staging project above

**Production**:
- Applied to: Production deployments
- Variables: Same as production project above

**Branch Configuration**:
- **Production**: `main` branch
- **Preview**: All other branches
- **Development**: Specific branch (optional)

---

## Recommended Setup: Three Projects

We recommend **Option 1** (three separate projects) because:

1. **Clear Separation**: Each environment is completely independent
2. **Easier Management**: No confusion about which environment you're deploying to
3. **Better Security**: Production credentials never mixed with dev
4. **Independent Scaling**: Can configure different settings per environment
5. **Easier Rollbacks**: Can rollback one environment without affecting others

---

## Step-by-Step: Create Three Projects

### Project 1: Development

1. Go to [vercel.com/new](https://vercel.com/new)
2. Import repository: `mentions-frontend`
3. Configure:
   - **Project Name**: `mentions-dev`
   - **Framework Preset**: Next.js
   - **Root Directory**: `./`
4. Add Environment Variables:
   - Click "Environment Variables"
   - Add each variable
   - Select "Development" environment
5. Deploy

### Project 2: Staging

1. Repeat steps 1-3, name: `mentions-staging`
2. Add Environment Variables:
   - Select "Preview" environment (or create staging-specific)
3. Configure branch (optional):
   - Settings → Git → Production Branch: `staging`

### Project 3: Production

1. Repeat steps 1-3, name: `mentions-prod`
2. Add Environment Variables:
   - Select "Production" environment
3. Configure:
   - Production Branch: `main`
   - Add custom domain (if applicable)

---

## Environment Variables Template

Copy this template for each environment:

```bash
# Development
NEXT_PUBLIC_ENV=dev
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
NEXT_PUBLIC_API_URL=

# Staging
NEXT_PUBLIC_ENV=staging
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
NEXT_PUBLIC_API_URL=

# Production
NEXT_PUBLIC_ENV=prod
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
NEXT_PUBLIC_API_URL=
```

---

## Supabase Redirect URLs

After Vercel deployments, update Supabase Auth settings:

### Development Supabase Project
- Site URL: `https://mentions-dev.vercel.app`
- Redirect URLs:
  - `https://mentions-dev.vercel.app/auth/callback`
  - `http://localhost:3000/auth/callback` (for local dev)

### Staging Supabase Project
- Site URL: `https://mentions-staging.vercel.app`
- Redirect URLs:
  - `https://mentions-staging.vercel.app/auth/callback`

### Production Supabase Project
- Site URL: `https://mentions-prod.vercel.app` (or custom domain)
- Redirect URLs:
  - `https://mentions-prod.vercel.app/auth/callback`
  - `https://yourdomain.com/auth/callback` (if using custom domain)

---

## Verification Checklist

After setup, verify:

- [ ] All three projects created
- [ ] Environment variables set for each project
- [ ] First deployment successful for each
- [ ] Supabase redirect URLs updated
- [ ] Can access each deployment URL
- [ ] Environment variables accessible in app
- [ ] Backend API URLs correct for each environment

---

## Quick Commands

### Deploy via CLI

```bash
# Install Vercel CLI
npm install -g vercel

# Login
vercel login

# Link to project
cd mentions_frontend
vercel link

# Deploy to preview (staging)
vercel

# Deploy to production
vercel --prod
```

### Check Deployment Status

```bash
# List deployments
vercel ls

# View deployment logs
vercel logs [deployment-url]
```

---

## Next Steps

After Vercel is configured:

1. ✅ Vercel projects set up
2. ⏳ Update Supabase redirect URLs
3. ⏳ Build authentication system
4. ⏳ Test end-to-end flow

