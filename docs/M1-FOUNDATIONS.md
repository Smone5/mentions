# Milestone 1: Foundations

## Goal
Establish authentication, multi-company support, Reddit app/account connection, and basic schema.

**Timeline**: Weeks 1-2  
**Depends On**: Environment setup complete (02-ENVIRONMENT-SETUP.md)  
**Outputs**: Users can sign up, connect Reddit accounts, view profiles

---

## Acceptance Criteria

- [ ] Users can sign up with email/password
- [ ] Users can log in and reset password
- [ ] Company owners can configure a Reddit app
- [ ] Users can connect Reddit accounts via OAuth
- [ ] Reddit profile data (username, karma) displayed in UI
- [ ] All Reddit secrets encrypted with KMS
- [ ] Basic FastAPI health check endpoint deployed

---

## Tasks

### 1.1 Supabase Project Setup

**Backend**
- [ ] Create Supabase projects for dev/stg/prod environments
- [ ] Enable email/password authentication
- [ ] Configure email templates for password reset
- [ ] Add redirect URLs for OAuth callbacks
- [ ] Test signup/login/password-reset flows

**Frontend**
- [ ] Install `@supabase/ssr` and `@supabase/auth-helpers-nextjs`
- [ ] Create Supabase client utility (`lib/supabase.ts`)
- [ ] Set up middleware for session management
- [ ] Create auth pages:
  - `/login`
  - `/signup`
  - `/reset-password`
  - `/auth/callback`

**Implementation Guide**:

```typescript
// lib/supabase.ts
import { createBrowserClient } from '@supabase/ssr'

export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  )
}
```

---

### 1.2 Database Migrations

- [ ] Run all schema migrations from **03-DATABASE-SCHEMA.md**:
  - Core multi-tenant structure (companies, user_profiles)
  - Prompt library (prompts)
  - Reddit integration (company_reddit_apps, reddit_connections)
  - Posting eligibility (posting_eligibility)
  - RAG tables (company_docs, company_doc_chunks)
  - Subreddit history (subreddit_history)
  - Artifacts and drafts (threads, ready_artifacts, draft_versions)
  - Posts and moderation (posts, moderation_events, approvals)
  - Feedback and training (subreddit_feedback, subreddit_accounts, training_events)

- [ ] Enable pgvector extension
- [ ] Create indexes
- [ ] Verify all foreign keys and constraints

**Commands**:
```bash
psql $DB_CONN -f db/migrations/001_core_tables.sql
psql $DB_CONN -f db/migrations/002_reddit_tables.sql
psql $DB_CONN -f db/migrations/003_rag_tables.sql
# ... etc
```

---

### 1.3 FastAPI Scaffold

**Structure**:
```
mentions_backend/
├── main.py
├── core/
│   ├── config.py       # Settings from env vars
│   ├── kms.py          # KMS encrypt/decrypt helpers
│   └── deps.py         # FastAPI dependencies
├── api/
│   ├── auth.py         # Auth endpoints
│   ├── reddit_oauth.py # Reddit OAuth flow
│   └── health.py       # Health check
├── db/
│   ├── queries.py      # SQL query helpers
│   └── migrations/     # Migration files
└── requirements.txt
```

**Core Files**:

```python
# main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from api import health, auth, reddit_oauth

app = FastAPI(title="Mentions Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],  # Update for prod
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router, tags=["health"])
app.include_router(auth.router, prefix="/api/auth", tags=["auth"])
app.include_router(reddit_oauth.router, prefix="/api/reddit", tags=["reddit"])
```

```python
# core/config.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    env: str = "dev"
    supabase_url: str
    supabase_service_role_key: str
    db_conn: str
    openai_api_key: str
    google_project_id: str
    google_location: str = "us-central1"
    kms_keyring: str
    kms_key: str
    allow_posts: bool = False
    
    class Config:
        env_file = ".env"

settings = Settings()
```

```python
# api/health.py
from fastapi import APIRouter

router = APIRouter()

@router.get("/health")
async def health_check():
    return {
        "status": "ok",
        "env": settings.env,
        "allow_posts": settings.allow_posts
    }
```

- [ ] Create basic FastAPI app with health endpoint
- [ ] Add CORS middleware
- [ ] Load settings from environment variables
- [ ] Test locally: `uvicorn main:app --reload`

---

### 1.4 Cloud KMS Integration

**Purpose**: Encrypt Reddit app secrets and OAuth refresh tokens before storing in database.

**Backend Implementation**:

```python
# core/kms.py
from google.cloud import kms
from core.config import settings
import base64

def get_kms_client():
    return kms.KeyManagementServiceClient()

def get_key_name():
    return (
        f"projects/{settings.google_project_id}/"
        f"locations/{settings.google_location}/"
        f"keyRings/{settings.kms_keyring}/"
        f"cryptoKeys/{settings.kms_key}"
    )

def encrypt(plaintext: str) -> str:
    """Encrypt plaintext and return base64-encoded ciphertext."""
    client = get_kms_client()
    key_name = get_key_name()
    
    plaintext_bytes = plaintext.encode('utf-8')
    response = client.encrypt(
        request={
            "name": key_name,
            "plaintext": plaintext_bytes
        }
    )
    
    return base64.b64encode(response.ciphertext).decode('utf-8')

def decrypt(ciphertext_b64: str) -> str:
    """Decrypt base64-encoded ciphertext and return plaintext."""
    client = get_kms_client()
    key_name = get_key_name()
    
    ciphertext = base64.b64decode(ciphertext_b64)
    response = client.decrypt(
        request={
            "name": key_name,
            "ciphertext": ciphertext
        }
    )
    
    return response.plaintext.decode('utf-8')
```

**Tasks**:
- [ ] Implement `encrypt()` and `decrypt()` functions
- [ ] Test with sample data
- [ ] Add error handling for KMS failures
- [ ] Log encryption operations (without sensitive data)

**Security Notes**:
- Never log plaintext secrets
- Never return decrypted tokens in API responses
- Only decrypt when needed (e.g., posting)

---

### 1.5 Company Reddit App Configuration

**Database**: `company_reddit_apps` table (already created in schema)

**Backend Endpoints**:

```python
# api/reddit_oauth.py
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from core.kms import encrypt, decrypt
from core.deps import get_current_user, get_db

router = APIRouter()

class RedditAppConfig(BaseModel):
    client_id: str
    client_secret: str
    redirect_uri: str

@router.post("/app/configure")
async def configure_reddit_app(
    config: RedditAppConfig,
    user = Depends(get_current_user),
    db = Depends(get_db)
):
    # Verify user is owner/admin
    if user.role not in ['owner', 'admin']:
        raise HTTPException(status_code=403, detail="Not authorized")
    
    # Encrypt client_secret
    encrypted_secret = encrypt(config.client_secret)
    
    # Upsert to database
    query = """
        insert into company_reddit_apps (
            company_id, client_id, client_secret_ciphertext, redirect_uri, created_by
        ) values (%s, %s, %s, %s, %s)
        on conflict (company_id) do update set
            client_id = excluded.client_id,
            client_secret_ciphertext = excluded.client_secret_ciphertext,
            redirect_uri = excluded.redirect_uri,
            updated_at = now()
        returning id
    """
    
    result = await db.fetchone(
        query,
        user.company_id,
        config.client_id,
        encrypted_secret,
        config.redirect_uri,
        user.id
    )
    
    return {"id": result['id'], "message": "Reddit app configured"}

@router.get("/app/config")
async def get_reddit_app_config(
    user = Depends(get_current_user),
    db = Depends(get_db)
):
    query = """
        select id, client_id, redirect_uri, created_at
        from company_reddit_apps
        where company_id = %s
    """
    result = await db.fetchone(query, user.company_id)
    
    if not result:
        return {"configured": False}
    
    return {
        "configured": True,
        "client_id": result['client_id'],
        "redirect_uri": result['redirect_uri']
    }
```

**Frontend UI** (`/settings/reddit-app`):
- [ ] Form with fields:
  - Client ID
  - Client Secret (password input)
  - Redirect URI
- [ ] Show instructions for creating Reddit app
- [ ] Display current config (without secret)
- [ ] Save button calls `/api/reddit/app/configure`

---

### 1.6 User Reddit OAuth Flow

**Flow**:
1. User clicks "Connect Reddit Account"
2. Backend generates OAuth URL with state parameter
3. User authorizes on Reddit
4. Reddit redirects to callback URL
5. Backend exchanges code for refresh token
6. Backend fetches user profile and karma
7. Backend encrypts refresh token and saves to `reddit_connections`

**Backend Implementation**:

```python
# api/reddit_oauth.py continued

import secrets
from urllib.parse import urlencode

@router.get("/connect/start")
async def start_reddit_oauth(
    user = Depends(get_current_user),
    db = Depends(get_db)
):
    # Get company's Reddit app config
    app_config = await db.fetchone(
        "select client_id, redirect_uri from company_reddit_apps where company_id = %s",
        user.company_id
    )
    
    if not app_config:
        raise HTTPException(status_code=400, detail="Reddit app not configured")
    
    # Generate state parameter
    state = secrets.token_urlsafe(32)
    
    # Store state temporarily (use Redis or session storage)
    # For now, we can use JWT with short expiry
    
    # Build authorization URL
    params = {
        "client_id": app_config['client_id'],
        "response_type": "code",
        "state": state,
        "redirect_uri": app_config['redirect_uri'],
        "duration": "permanent",
        "scope": "identity read submit vote"
    }
    
    auth_url = f"https://www.reddit.com/api/v1/authorize?{urlencode(params)}"
    
    return {"auth_url": auth_url, "state": state}

@router.get("/connect/callback")
async def reddit_oauth_callback(
    code: str,
    state: str,
    user = Depends(get_current_user),
    db = Depends(get_db)
):
    # Verify state (important for security)
    # ... verify state matches ...
    
    # Get app config
    app_config = await db.fetchone(
        """
        select client_id, client_secret_ciphertext, redirect_uri 
        from company_reddit_apps 
        where company_id = %s
        """,
        user.company_id
    )
    
    client_secret = decrypt(app_config['client_secret_ciphertext'])
    
    # Exchange code for tokens
    import httpx
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://www.reddit.com/api/v1/access_token",
            auth=(app_config['client_id'], client_secret),
            data={
                "grant_type": "authorization_code",
                "code": code,
                "redirect_uri": app_config['redirect_uri']
            },
            headers={"User-Agent": "mentions/1.0"}
        )
        
        if response.status_code != 200:
            raise HTTPException(status_code=400, detail="Failed to get tokens")
        
        tokens = response.json()
        access_token = tokens['access_token']
        refresh_token = tokens['refresh_token']
        
        # Fetch Reddit profile
        profile_response = await client.get(
            "https://oauth.reddit.com/api/v1/me",
            headers={
                "Authorization": f"Bearer {access_token}",
                "User-Agent": "mentions/1.0"
            }
        )
        
        profile = profile_response.json()
        
        # Encrypt refresh token
        encrypted_refresh = encrypt(refresh_token)
        
        # Save to database
        await db.execute(
            """
            insert into reddit_connections (
                company_id, user_id, company_reddit_app_id, reddit_username,
                refresh_token_ciphertext, karma_total, karma_comment,
                account_created_at, is_active
            ) values (%s, %s, %s, %s, %s, %s, %s, to_timestamp(%s), true)
            on conflict (user_id, company_id) do update set
                refresh_token_ciphertext = excluded.refresh_token_ciphertext,
                reddit_username = excluded.reddit_username,
                karma_total = excluded.karma_total,
                karma_comment = excluded.karma_comment,
                is_active = true,
                updated_at = now()
            """,
            user.company_id,
            user.id,
            app_config['id'],
            profile['name'],
            encrypted_refresh,
            profile['total_karma'],
            profile['comment_karma'],
            profile['created_utc']
        )
    
    return {"success": True, "reddit_username": profile['name']}
```

**Frontend** (`/settings/reddit-account`):
- [ ] "Connect Reddit Account" button
- [ ] Shows current connection status
- [ ] Displays username, karma, account age
- [ ] "Disconnect" option

---

### 1.7 User Profile UI

**Page**: `/profile`

**Features**:
- [ ] Display user email (from Supabase auth)
- [ ] Display company name
- [ ] Display role (owner/admin/member)
- [ ] Show Reddit connection:
  - Username
  - Total karma
  - Comment karma
  - Account age
  - "Connected" badge
- [ ] Link to connect/disconnect Reddit

---

### 1.8 Testing

**Backend Tests** (`tests/test_m1.py`):
```python
import pytest
from httpx import AsyncClient
from main import app

@pytest.mark.asyncio
async def test_health_check():
    async with AsyncClient(app=app, base_url="http://test") as client:
        response = await client.get("/health")
        assert response.status_code == 200
        assert response.json()['status'] == 'ok'

@pytest.mark.asyncio
async def test_kms_encrypt_decrypt():
    from core.kms import encrypt, decrypt
    plaintext = "test_secret_123"
    ciphertext = encrypt(plaintext)
    decrypted = decrypt(ciphertext)
    assert decrypted == plaintext
    assert ciphertext != plaintext

# Add more tests...
```

**Manual Testing**:
- [ ] Sign up new user
- [ ] Log in with user
- [ ] Reset password
- [ ] Configure Reddit app (as owner)
- [ ] Connect Reddit account (OAuth flow)
- [ ] View profile with Reddit connection info
- [ ] Verify secrets are encrypted in database

---

## Deployment

### Backend to Cloud Run
```bash
cd mentions_backend
gcloud builds submit --tag gcr.io/mentions-dev/backend:m1
gcloud run deploy mentions-backend \
  --image gcr.io/mentions-dev/backend:m1 \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars ENV=dev,ALLOW_POSTS=false \
  --set-secrets OPENAI_API_KEY=openai-api-key:latest \
  --max-instances 5
```

### Frontend to Vercel
- Push to GitHub
- Vercel auto-deploys
- Set environment variables in Vercel dashboard

---

## Success Metrics

- [ ] 100% of core tables created
- [ ] All migrations run without errors
- [ ] KMS encryption/decryption works
- [ ] Users can complete signup/login flow
- [ ] Reddit OAuth flow completes end-to-end
- [ ] Reddit profile data displayed correctly
- [ ] All tests pass

---

## Next Steps
Proceed to **M2-GENERATION-FLOW.md** to implement the LangGraph pipeline for draft generation.

