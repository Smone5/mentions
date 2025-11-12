# Supabase Setup Guide

This guide walks you through setting up Supabase projects for the Mentions application.

---

## Overview

You need to create **one Supabase project** for development. You can add staging and production projects later.

**Project Name**: `mentions-dev` (or similar)

---

## Step 1: Create Supabase Account & Project

### 1.1 Sign Up / Sign In

1. Go to [supabase.com](https://supabase.com)
2. Click **"Start your project"** or **"Sign In"**
3. Sign in with GitHub (recommended) or email

### 1.2 Create New Project

1. Click **"New Project"** button
2. Fill in project details:
   - **Name**: `mentions-dev`
   - **Database Password**: Choose a strong password (save it!)
     - ⚠️ **IMPORTANT**: Save this password - you'll need it for the connection string
   - **Region**: Choose closest to your users (e.g., `US East (North Virginia)` or `US West (Oregon)`)
   - **Pricing Plan**: Free tier is fine for development
3. Click **"Create new project"**
4. Wait 2-3 minutes for project to finish provisioning

---

## Step 2: Enable Required Extensions

### 2.1 Open SQL Editor

1. In your Supabase project dashboard, click **"SQL Editor"** in the left sidebar
2. Click **"New query"**

### 2.2 Run Extension Commands

Copy and paste this SQL, then click **"Run"**:

```sql
-- Enable pgvector for RAG (vector similarity search)
CREATE EXTENSION IF NOT EXISTS vector;

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
```

You should see success messages for both extensions.

---

## Step 3: Get Project Credentials

### 3.1 Get API Credentials

1. Go to **Settings** → **API** (in left sidebar)
2. You'll see:
   - **Project URL**: `https://xxxxx.supabase.co` (save this!)
   - **anon public key**: `eyJhbGc...` (public key, safe for frontend)
   - **service_role key**: `eyJhbGc...` (private key, backend only - keep secret!)

### 3.2 Get Database Connection String

1. Go to **Settings** → **Database**
2. Scroll to **Connection string** section
3. Find **URI** format
4. Copy the connection string (it will look like):
   ```
   postgresql://postgres:[YOUR-PASSWORD]@db.xxxxx.supabase.co:5432/postgres
   ```
5. Replace `[YOUR-PASSWORD]` with the database password you set when creating the project

**Example**:
```
postgresql://postgres:mypassword123@db.abcdefghijklmnop.supabase.co:5432/postgres
```

---

## Step 4: Configure Authentication

### 4.1 Enable Email Provider

1. Go to **Authentication** → **Providers** (in left sidebar)
2. Find **Email** provider
3. Toggle it **ON** (should be enabled by default)
4. Configure email settings if needed (optional for dev)

### 4.2 Configure Site URL & Redirect URLs

1. Go to **Authentication** → **URL Configuration**
2. Set **Site URL**:
   - Development: `http://localhost:3000`
   - Production: `https://yourdomain.com` (set later)
3. Add **Redirect URLs**:
   - Development: `http://localhost:3000/auth/callback`
   - Production: `https://yourdomain.com/auth/callback` (set later)

---

## Step 5: Save Your Credentials

Create a secure note with these values:

```
Supabase Project: mentions-dev
Project URL: https://xxxxx.supabase.co
Anon Key: eyJhbGc... (public, for frontend)
Service Role Key: eyJhbGc... (private, for backend - keep secret!)
Database Password: [your password]
Database Connection String: postgresql://postgres:password@db.xxxxx.supabase.co:5432/postgres
```

---

## Step 6: Add Credentials to GCP Secret Manager

After you have the credentials, add them to GCP Secret Manager:

```bash
# Set active project
gcloud config set project mention001

# Add Supabase service role key
echo -n "eyJhbGc..." | gcloud secrets versions add supabase-service-role-key --data-file=-

# Add database connection string
echo -n "postgresql://postgres:password@db.xxxxx.supabase.co:5432/postgres" | \
  gcloud secrets versions add db-connection-string --data-file=-
```

---

## Step 7: Update Terraform Variables

Update `mentions_terraform/environments/dev/terraform.tfvars`:

```hcl
supabase_url = "https://xxxxx.supabase.co"  # Your Supabase project URL
```

---

## Step 8: Update Local Environment Files

### Backend `.env` (for local development)

Create `mentions_backend/.env`:

```bash
ENV=dev
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJhbGc...  # Service role key
DB_CONN=postgresql://postgres:password@db.xxxxx.supabase.co:5432/postgres
OPENAI_API_KEY=sk-...  # You'll add this later
GOOGLE_PROJECT_ID=mention001
GOOGLE_LOCATION=us-central1
KMS_KEYRING=reddit-secrets
KMS_KEY=reddit-token-key
ALLOW_POSTS=false
API_HOST=0.0.0.0
API_PORT=8000
LOG_LEVEL=DEBUG
LOG_JSON=false
```

### Frontend `.env.local` (for local development)

Create `mentions_frontend/.env.local`:

```bash
NEXT_PUBLIC_ENV=dev
NEXT_PUBLIC_SUPABASE_URL=https://xxxxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGc...  # Anon key (public)
NEXT_PUBLIC_API_URL=http://localhost:8000
```

---

## Verification Checklist

After setup, verify:

- [ ] Project created in Supabase dashboard
- [ ] Extensions enabled (`vector` and `uuid-ossp`)
- [ ] Credentials saved securely
- [ ] Email provider enabled
- [ ] Site URL and redirect URLs configured
- [ ] Credentials added to GCP Secret Manager (optional, can do later)
- [ ] Local `.env` files created (optional, can do later)

---

## Next Steps After Supabase Setup

1. **Run Database Migrations**
   - See `docs/03-DATABASE-SCHEMA.md`
   - Connect to Supabase and run migration SQL files

2. **Test Database Connection**
   ```bash
   # Using psql (if installed)
   psql "postgresql://postgres:password@db.xxxxx.supabase.co:5432/postgres"
   
   # Or use Supabase SQL Editor
   ```

3. **Add Credentials to GCP Secret Manager**
   - Use the commands in Step 6 above

4. **Update Terraform Variables**
   - Add `supabase_url` to `terraform.tfvars`

---

## Troubleshooting

### Extensions Fail to Enable
- Ensure you're using the SQL Editor (not Table Editor)
- Check you have proper permissions
- Verify PostgreSQL version supports extensions (Supabase uses PostgreSQL 15+)

### Can't Find Connection String
- Go to Settings → Database
- Look for "Connection string" section
- Use "URI" format, not "JDBC" or "Node.js"

### Authentication Not Working
- Verify Site URL matches your frontend URL exactly
- Check redirect URLs include the callback path
- Ensure Email provider is enabled

### Connection String Format
- Must include password: `postgresql://postgres:password@host:port/db`
- Replace `[YOUR-PASSWORD]` with actual password
- No spaces in the connection string

---

## Security Notes

- ⚠️ **Never commit** `.env` files to Git
- ⚠️ **Service Role Key** has admin access - keep it secret!
- ⚠️ **Anon Key** is public but still use environment variables
- ⚠️ **Database Password** - save securely, you'll need it for connection strings

---

## Quick Reference

### Supabase Dashboard URLs
- **Project Dashboard**: `https://supabase.com/dashboard/project/[project-id]`
- **SQL Editor**: Dashboard → SQL Editor
- **API Settings**: Dashboard → Settings → API
- **Database Settings**: Dashboard → Settings → Database
- **Auth Settings**: Dashboard → Authentication → URL Configuration

### Credential Locations
- **Project URL**: Settings → API → Project URL
- **Anon Key**: Settings → API → anon public key
- **Service Role Key**: Settings → API → service_role key (secret)
- **Connection String**: Settings → Database → Connection string → URI

---

## Support

- Supabase Docs: https://supabase.com/docs
- Supabase Discord: https://discord.supabase.com
- See `docs/02-ENVIRONMENT-SETUP.md` for more details

