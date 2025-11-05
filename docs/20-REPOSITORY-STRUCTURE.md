# Repository Structure

## Overview
The Mentions project is organized as a monorepo with separate directories for backend and frontend applications, plus a shared docs folder for all planning and implementation documentation.

---

## Root Directory Layout

```
mentions/
├── mentions_backend/      # FastAPI backend application
├── mentions_frontend/     # Next.js frontend application
├── mentions_terraform/    # Terraform infrastructure as code
├── docs/                  # All planning and documentation
├── .github/              # GitHub Actions CI/CD workflows
├── .gitignore
└── README.md
```

---

## Backend Directory (`mentions_backend/`)

**Framework**: FastAPI (Python 3.11)  
**Purpose**: API server, LangGraph orchestration, Reddit integration, RAG pipeline

### Structure

```
mentions_backend/
├── api/                   # API route handlers
│   ├── __init__.py
│   ├── auth.py           # Authentication endpoints
│   ├── companies.py      # Company management
│   ├── reddit_accounts.py # Reddit OAuth & account management
│   ├── keywords.py       # Keyword configuration
│   ├── generate.py       # Trigger generation flow
│   ├── drafts.py         # Draft management & approval
│   ├── posts.py          # Posting & verification
│   ├── prompts.py        # Prompt templates
│   ├── rag.py            # RAG data ingestion
│   ├── analytics.py      # Analytics endpoints
│   └── webhooks.py       # Stripe webhooks
│
├── core/                 # Core configuration and utilities
│   ├── __init__.py
│   ├── config.py         # Settings from environment variables
│   ├── database.py       # Supabase client & connection
│   ├── auth.py           # JWT validation & user context
│   └── logging.py        # Structured logging setup
│
├── graph/                # LangGraph generation pipeline
│   ├── __init__.py
│   ├── state.py          # State definitions
│   ├── build.py          # Graph builder
│   ├── checkpointer.py   # PostgreSQL checkpointer singleton
│   └── nodes/            # Individual graph nodes
│       ├── __init__.py
│       ├── fetch_subreddits.py
│       ├── judge_subreddit.py
│       ├── fetch_rules.py
│       ├── fetch_threads.py
│       ├── rank_threads.py
│       ├── rag_retrieve.py
│       ├── draft_compose.py
│       ├── vary_draft.py
│       ├── judge_draft.py
│       └── emit_ready.py
│
├── reddit/               # Reddit API integration
│   ├── __init__.py
│   ├── client.py         # Reddit API client wrapper
│   ├── oauth.py          # OAuth flow handlers
│   ├── encryption.py     # Token encryption/decryption (KMS)
│   ├── poster.py         # Posting & verification logic
│   └── rate_limiter.py   # Reddit rate limiting
│
├── rag/                  # RAG system
│   ├── __init__.py
│   ├── ingest.py         # Document ingestion & chunking
│   ├── embed.py          # OpenAI embeddings
│   ├── store.py          # pgvector storage
│   └── retrieve.py       # Semantic search & retrieval
│
├── llm/                  # LLM utilities
│   ├── __init__.py
│   ├── client.py         # OpenAI client wrapper
│   ├── prompts.py        # Prompt rendering
│   └── judge.py          # Judge LLM utilities
│
├── models/               # Pydantic models
│   ├── __init__.py
│   ├── requests.py       # API request models
│   ├── responses.py      # API response models
│   └── domain.py         # Domain models (Company, Draft, etc.)
│
├── services/             # Business logic services
│   ├── __init__.py
│   ├── company.py        # Company operations
│   ├── draft.py          # Draft management
│   ├── post.py           # Posting orchestration
│   ├── fine_tuning.py    # Fine-tuning export & job management
│   └── billing.py        # Stripe subscription management
│
├── tasks/                # Background tasks (Cloud Tasks handlers)
│   ├── __init__.py
│   ├── generate.py       # Generation task handler
│   ├── verify_post.py    # Post verification task
│   └── training_export.py # Training data export task
│
├── migrations/           # Database migrations (if using Alembic)
│   └── versions/
│
├── tests/                # Test suite
│   ├── __init__.py
│   ├── conftest.py       # Pytest fixtures
│   ├── unit/             # Unit tests
│   ├── integration/      # Integration tests
│   └── e2e/              # End-to-end tests
│
├── .env.example          # Example environment variables
├── .dockerignore
├── .python-version       # Python version (3.11)
├── Dockerfile            # Docker image for Cloud Run
├── requirements.txt      # Python dependencies
├── pyproject.toml        # Python project config (optional)
├── pytest.ini            # Pytest configuration
└── main.py               # FastAPI application entry point
```

### Key Files

#### `main.py`
```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from core.config import settings
from core.logging import setup_logging
from api import (
    auth,
    companies,
    reddit_accounts,
    keywords,
    generate,
    drafts,
    posts,
    prompts,
    rag,
    analytics,
    webhooks,
)

# Setup structured logging
setup_logging()

app = FastAPI(
    title="Mentions API",
    description="AI-powered Reddit reply assistant",
    version="1.0.0",
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Health check
@app.get("/health")
def health_check():
    return {"status": "healthy"}

# Include routers
app.include_router(auth.router, prefix="/api/auth", tags=["auth"])
app.include_router(companies.router, prefix="/api/companies", tags=["companies"])
app.include_router(reddit_accounts.router, prefix="/api/reddit-accounts", tags=["reddit-accounts"])
app.include_router(keywords.router, prefix="/api/keywords", tags=["keywords"])
app.include_router(generate.router, prefix="/api/generate", tags=["generate"])
app.include_router(drafts.router, prefix="/api/drafts", tags=["drafts"])
app.include_router(posts.router, prefix="/api/posts", tags=["posts"])
app.include_router(prompts.router, prefix="/api/prompts", tags=["prompts"])
app.include_router(rag.router, prefix="/api/rag", tags=["rag"])
app.include_router(analytics.router, prefix="/api/analytics", tags=["analytics"])
app.include_router(webhooks.router, prefix="/api/webhooks", tags=["webhooks"])
```

#### `requirements.txt`
```txt
# Web Framework
fastapi==0.104.1
uvicorn[standard]==0.24.0
pydantic==2.5.0
pydantic-settings==2.1.0

# Database
supabase==2.0.3
asyncpg==0.29.0
psycopg2-binary==2.9.9

# LangGraph & LLM
langgraph==0.0.25
langchain==0.1.0
langchain-openai==0.0.2
openai==1.6.0

# Reddit
asyncpraw==7.7.1
httpx==0.25.2

# RAG & Embeddings
pgvector==0.2.3

# Google Cloud
google-cloud-tasks==2.14.2
google-cloud-secret-manager==2.17.0
google-cloud-kms==2.19.2

# Authentication
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4

# Billing
stripe==7.8.0

# Utilities
python-dotenv==1.0.0
structlog==23.2.0
tenacity==8.2.3

# Testing
pytest==7.4.3
pytest-asyncio==0.21.1
pytest-cov==4.1.0
httpx==0.25.2  # For TestClient
```

---

## Frontend Directory (`mentions_frontend/`)

**Framework**: Next.js 14 (App Router)  
**Purpose**: User interface, authentication, content review, settings

### Structure

```
mentions_frontend/
├── app/                  # Next.js 14 App Router
│   ├── layout.tsx        # Root layout with Supabase provider
│   ├── page.tsx          # Landing page (/)
│   ├── globals.css       # Global styles & Tailwind imports
│   │
│   ├── (auth)/           # Auth route group (public)
│   │   ├── login/
│   │   │   └── page.tsx
│   │   ├── signup/
│   │   │   └── page.tsx
│   │   ├── verify-email/
│   │   │   └── page.tsx
│   │   └── reset-password/
│   │       └── page.tsx
│   │
│   ├── (marketing)/      # Marketing pages (public)
│   │   ├── about/
│   │   │   └── page.tsx
│   │   ├── pricing/
│   │   │   └── page.tsx
│   │   ├── terms/
│   │   │   └── page.tsx
│   │   └── privacy/
│   │       └── page.tsx
│   │
│   ├── (dashboard)/      # Protected dashboard routes
│   │   ├── layout.tsx    # Dashboard layout with sidebar
│   │   ├── dashboard/
│   │   │   └── page.tsx  # Dashboard home
│   │   ├── inbox/
│   │   │   └── page.tsx  # Content review (main inbox)
│   │   ├── drafts/
│   │   │   └── [id]/
│   │   │       └── page.tsx  # Draft detail view
│   │   ├── analytics/
│   │   │   └── page.tsx
│   │   └── settings/
│   │       ├── page.tsx          # Settings home (redirect to company)
│   │       ├── company/
│   │       │   └── page.tsx
│   │       ├── profile/
│   │       │   └── page.tsx
│   │       ├── reddit-accounts/
│   │       │   └── page.tsx
│   │       ├── keywords/
│   │       │   └── page.tsx
│   │       ├── prompts/
│   │       │   └── page.tsx
│   │       ├── rag/
│   │       │   └── page.tsx
│   │       └── billing/
│   │           └── page.tsx
│   │
│   ├── api/              # API route handlers (Next.js API routes)
│   │   ├── auth/
│   │   │   └── callback/
│   │   │       └── route.ts  # Supabase auth callback
│   │   └── webhooks/
│   │       └── stripe/
│   │           └── route.ts  # Stripe webhook handler
│   │
│   ├── sitemap.ts        # Dynamic sitemap
│   ├── robots.ts         # Robots.txt
│   └── not-found.tsx     # 404 page
│
├── components/           # React components
│   ├── layout/
│   │   ├── Navbar.tsx
│   │   ├── Footer.tsx
│   │   ├── Sidebar.tsx
│   │   └── DashboardLayout.tsx
│   │
│   ├── landing/          # Landing page sections
│   │   ├── HeroSection.tsx
│   │   ├── FeaturesSection.tsx
│   │   ├── HowItWorksSection.tsx
│   │   ├── PricingSection.tsx
│   │   └── CTASection.tsx
│   │
│   ├── auth/
│   │   ├── LoginForm.tsx
│   │   ├── SignupForm.tsx
│   │   └── ResetPasswordForm.tsx
│   │
│   ├── inbox/
│   │   ├── DraftCard.tsx
│   │   ├── DraftTable.tsx
│   │   ├── FilterBar.tsx
│   │   └── RiskBadge.tsx
│   │
│   ├── drafts/
│   │   ├── DraftViewer.tsx
│   │   ├── DraftEditor.tsx
│   │   ├── ThreadContext.tsx
│   │   ├── ApprovalControls.tsx
│   │   └── PostingStatus.tsx
│   │
│   ├── settings/
│   │   ├── CompanySettings.tsx
│   │   ├── ProfileSettings.tsx
│   │   ├── RedditAccountCard.tsx
│   │   ├── RedditConnectButton.tsx
│   │   ├── KeywordManager.tsx
│   │   ├── PromptEditor.tsx
│   │   ├── RAGUploader.tsx
│   │   └── BillingSettings.tsx
│   │
│   ├── analytics/
│   │   ├── StatsCard.tsx
│   │   ├── PostsChart.tsx
│   │   └── SubredditTable.tsx
│   │
│   ├── seo/
│   │   ├── StructuredData.tsx
│   │   └── MetaTags.tsx
│   │
│   └── ui/               # shadcn/ui components
│       ├── button.tsx
│       ├── card.tsx
│       ├── dialog.tsx
│       ├── dropdown-menu.tsx
│       ├── input.tsx
│       ├── label.tsx
│       ├── select.tsx
│       ├── table.tsx
│       ├── tabs.tsx
│       ├── textarea.tsx
│       ├── toast.tsx
│       └── ...
│
├── lib/                  # Utility libraries
│   ├── supabase/
│   │   ├── client.ts     # Browser Supabase client
│   │   ├── server.ts     # Server-side Supabase client
│   │   └── middleware.ts # Auth middleware
│   ├── api/
│   │   ├── client.ts     # Backend API client
│   │   └── endpoints.ts  # API endpoint definitions
│   ├── stripe/
│   │   └── client.ts     # Stripe client
│   └── utils.ts          # General utilities
│
├── hooks/                # Custom React hooks
│   ├── useAuth.ts
│   ├── useCompany.ts
│   ├── useDrafts.ts
│   └── useToast.ts
│
├── types/                # TypeScript type definitions
│   ├── database.ts       # Supabase generated types
│   ├── api.ts            # Backend API types
│   └── index.ts
│
├── styles/
│   └── globals.css       # Global styles
│
├── public/               # Static assets
│   ├── images/
│   │   ├── logo.svg
│   │   ├── hero-dashboard.png
│   │   └── og-image.png
│   ├── favicon.ico
│   ├── apple-touch-icon.png
│   └── site.webmanifest
│
├── .env.example          # Example environment variables
├── .env.local            # Local environment (gitignored)
├── .eslintrc.json
├── .prettierrc
├── components.json       # shadcn/ui config
├── next.config.js
├── package.json
├── postcss.config.js
├── tailwind.config.ts
├── tsconfig.json
└── README.md
```

### Key Files

#### `app/layout.tsx`
```tsx
import { Inter } from 'next/font/google'
import { Metadata } from 'next'
import { SupabaseProvider } from '@/lib/supabase/provider'
import { Toaster } from '@/components/ui/toaster'
import './globals.css'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: {
    default: 'Mentions - AI-Powered Reddit Marketing Assistant',
    template: '%s | Mentions'
  },
  description: 'Turn Reddit into your customer acquisition channel',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <SupabaseProvider>
          {children}
          <Toaster />
        </SupabaseProvider>
      </body>
    </html>
  )
}
```

#### `package.json`
```json
{
  "name": "mentions-frontend",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "type-check": "tsc --noEmit"
  },
  "dependencies": {
    "next": "14.0.4",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "@supabase/supabase-js": "^2.38.4",
    "@supabase/ssr": "^0.0.10",
    "@stripe/stripe-js": "^2.3.0",
    "lucide-react": "^0.294.0",
    "class-variance-authority": "^0.7.0",
    "clsx": "^2.0.0",
    "tailwind-merge": "^2.1.0",
    "date-fns": "^2.30.0",
    "zod": "^3.22.4",
    "react-hook-form": "^7.48.2",
    "@hookform/resolvers": "^3.3.2"
  },
  "devDependencies": {
    "@types/node": "^20.10.0",
    "@types/react": "^18.2.42",
    "@types/react-dom": "^18.2.17",
    "typescript": "^5.3.2",
    "tailwindcss": "^3.3.6",
    "postcss": "^8.4.32",
    "autoprefixer": "^10.4.16",
    "eslint": "^8.54.0",
    "eslint-config-next": "14.0.4",
    "prettier": "^3.1.0"
  }
}
```

---

## Terraform Directory (`mentions_terraform/`)

**Purpose**: Infrastructure as Code for all GCP resources (dev, staging, production)

### Structure

```
mentions_terraform/
├── README.md                     # Quick start guide
├── .gitignore                    # Ignore .tfstate, .terraform/, etc.
├── terraform.tfvars.example      # Example variables
│
├── environments/                 # Environment-specific configs
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars      # Dev-specific values (gitignored)
│   │   └── backend.tf            # State backend config
│   ├── staging/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars
│       └── backend.tf
│
├── modules/                      # Reusable Terraform modules
│   ├── project/                  # GCP project setup
│   ├── kms/                      # KMS keyring & keys
│   ├── cloud-run/                # Cloud Run service
│   ├── cloud-tasks/              # Cloud Tasks queues
│   ├── secret-manager/           # Secret Manager secrets
│   ├── service-accounts/         # IAM service accounts
│   └── scheduler/                # Cloud Scheduler jobs
│
└── scripts/                      # Helper scripts
    ├── init-backend.sh           # Initialize Terraform backend
    ├── apply-all.sh              # Apply all environments
    └── destroy-env.sh            # Destroy specific environment
```

### Key Terraform Commands

```bash
# Navigate to environment
cd mentions_terraform/environments/dev

# Initialize Terraform
terraform init

# Plan changes
terraform plan

# Apply changes
terraform apply

# Show outputs
terraform output
```

See **[28-TERRAFORM-INFRASTRUCTURE.md](./28-TERRAFORM-INFRASTRUCTURE.md)** for complete Terraform setup and usage.

---

## Documentation Directory (`docs/`)

All planning, architecture, and implementation documentation lives here. See **[00-INDEX.md](./00-INDEX.md)** for complete document listing.

**Structure:**
```
docs/
├── 00-INDEX.md                   # This index
├── 01-TECH-STACK.md
├── 02-ENVIRONMENT-SETUP.md
├── 03-DATABASE-SCHEMA.md
├── M1-FOUNDATIONS.md
├── M2-GENERATION-FLOW.md
├── M3-REVIEW-UI.md
├── M4-VOLUME-LEARNING.md
├── M5-PRODUCTION.md
├── 10-LANGGRAPH-FLOW.md
├── 11-RAG-IMPLEMENTATION.md
├── 12-POSTING-FLOW.md
├── 13-RATE-LIMITING.md
├── 14-UI-SPECIFICATIONS.md
├── 15-TESTING-PLAN.md
├── 16-RL-FINE-TUNING.md
├── 17-GPT5-PROMPTING-GUIDE.md
├── 18-REDDIT-API-REFERENCE.md
├── 19-COMPANY-FINE-TUNING.md
├── 20-REPOSITORY-STRUCTURE.md    # This document
├── 21-API-ENDPOINTS.md
├── 22-HARD-RULES.md
├── 23-OBSERVABILITY.md
├── 24-LOGGING-DEBUGGING.md
├── 25-FRONTEND-PAGES.md
├── 26-PRICING-BILLING.md
└── 27-RESPONSIVE-SEO.md
```

---

## CI/CD Directory (`.github/`)

**Structure:**
```
.github/
└── workflows/
    ├── backend-ci.yml        # Backend tests & Docker build
    ├── frontend-ci.yml       # Frontend tests & build
    ├── deploy-backend.yml    # Deploy to Cloud Run
    └── deploy-frontend.yml   # Deploy to Vercel/Cloud Run
```

---

## Environment Files

### Backend `.env` (development)
```bash
# Environment
ENV=dev

# Database
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=xxx
DB_CONN=postgresql://...

# OpenAI
OPENAI_API_KEY=sk-...

# Google Cloud
GOOGLE_PROJECT_ID=mentions-dev
GOOGLE_LOCATION=us-central1
KMS_KEYRING=reddit-secrets
KMS_KEY=reddit-token-key

# Reddit (one app per company - stored encrypted in DB)
# No hardcoded credentials

# Stripe
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...

# Logging
LOG_LEVEL=INFO
LOG_JSON=false

# Safety
ALLOW_POSTS=false  # Set to true only in production
```

### Frontend `.env.local` (development)
```bash
# Supabase (public keys)
NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=xxx

# Backend API
NEXT_PUBLIC_API_URL=http://localhost:8000

# Stripe (public key)
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_...

# Environment
NEXT_PUBLIC_ENV=dev
```

---

## Git Configuration

### Root `.gitignore`
```gitignore
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
ENV/
.venv

# Node
node_modules/
.next/
out/
build/
dist/

# Terraform
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
terraform.tfvars
*.tfplan
crash.log
crash.*.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# Environment
.env
.env.local
.env.*.local

# IDEs
.vscode/
.idea/
*.swp
*.swo
.DS_Store

# Testing
.coverage
htmlcov/
.pytest_cache/
coverage/

# Logs
*.log
logs/

# Build artifacts
*.egg-info/
dist/
build/
```

---

## Development Workflow

### Starting Backend (Local)

```bash
cd mentions_backend

# Create virtual environment
python3.11 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Copy environment variables
cp .env.example .env
# Edit .env with your credentials

# Run migrations (if using Alembic)
alembic upgrade head

# Start server
uvicorn main:app --reload --port 8000
```

Backend runs at: `http://localhost:8000`  
API docs: `http://localhost:8000/docs`

### Starting Frontend (Local)

```bash
cd mentions_frontend

# Install dependencies
npm install

# Copy environment variables
cp .env.example .env.local
# Edit .env.local with your credentials

# Generate Supabase types
npm run types  # Optional: if you have type generation setup

# Start dev server
npm run dev
```

Frontend runs at: `http://localhost:3000`

---

## Deployment

### Backend Deployment (Cloud Run)

See **[02-ENVIRONMENT-SETUP.md](./02-ENVIRONMENT-SETUP.md)** for complete deployment instructions.

```bash
cd mentions_backend

# Build Docker image
docker build -t gcr.io/mentions-prod/backend:latest .

# Push to GCR
docker push gcr.io/mentions-prod/backend:latest

# Deploy to Cloud Run
gcloud run deploy mentions-backend \
  --image gcr.io/mentions-prod/backend:latest \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated
```

### Frontend Deployment (Vercel - Recommended)

```bash
cd mentions_frontend

# Install Vercel CLI
npm install -g vercel

# Deploy
vercel --prod
```

Alternatively, connect your GitHub repo to Vercel for automatic deployments on push.

---

## Testing

### Backend Tests

```bash
cd mentions_backend

# Run all tests
pytest

# Run with coverage
pytest --cov=. --cov-report=html

# Run specific test file
pytest tests/unit/test_judge.py

# Run integration tests
pytest tests/integration/
```

### Frontend Tests

```bash
cd mentions_frontend

# Type checking
npm run type-check

# Linting
npm run lint

# Unit tests (if using Jest/Vitest)
npm test

# E2E tests (if using Playwright)
npm run test:e2e
```

---

## Quick Reference

| Component | Directory | Port | Tech Stack |
|-----------|-----------|------|------------|
| Backend API | `mentions_backend/` | 8000 | FastAPI, LangGraph, Python 3.11 |
| Frontend | `mentions_frontend/` | 3000 | Next.js 14, TypeScript, Tailwind |
| Infrastructure | `mentions_terraform/` | - | Terraform, GCP |
| Documentation | `docs/` | - | Markdown |
| Database | Supabase | - | PostgreSQL + pgvector |

---

## Best Practices

### Code Organization
✅ Keep business logic in `services/`  
✅ Keep API routes thin (just validation & orchestration)  
✅ Use Pydantic models for all request/response validation  
✅ Use TypeScript strict mode for frontend  
✅ Follow Next.js App Router conventions  

### File Naming
✅ Backend: `snake_case.py`  
✅ Frontend: `PascalCase.tsx` for components, `camelCase.ts` for utilities  
✅ Use index files to simplify imports  

### Import Organization
✅ Standard library imports first  
✅ Third-party imports second  
✅ Local imports last  
✅ Absolute imports preferred over relative (use path aliases)  

### Environment Variables
✅ Never commit `.env` files  
✅ Always provide `.env.example` templates  
✅ Use strong typing for environment variables (Pydantic Settings)  
✅ Validate environment on startup  

---

## Additional Resources

- **Backend API Docs**: `http://localhost:8000/docs` (Swagger UI)
- **Database Schema**: See [03-DATABASE-SCHEMA.md](./03-DATABASE-SCHEMA.md)
- **API Endpoints**: See [21-API-ENDPOINTS.md](./21-API-ENDPOINTS.md)
- **Deployment**: See [02-ENVIRONMENT-SETUP.md](./02-ENVIRONMENT-SETUP.md)
- **Testing**: See [15-TESTING-PLAN.md](./15-TESTING-PLAN.md)

