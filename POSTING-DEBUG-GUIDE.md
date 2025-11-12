# Reddit Posting Debug & Configuration Guide

## 🔍 Issue Diagnosis

Your comments are **NOT actually being posted to Reddit** because the system is in **MOCK MODE**.

### Why Comments Aren't Showing on Reddit

The system has a safety mechanism (Hard Rule #10) that prevents accidental posting to Reddit during development:

1. **Environment Check**: If `ENV != "prod"`, all posts are mocked
2. **Safety Flag Check**: If `ALLOW_POSTS != true`, all posts are mocked

### Current Configuration

Based on your logs and code:
- **ENV**: `dev` (default)
- **ALLOW_POSTS**: `false` (default)

**Result**: All "posts" are mocked - they create database records but DON'T actually post to Reddit.

---

## ✅ How to Enable Real Posting

### Option 1: Testing in Development (⚠️ Use with Caution)

If you want to test real posting in your dev environment:

1. **Set environment variables**:
   ```bash
   export ENV=prod
   export ALLOW_POSTS=true
   ```

2. **Or add to your `.env` file**:
   ```bash
   ENV=prod
   ALLOW_POSTS=true
   ```

3. **Restart your backend server**

4. **Watch the logs** - you'll now see:
   ```
   ✅ REAL POST STARTING - Posting to Reddit thread xxx
   ✅ COMMENT POSTED SUCCESSFULLY!
      Comment ID: abc123
      Permalink: https://reddit.com/r/subreddit/comments/...
   ```

**⚠️ WARNING**: This will post REAL comments to REAL Reddit threads. Use a test subreddit or your own subreddit for testing!

### Option 2: Production Deployment

For Cloud Run production deployment:

```bash
gcloud run deploy mentions-backend \
  --image gcr.io/mention001/backend:latest \
  --region us-central1 \
  --set-env-vars ENV=prod,ALLOW_POSTS=true \
  # ... other env vars
```

---

## 🔍 How to Check If Posting is Enabled

### Method 1: Check Logs

When you try to post, look for these log messages:

**Mock Mode (Not posting)**:
```
⚠️  [MOCK POST] Not posting to Reddit - ENV=dev (must be 'prod')
   To enable real posting: Set ENV=prod and ALLOW_POSTS=true
```

**Real Posting**:
```
🎯 POST COMMENT CALLED - ENV=prod, ALLOW_POSTS=True
✅ REAL POST STARTING - Posting to Reddit thread xxx
```

### Method 2: Check Health Endpoint

```bash
curl http://localhost:8000/api/health
```

Response shows:
```json
{
  "status": "ok",
  "env": "dev",
  "allow_posts": false
}
```

### Method 3: Check Database

After "posting", check the `posts` table:

```sql
SELECT comment_reddit_id, permalink FROM posts ORDER BY posted_at DESC LIMIT 1;
```

**Mock post**:
- `comment_reddit_id`: `mock_xxx` (starts with "mock_")
- `permalink`: `/r/test/comments/...` (fake permalink)

**Real post**:
- `comment_reddit_id`: Real Reddit ID like `abc123`
- `permalink`: Real Reddit permalink

---

## 📋 New Debugging Features

We've added comprehensive logging to help you diagnose posting issues:

### 1. Post Workflow Start
```
================================================================================
🚀 STARTING POST TO REDDIT WORKFLOW
   Draft ID: xxx
   Approved by: xxx
   Environment: dev
   ALLOW_POSTS: False
================================================================================
```

### 2. Hard Rules Checks
```
✅ HARD RULE #1: Checking human approval...
   Draft approved by: xxx

✅ HARD RULE #10: Checking environment...
⚠️  MOCK POST MODE
   ENV=dev
   ALLOW_POSTS=False
   This draft will NOT be posted to Reddit
   To enable real posting: Set ENV=prod and ALLOW_POSTS=true
```

### 3. Reddit API Call
```
🎯 POST COMMENT CALLED - ENV=prod, ALLOW_POSTS=True
   Thread: abc123
   Body length: 234 chars
   Body preview: Here's my comment...

✅ REAL POST STARTING - Posting to Reddit thread abc123
   Fetched submission: r/test
   Calling submission.reply()...
```

### 4. Success/Failure
```
✅ COMMENT POSTED SUCCESSFULLY!
   Comment ID: abc123
   Permalink: https://reddit.com/r/test/comments/abc123/...
   Created: 2025-11-10 18:30:00
   Subreddit: r/test
```

Or if there's an error:
```
❌ FAILED TO POST COMMENT
   Thread: abc123
   Error type: RedditAPIException
   Error: RATELIMIT - you are doing that too much
   Traceback: ...
```

---

## ☁️ Google Cloud Platform Usage

### Yes, you ARE using GCP for scalability!

Your logs show active GCP usage:

#### 1. **Cloud KMS (Key Management Service)** ✅ ACTIVE
From your logs:
```
2025-11-07 18:01:13,268 - core.kms - INFO - Successfully decrypted data using KMS key: 
projects/mention001/locations/us-central1/keyRings/reddit-secrets/cryptoKeys/reddit-token-key
```

**Purpose**: 
- Encrypts/decrypts Reddit app client secrets
- Encrypts/decrypts user OAuth refresh tokens
- Ensures secure storage of credentials

**Location**: `projects/mention001/locations/us-central1`

#### 2. **OAuth2 Authentication** ✅ ACTIVE
```
2025-11-07 18:01:12,815 - urllib3.connectionpool - DEBUG - Starting new HTTPS connection (1): oauth2.googleapis.com:443
```

**Purpose**: Service account authentication for GCP services

#### 3. **Infrastructure Ready (Terraform)**

Your repository includes Terraform modules for:

**Cloud Run**:
- Serverless container hosting for FastAPI backend
- Auto-scaling (0-100+ instances)
- Pay-per-use pricing

**Cloud Tasks**:
- Reliable task queues for posting
- Per-company queues: `reddit-posts-{company_id}`
- Retry logic with exponential backoff

**Cloud Scheduler**:
- Cron-based triggers for scheduled jobs
- Nightly learning/summarization
- Triggers Cloud Run endpoints

**Secret Manager**:
- Store API keys (OpenAI, Supabase)
- Separate secrets per environment

**Artifact Registry**:
- Store Docker images for Cloud Run

### Current Setup

**Project ID**: `mention001`
**Region**: `us-central1`
**KMS Keyring**: `reddit-secrets`
**KMS Key**: `reddit-token-key`

### Scalability Architecture

```
User → Next.js (Vercel/Cloud Run)
         ↓
    FastAPI Backend (Cloud Run)
         ↓
    ├─→ Supabase (Postgres + pgvector)
    ├─→ Reddit API (OAuth)
    ├─→ OpenAI API (GPT-5)
    ├─→ Cloud KMS (encrypt/decrypt)
    ├─→ Cloud Tasks (queues) [not yet deployed]
    └─→ Cloud Scheduler (cron) [not yet deployed]
```

**Auto-scaling**: Cloud Run scales from 0 to 100+ instances based on load
**Database**: Supabase Postgres handles millions of rows with pgvector
**Rate Limiting**: Per-company, per-account, per-subreddit tracking
**Security**: KMS encryption, RLS policies, multi-tenant isolation

---

## 🚀 Quick Test: Verify Real Posting

### 1. Create a Test Subreddit

Create your own subreddit for testing:
- Go to https://reddit.com/subreddits/create
- Create a private test subreddit (e.g., `r/mytest123`)

### 2. Enable Real Posting

```bash
# In your terminal where you run the backend
export ENV=prod
export ALLOW_POSTS=true

# Restart backend
python mentions_backend/main.py
```

### 3. Generate and Post a Comment

Use your frontend or API to:
1. Trigger discovery workflow
2. Approve a draft
3. Post the draft

### 4. Check Logs

Look for:
```
🎯 POST COMMENT CALLED - ENV=prod, ALLOW_POSTS=True
✅ COMMENT POSTED SUCCESSFULLY!
   Permalink: https://reddit.com/r/mytest123/comments/...
```

### 5. Verify on Reddit

Open the permalink in your browser - you should see your comment!

---

## 🐛 Common Issues

### Issue: "error with request" in logs

**Symptoms**:
```
reddit.client - ERROR - Failed to search subreddits: error with request
```

**Causes**:
1. Reddit API rate limit exceeded
2. Invalid OAuth token
3. Reddit app not properly configured

**Solutions**:
1. Wait 60 seconds and try again
2. Check Reddit app credentials in database
3. Re-authenticate Reddit account

### Issue: Comment posted but not visible

**Symptoms**: Comment ID returned, but comment not visible on Reddit

**Causes**:
1. **Spam filter** - Reddit's spam filter caught it
2. **Shadow ban** - Account is shadow banned
3. **AutoModerator** - Subreddit rules auto-removed it
4. **Karma requirement** - Account doesn't have enough karma

**Solutions**:
1. Check comment with different account
2. Check your Reddit account status
3. Review subreddit rules and AutoModerator config
4. Build account karma before posting

### Issue: Posts always mocked even with ENV=prod

**Cause**: Environment variable not loaded

**Solutions**:
1. Check `.env` file exists
2. Restart backend after changing env vars
3. Verify with health endpoint: `curl http://localhost:8000/api/health`

---

## 📊 Monitoring Real Posts

### Check Post Status

```sql
SELECT 
  p.id,
  p.comment_reddit_id,
  p.permalink,
  p.posted_at,
  p.verified,
  d.body
FROM posts p
JOIN drafts d ON d.id = p.draft_id
ORDER BY p.posted_at DESC
LIMIT 10;
```

**Mock posts**: `comment_reddit_id` starts with `mock_`
**Real posts**: `comment_reddit_id` is a Reddit ID

### Verify Comment on Reddit

Use the verification function:

```python
from reddit.client import get_reddit_client_for_account

client = await get_reddit_client_for_account(company_id, account_id)
is_visible = await client.check_comment_visible(comment_id)
```

---

## 🎯 Summary

1. **Your posts are currently MOCKED** because `ENV=dev` and `ALLOW_POSTS=false`
2. **To enable real posting**: Set `ENV=prod` and `ALLOW_POSTS=true`
3. **You ARE using GCP**: Cloud KMS is actively encrypting/decrypting credentials
4. **Full GCP infrastructure ready**: Cloud Run, Tasks, Scheduler modules in Terraform
5. **New debugging added**: Comprehensive logs now show exactly what's happening

**Next Steps**:
1. Try posting with new debug logs to see exact behavior
2. When ready for real posting, set `ENV=prod` and `ALLOW_POSTS=true`
3. Test on your own private subreddit first
4. Deploy full GCP infrastructure with Terraform when ready for production scale

