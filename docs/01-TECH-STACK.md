# Tech Stack & Architecture

## Overview
This document defines the complete technology stack for the Reddit Reply Assistant, including rationale for key choices.

---

## Frontend Stack

### Core Framework
**Next.js 14 (App Router)**
- Modern React framework with server components
- Built-in routing and API routes
- Excellent TypeScript support
- Optimized bundle sizes and performance

### Language
**TypeScript**
- Type safety across frontend codebase
- Better IDE support and refactoring
- Catch errors at compile time

### Styling
**Tailwind CSS**
- Utility-first CSS framework
- Rapid UI development
- Consistent design system
- Small production bundle with purging

### Authentication
**Supabase Auth**
- Email/password authentication
- Password recovery flows
- Session management
- JWT tokens for API authorization

### State Management
- React hooks for local state
- Server components for data fetching
- SWR or React Query for client-side caching (optional)

---

## Backend Stack

### Core Framework
**FastAPI (Python 3.11+)**
- High-performance async Python framework
- Automatic OpenAPI documentation
- Built-in request/response validation with Pydantic
- Excellent async support for I/O-bound operations

### LLM Orchestration
**LangGraph**
- State machine for complex LLM workflows
- Built on LangChain primitives
- Enables conditional routing (gates, judges)
- Easy to visualize and debug flow

### Reddit API Client
**asyncpraw or httpx**
- `asyncpraw`: Async Python Reddit API Wrapper
  - Easier OAuth management
  - Built-in rate limiting
- `httpx`: If more control needed
  - Full async HTTP client
  - Manual OAuth handling

### Request/Response Schemas
**Pydantic V2**
- Type validation for all API requests
- Serialization/deserialization
- Settings management
- OpenAPI schema generation

---

## Infrastructure (GCP)

### Compute
**Cloud Run**
- Serverless containers for FastAPI
- Auto-scaling based on traffic
- Pay-per-use pricing
- Easy deployment from Docker images

### Asynchronous Work
**Cloud Tasks**
- Reliable task queues
- Per-company queues: `reddit-posts-{company_id}`
- Retry logic with exponential backoff
- Task deduplication

### Scheduled Jobs
**Cloud Scheduler**
- Cron-based triggers
- Nightly learning/summarization jobs
- Cleanup tasks
- Triggers Cloud Run endpoints via HTTP

### Secrets & Encryption
**Secret Manager**
- Store API keys (OpenAI, Supabase service role)
- Separate secrets per environment

**Cloud KMS (Key Management Service)**
- Encrypt Reddit app client secrets
- Encrypt user OAuth refresh tokens
- Envelope encryption pattern

### Container Registry
**Artifact Registry**
- Store Docker images for Cloud Run
- Multi-environment image management

---

## Database

### Primary Database
**Supabase Postgres**
- Managed PostgreSQL with extensions
- Built-in auth integration
- Real-time subscriptions (optional for UI updates)
- Automatic API generation (can bypass for FastAPI)

### Vector Search
**pgvector Extension**
- Store embeddings as `vector(1536)` type
- Efficient similarity search with indexes
- Cosine/L2 distance operators
- Scales to millions of vectors

### Security
**Row Level Security (RLS)**
- Multi-tenant data isolation
- Company-scoped policies on all tables
- Enforced at database level
- Uses JWT claims from Supabase Auth

---

## LLM & AI

### Primary LLM
**GPT-5-mini** (via OpenAI API)
- Cost-effective for high volume
- Fast response times
- Good instruction following

### Temperature Settings
- **Drafting**: 0.5–0.6 (creative but consistent)
- **Judging**: 0.2–0.3 (deterministic evaluations)
- **Paraphrasing**: 0.7 (higher variation)

### Embeddings
**text-embedding-3-small** (OpenAI)
- 1536 dimensions
- Good quality-to-cost ratio
- Fast embedding generation

### Future: Fine-Tuning
- Collect training data via `training_events` table
- Export for supervised fine-tuning
- RLHF with human feedback signals

---

## Reddit Integration

### Authentication Model
**One Reddit App per Company**
- Each company registers their own Reddit app
- Stored: `client_id`, encrypted `client_secret`, `redirect_uri`
- Scopes: `identity`, `read`, `submit`, `vote`

**One OAuth Connection per User**
- Users authorize via OAuth2 flow
- Stored: encrypted `refresh_token`
- Fetch: `reddit_username`, karma, account age
- No passwords stored

### Security
- All Reddit secrets encrypted with Cloud KMS
- Refresh tokens re-encrypted on rotation
- Tokens never logged or exposed in API responses

---

## Development Tools

### Package Management
**Backend**: `pip` + `requirements.txt` (or `poetry`)  
**Frontend**: `npm` or `pnpm`

### Code Quality
**Backend**:
- `black` (code formatting)
- `ruff` (fast linting)
- `mypy` (type checking)

**Frontend**:
- ESLint + TypeScript
- Prettier (formatting)

### Testing
**Backend**:
- `pytest` (unit & integration tests)
- `pytest-asyncio` (async test support)
- `httpx` (test client for FastAPI)

**Frontend**:
- Jest + React Testing Library
- Playwright (E2E tests)

### Local Development
- Docker Compose for local Postgres + pgvector
- `.env.local` files for environment variables
- Hot reload for both frontend and backend

---

## Environment Management

### Environments
1. **Development** (`dev`)
   - Local or dev GCP project
   - `ALLOW_POSTS=false`
   - Supabase dev project

2. **Staging** (`stg`)
   - Staging GCP project
   - `ALLOW_POSTS=false` (or test subreddit only)
   - Supabase staging project

3. **Production** (`prod`)
   - Production GCP project
   - `ALLOW_POSTS=true`
   - Supabase production project

### Configuration
- Environment variables via `.env` files
- Secret Manager for sensitive values in GCP
- Never commit secrets to Git

---

## Architecture Diagram (Conceptual)

```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │
       │ HTTPS
       ▼
┌─────────────────┐
│   Next.js App   │◄─── Supabase Auth (JWT)
│  (Cloud Run or  │
│   Vercel)       │
└────────┬────────┘
         │
         │ API Calls
         ▼
┌──────────────────────┐
│   FastAPI Backend    │◄─── OpenAI API (LLM)
│    (Cloud Run)       │
└──────┬───────────────┘
       │
       ├─► Supabase Postgres (w/ pgvector)
       │   ├─ Multi-tenant tables
       │   └─ RAG embeddings
       │
       ├─► Reddit API (OAuth + posting)
       │
       ├─► Cloud Tasks
       │   ├─ Post queue
       │   └─ Verify queue
       │
       ├─► Cloud KMS (encrypt/decrypt)
       │
       └─► Cloud Scheduler (nightly jobs)
```

---

## Rationale for Key Choices

### Why FastAPI?
- Async-first for I/O-bound Reddit/LLM calls
- Strong typing with Pydantic
- Auto-generated API docs
- Python ecosystem for LLMs

### Why LangGraph?
- Complex orchestration with gates and judges
- Conditional routing based on LLM outputs
- Easy to add new nodes and modify flow
- Built-in state management

### Why Supabase?
- Managed Postgres with auth built-in
- pgvector support for RAG
- RLS for multi-tenant security
- Real-time capabilities for future features

### Why GCP?
- Cloud Run for serverless containers
- Cloud Tasks for reliable queues
- Cloud KMS for encryption
- Good Python SDK support

### Why Next.js?
- Modern React with server components
- App Router for layouts and nested routing
- Great TypeScript support
- Easy deployment to Vercel or Cloud Run

---

## Scalability Considerations

### Database
- Postgres can handle millions of rows
- pgvector indexes for fast similarity search
- Connection pooling via pgbouncer if needed

### Compute
- Cloud Run auto-scales to 100+ instances
- Each FastAPI instance handles multiple concurrent requests (async)

### Reddit API
- Rate limits: ~60 requests/min per OAuth token
- Multiple accounts per company for higher throughput
- Cooldown logic prevents hitting limits

### Cost
- Cloud Run: pay per request, scales to zero
- Supabase: pay for storage and compute
- OpenAI: biggest cost driver (optimize prompts and caching)

---

## Next Steps
1. Set up GCP project and enable APIs
2. Create Supabase project(s) for each environment
3. Configure Cloud KMS keyring and keys
4. Scaffold FastAPI and Next.js repositories
5. See **02-ENVIRONMENT-SETUP.md** for detailed setup

