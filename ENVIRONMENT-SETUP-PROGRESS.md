# Environment Setup Progress Tracker

This document tracks the progress of setting up all required environments and services for the Mentions project.

**Last Updated**: 2025-01-27

---

## Overview

We need to set up the following environments:
- **Development** (`dev`)
- **Staging** (`stg`)
- **Production** (`prod`)

For each environment, we need:
- Google Cloud Platform (GCP) project
- Supabase project
- Vercel project (frontend only)
- Terraform infrastructure
- Secrets and configurations

---

## ✅ Completed Tasks

### Infrastructure Setup
- [x] Google Cloud projects created
- [x] Supabase projects created
- [ ] Vercel project connected
- [x] Terraform structure initialized

### GCP Configuration
- [x] APIs enabled
- [x] KMS keyring and keys created
- [x] Secret Manager secrets created (with values)
- [x] Cloud Tasks queues created
- [x] Service accounts created
- [x] IAM permissions configured

### Supabase Configuration
- [x] Projects created (dev)
- [x] pgvector extension enabled
- [x] UUID extension enabled
- [x] Auth configured
- [x] Database migrations run (26 tables created)

### Vercel Configuration
- [ ] Project connected to GitHub repo
- [ ] Environment variables configured
- [ ] Domain configured (if applicable)

### Frontend Setup
- [x] Next.js 14 app created
- [x] TypeScript configured
- [x] Tailwind CSS configured
- [x] Supabase client setup
- [x] Basic structure created

---

## 📋 Detailed Progress

### 1. Google Cloud Platform

#### Development (`mention001`)
- [x] Project created (Project ID: mention001, Number: 666103574212)
- [x] Billing account linked (01237B-7198D6-449D59)
- [x] APIs enabled:
  - [x] Cloud Run API
  - [x] Cloud Tasks API
  - [x] Cloud Scheduler API
  - [x] Secret Manager API
  - [x] Cloud KMS API
  - [x] Artifact Registry API
  - [x] Cloud Build API
  - [x] Compute Engine API
  - [x] Cloud Storage API
- [x] KMS keyring: `reddit-secrets`
- [x] KMS key: `reddit-token-key`
- [x] Service account: `mentions-backend@mention001.iam.gserviceaccount.com`
- [x] Secret Manager secrets created (empty - add values later):
  - [x] `openai-api-key`
  - [x] `supabase-service-role-key`
  - [x] `db-connection-string`
  - [x] `stripe-secret-key` (optional)
  - [x] `stripe-webhook-secret` (optional)
- [x] Cloud Tasks queues:
  - [x] `reddit-posts-default`
  - [x] `generate-drafts`
  - [x] `verify-posts`
- [x] Terraform state bucket: `mention001-terraform-state`

#### Staging (`mentions-staging`)
- [ ] Project created
- [ ] Billing account linked
- [ ] APIs enabled
- [ ] KMS keyring and keys
- [ ] Service accounts
- [ ] Secrets configured
- [ ] Terraform state bucket: `mentions-terraform-state-staging`

#### Production (`mentions-prod`)
- [ ] Project created
- [ ] Billing account linked
- [ ] APIs enabled
- [ ] KMS keyring and keys
- [ ] Service accounts
- [ ] Secrets configured
- [ ] Terraform state bucket: `mentions-terraform-state-prod`

---

### 2. Supabase

#### Development (`mentions-dev`)
- [ ] Project created
- [ ] Project URL: `https://xxx.supabase.co`
- [ ] Anon key: `eyJ...`
- [ ] Service role key: `eyJ...` (stored in GCP Secret Manager)
- [ ] Database connection string: `postgresql://...`
- [ ] Extensions enabled:
  - [ ] `vector` (pgvector)
  - [ ] `uuid-ossp`
- [ ] Auth configured:
  - [ ] Email provider enabled
  - [ ] Redirect URLs configured

#### Staging (`mentions-stg`)
- [ ] Project created
- [ ] Extensions enabled
- [ ] Auth configured

#### Production (`mentions-prod`)
- [ ] Project created
- [ ] Extensions enabled
- [ ] Auth configured

---

### 3. Vercel

#### Frontend Deployment
- [ ] Project created
- [ ] Connected to GitHub repo: `mentions-frontend`
- [ ] Environment variables configured:
  - [ ] `NEXT_PUBLIC_ENV` (dev/staging/prod)
  - [ ] `NEXT_PUBLIC_SUPABASE_URL`
  - [ ] `NEXT_PUBLIC_SUPABASE_ANON_KEY`
  - [ ] `NEXT_PUBLIC_API_URL`
- [ ] Domains configured (if applicable)

---

### 4. Terraform Infrastructure

#### Structure
- [ ] Directory structure created
- [ ] Modules created:
  - [ ] `modules/project/`
  - [ ] `modules/kms/`
  - [ ] `modules/service-accounts/`
  - [ ] `modules/secret-manager/`
  - [ ] `modules/cloud-run/`
  - [ ] `modules/cloud-tasks/`
- [ ] Environment configs:
  - [ ] `environments/dev/`
  - [ ] `environments/staging/`
  - [ ] `environments/prod/`
- [ ] Helper scripts:
  - [ ] `scripts/init-backend.sh`
  - [ ] `scripts/apply-all.sh`

#### Deployment Status
- [ ] Dev environment applied
- [ ] Staging environment applied
- [ ] Prod environment applied

---

## 🔑 Required Credentials & Secrets

### To Be Collected/Configured

#### Google Cloud
- [ ] Billing account ID
- [ ] Organization ID (if applicable)
- [ ] Project IDs confirmed

#### Supabase
- [x] Dev project URL and keys (https://mjsxwzpxzalhgkekseyo.supabase.co)
- [ ] Staging project URL and keys
- [ ] Prod project URL and keys

#### OpenAI
- [x] API key (stored in Secret Manager)

#### Reddit (per company - configured later)
- [ ] Client IDs and secrets (encrypted with KMS)

---

## 📝 Notes

### Manual Steps Required
1. **Google Cloud**: Create projects and link billing (can be done via Terraform or manually)
2. **Supabase**: Create projects via web interface (no API for project creation)
3. **Vercel**: Connect via web interface
4. **Secrets**: Set secret values manually after creating Secret Manager secrets

### Next Steps After Setup
1. Run database migrations
2. Deploy backend to Cloud Run
3. Deploy frontend to Vercel
4. Test end-to-end flow
5. Configure monitoring and alerts

---

## 🚨 Important Reminders

- ⚠️ Never commit secrets to Git
- ⚠️ Use Terraform for all GCP infrastructure
- ⚠️ Keep `.tfvars` files out of Git (use `.tfvars.example`)
- ⚠️ Enable versioning on Terraform state buckets
- ⚠️ Use separate projects for dev/staging/prod
- ⚠️ Set `ALLOW_POSTS=false` in dev and staging

---

## 📚 Reference Documents

- [02-ENVIRONMENT-SETUP.md](docs/02-ENVIRONMENT-SETUP.md) - Detailed setup instructions
- [28-TERRAFORM-INFRASTRUCTURE.md](docs/28-TERRAFORM-INFRASTRUCTURE.md) - Terraform guide
- [01-TECH-STACK.md](docs/01-TECH-STACK.md) - Technology stack overview


