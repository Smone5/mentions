# Hard Rules - Non-Negotiable Constraints

⚠️ **CRITICAL**: These rules are ABSOLUTE. No exceptions. No "unless". No workarounds.

Violating these rules could result in:
- Reddit account bans
- Subreddit bans
- Shadow banning
- Platform-wide suspensions
- Legal issues
- Loss of user trust

---

## Rule 1: Human Approval Required

**RULE**: Every single post to Reddit MUST be approved by a human before posting.

**Implementation**:
```python
# ✅ CORRECT
def post_to_reddit(draft_id: str, user_id: str):
    draft = get_draft(draft_id)
    
    # MUST check approval status
    if draft.status != "approved":
        raise Exception("Cannot post unapproved draft")
    
    # MUST check approval was by a real user
    if not draft.approved_by:
        raise Exception("No approver found")
    
    # MUST check approval is recent (not stale)
    if (now() - draft.approved_at) > timedelta(hours=24):
        raise Exception("Approval expired")
    
    # Now safe to post
    return reddit_client.post(draft)

# ❌ WRONG - Never do this
def post_to_reddit(draft_id: str):
    draft = get_draft(draft_id)
    return reddit_client.post(draft)  # NO APPROVAL CHECK!
```

**Environment Gate**:
```python
# Must be explicit in environment
ALLOW_POSTS = os.getenv("ALLOW_POSTS", "false").lower() == "true"

if ALLOW_POSTS and ENV != "prod":
    raise Exception("ALLOW_POSTS=true only allowed in production")
```

**Enforcement**:
- Database constraint: `approved_by` must be NOT NULL before status can be "posted"
- API endpoint requires approval token
- Rate limit: max 1 post per draft (prevent accidental double-posts)

---

## Rule 2: No Links in Replies

**RULE**: Reddit replies MUST NOT contain ANY links, URLs, or domain references.

**Why**: Reddit's spam detection aggressively flags promotional links. Even helpful links can trigger shadow bans.

**Forbidden Patterns**:
```python
# ❌ All of these are FORBIDDEN
"Visit example.com"
"Check out https://example.com"
"Go to www.example.com"
"example.com"
"example dot com"
"DM me for a link"
"Link in bio"
"See my profile for more"
"[Click here](https://example.com)"
```

**Implementation**:
```python
import re

LINK_PATTERNS = [
    r'https?://[^\s]+',           # http://example.com
    r'www\.[^\s]+',                # www.example.com
    r'\w+\.(com|net|org|io)',      # example.com
    r'\w+\s+dot\s+\w+',            # example dot com
    r'link\s+in\s+(bio|profile)',  # link in bio
    r'dm\s+me\s+for',              # DM me for
]

def validate_no_links(text: str) -> tuple[bool, str]:
    """Check if text contains any link patterns."""
    text_lower = text.lower()
    
    for pattern in LINK_PATTERNS:
        if re.search(pattern, text_lower):
            return False, f"Found forbidden link pattern: {pattern}"
    
    return True, "OK"

# MUST be called before draft is marked ready
def judge_draft(draft: str) -> bool:
    is_valid, reason = validate_no_links(draft)
    if not is_valid:
        return False
    # ... other checks
    return True
```

**LLM System Prompt**:
```
CRITICAL INSTRUCTION: You MUST NOT include ANY links, URLs, or website references 
in your reply. This includes:
- Direct URLs (http://, https://)
- Domain names (example.com, www.example.com)
- Indirect references ("link in bio", "DM me")
- Obfuscated links ("example dot com")

If you cannot answer without a link, provide helpful information instead.
```

**Judge LLM Verification**:
```python
# Additional LLM-based check
judge_prompt = f"""
Does this text contain ANY links, URLs, or domain references?
Text: {draft}

Answer ONLY "YES" or "NO".
"""

response = llm.generate(judge_prompt, temperature=0.0)
if response.strip().upper() == "YES":
    return False  # Reject draft
```

---

## Rule 3: LLM Judges Are Gates, Not Suggestions

**RULE**: LLM judge rejections are HARD STOPS. The pipeline cannot continue if a judge rejects.

**Judges**:
1. **JudgeSubreddit**: Determines if subreddit is appropriate
2. **JudgeDraft**: Determines if draft is high quality and safe

**Implementation**:
```python
# ✅ CORRECT
def judge_subreddit(subreddit: str, keyword: str) -> JudgeResult:
    result = llm_judge_subreddit(subreddit, keyword)
    
    if result.verdict == "reject":
        # HARD STOP - do not proceed
        raise SubredditRejected(result.reason)
    
    return result  # Only continues if "approve"

# ❌ WRONG - Never ignore judge verdict
def judge_subreddit(subreddit: str, keyword: str) -> JudgeResult:
    result = llm_judge_subreddit(subreddit, keyword)
    
    # ❌ This bypasses the gate!
    if result.confidence < 0.5:
        return JudgeResult(verdict="approve", reason="Low confidence, allowing anyway")
    
    return result
```

**LangGraph Integration**:
```python
def judge_subreddit_node(state: GenerateState) -> GenerateState:
    """Judge node that stops pipeline on rejection."""
    subreddit = state["subreddit"]
    keyword = state["keyword"]
    
    result = llm_judge_subreddit(subreddit, keyword)
    
    if result.verdict == "reject":
        # Set error to stop pipeline
        state["error"] = f"Subreddit rejected: {result.reason}"
        state["subreddit_approved"] = False
        return state  # LangGraph will route to END
    
    state["subreddit_approved"] = True
    state["judge_reason"] = result.reason
    return state

# Conditional edge enforces the gate
graph.add_conditional_edges(
    "judge_subreddit",
    lambda state: "end" if state.get("error") else "continue",
    {"continue": "fetch_rules", "end": END}
)
```

**Judge Temperatures**:
```python
# Low temperature for consistency
JUDGE_TEMPERATURE = 0.2  # Very deterministic
DRAFT_TEMPERATURE = 0.6   # More creative
PARAPHRASE_TEMPERATURE = 0.7  # Even more varied
```

---

## Rule 4: One Reddit App Per Company

**RULE**: Each company MUST have their own Reddit app credentials. Never share credentials across companies.

**Why**:
- Rate limiting is per app
- Ban risk is per app
- Company data isolation
- Compliance and audit trails

**Implementation**:
```python
# ✅ CORRECT
async def get_reddit_client(company_id: str, reddit_account_id: str):
    # Get company-specific Reddit app
    app = await get_reddit_app(company_id)
    
    if not app:
        raise Exception(f"No Reddit app configured for company {company_id}")
    
    # Get user-specific tokens
    account = await get_reddit_account(reddit_account_id, company_id)
    
    # Each client is isolated
    return RedditClient(
        client_id=app.client_id,
        client_secret=decrypt_kms(app.client_secret_encrypted),
        refresh_token=decrypt_kms(account.refresh_token_encrypted)
    )

# ❌ WRONG - Global shared client
GLOBAL_REDDIT_CLIENT = RedditClient(
    client_id=os.getenv("REDDIT_CLIENT_ID"),  # Shared across companies!
    client_secret=os.getenv("REDDIT_SECRET")
)
```

**Database Schema**:
```sql
create table reddit_apps (
  id uuid primary key,
  company_id uuid not null references companies(id) on delete cascade,
  client_id text not null,
  client_secret_encrypted text not null,  -- Encrypted with KMS
  created_at timestamptz default now(),
  
  -- ENFORCE: One app per company
  unique(company_id)
);

create table reddit_accounts (
  id uuid primary key,
  company_id uuid not null references companies(id),
  user_id uuid not null references auth.users(id),
  reddit_username text not null,
  refresh_token_encrypted text not null,  -- Encrypted with KMS
  
  -- ENFORCE: Account belongs to company
  foreign key (company_id) references companies(id) on delete cascade
);
```

---

## Rule 5: Encrypted Credentials Only

**RULE**: Reddit credentials (tokens, secrets) MUST be encrypted at rest using GCP KMS.

**Never Store Plain Text**:
```python
# ❌ WRONG - Plain text storage
INSERT INTO reddit_accounts (refresh_token) VALUES ('abc123');

# ✅ CORRECT - Encrypted storage
encrypted_token = kms_encrypt(refresh_token)
INSERT INTO reddit_accounts (refresh_token_encrypted) VALUES (encrypted_token);
```

**KMS Encryption**:
```python
from google.cloud import kms

def encrypt_token(plaintext: str) -> str:
    """Encrypt with GCP KMS."""
    kms_client = kms.KeyManagementServiceClient()
    
    key_name = kms_client.crypto_key_path(
        project=settings.GOOGLE_PROJECT_ID,
        location=settings.GOOGLE_LOCATION,
        key_ring=settings.KMS_KEYRING,
        crypto_key=settings.KMS_KEY
    )
    
    response = kms_client.encrypt(
        request={"name": key_name, "plaintext": plaintext.encode()}
    )
    
    return base64.b64encode(response.ciphertext).decode()

def decrypt_token(ciphertext: str) -> str:
    """Decrypt with GCP KMS."""
    kms_client = kms.KeyManagementServiceClient()
    
    key_name = kms_client.crypto_key_path(
        project=settings.GOOGLE_PROJECT_ID,
        location=settings.GOOGLE_LOCATION,
        key_ring=settings.KMS_KEYRING,
        crypto_key=settings.KMS_KEY
    )
    
    response = kms_client.decrypt(
        request={"name": key_name, "ciphertext": base64.b64decode(ciphertext)}
    )
    
    return response.plaintext.decode()
```

**Never Log Credentials**:
```python
# ❌ WRONG
logger.info(f"Using token: {refresh_token}")

# ✅ CORRECT
logger.info(f"Using token: {refresh_token[:8]}...")  # Only log prefix
```

---

## Rule 6: Rate Limiting Must Be Enforced

**RULE**: Respect Reddit's rate limits and implement our own volume controls.

**Reddit API Limits**:
- 60 requests per minute per OAuth client
- 1 post per 10 minutes per account (comment rate limit)
- Bursts trigger spam detection

**Our Volume Controls**:
```python
# Maximum posts per account per day
MAX_POSTS_PER_ACCOUNT_PER_DAY = 10

# Maximum posts per subreddit per account per week
MAX_POSTS_PER_SUBREDDIT_PER_ACCOUNT_PER_WEEK = 3

# Minimum time between posts for same account
MIN_MINUTES_BETWEEN_POSTS = 15

# Maximum posts across all accounts per company per day
MAX_POSTS_PER_COMPANY_PER_DAY = 50
```

**Eligibility Check**:
```python
async def check_post_eligibility(
    company_id: str,
    reddit_account_id: str,
    subreddit: str
) -> tuple[bool, str]:
    """Check if account is eligible to post."""
    
    # Check account daily limit
    posts_today = await count_posts_today(reddit_account_id)
    if posts_today >= MAX_POSTS_PER_ACCOUNT_PER_DAY:
        return False, "Account daily limit reached"
    
    # Check subreddit weekly limit
    posts_this_week = await count_posts_this_week(reddit_account_id, subreddit)
    if posts_this_week >= MAX_POSTS_PER_SUBREDDIT_PER_ACCOUNT_PER_WEEK:
        return False, "Subreddit weekly limit reached"
    
    # Check time since last post
    last_post = await get_last_post(reddit_account_id)
    if last_post:
        minutes_since = (now() - last_post.created_at).total_seconds() / 60
        if minutes_since < MIN_MINUTES_BETWEEN_POSTS:
            return False, f"Must wait {MIN_MINUTES_BETWEEN_POSTS - minutes_since:.0f} more minutes"
    
    # Check company daily limit
    company_posts_today = await count_company_posts_today(company_id)
    if company_posts_today >= MAX_POSTS_PER_COMPANY_PER_DAY:
        return False, "Company daily limit reached"
    
    return True, "Eligible"
```

**Cloud Tasks Queue**:
```python
# Use Cloud Tasks to enforce rate limiting
async def enqueue_post(draft_id: str):
    """Enqueue post with rate limiting."""
    task_client = tasks_v2.CloudTasksClient()
    
    # Get account's queue (one queue per account for rate limiting)
    queue_path = f"projects/{PROJECT_ID}/locations/{LOCATION}/queues/reddit-posts-{account_id}"
    
    # Schedule task with delay based on last post
    last_post_time = await get_last_post_time(account_id)
    delay_seconds = max(0, MIN_MINUTES_BETWEEN_POSTS * 60 - (now() - last_post_time))
    
    task = {
        "http_request": {
            "http_method": tasks_v2.HttpMethod.POST,
            "url": f"{API_URL}/internal/post/{draft_id}",
        },
        "schedule_time": datetime.now() + timedelta(seconds=delay_seconds)
    }
    
    return task_client.create_task(parent=queue_path, task=task)
```

---

## Rule 7: Row Level Security (RLS) Required

**RULE**: All database tables MUST have Row Level Security policies enforcing company isolation.

**Schema Example**:
```sql
-- Enable RLS on all tenant tables
alter table drafts enable row level security;
alter table posts enable row level security;
alter table reddit_accounts enable row level security;

-- Policy: Users can only see their company's data
create policy "Users see own company data"
  on drafts
  for select
  using (
    company_id = (select company_id from auth.users where id = auth.uid())
  );

create policy "Users modify own company data"
  on drafts
  for update
  using (
    company_id = (select company_id from auth.users where id = auth.uid())
  );
```

**Never Bypass RLS**:
```python
# ❌ WRONG - Service role bypasses RLS
supabase = create_client(url, service_role_key)
drafts = supabase.table("drafts").select("*").execute()  # Returns ALL companies!

# ✅ CORRECT - Use authenticated client
supabase = create_client(url, anon_key)
supabase.auth.set_session(user_jwt)
drafts = supabase.table("drafts").select("*").execute()  # Only user's company
```

---

## Rule 8: Verify Post Visibility

**RULE**: After posting, MUST verify the post is visible and not shadow-banned.

**Implementation**:
```python
async def verify_post_visible(post_id: str, reddit_post_id: str):
    """Verify post is visible on Reddit."""
    
    # Wait for Reddit to process
    await asyncio.sleep(30)
    
    # Fetch post as unauthenticated user (how others see it)
    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"https://www.reddit.com/comments/{reddit_post_id}.json",
            headers={"User-Agent": "Mozilla/5.0"}
        )
    
    if response.status_code == 404:
        # Post was removed or shadow-banned
        await mark_post_removed(post_id)
        await notify_user(post_id, "Post appears to be removed")
        return False
    
    data = response.json()
    comment = data[1]["data"]["children"][0]["data"]
    
    # Check for removal indicators
    if comment.get("removed"):
        await mark_post_removed(post_id)
        return False
    
    if comment.get("spam"):
        await mark_post_spam(post_id)
        return False
    
    # Post is visible!
    await mark_post_verified(post_id)
    return True

# Schedule verification task
await schedule_verification_task(post_id, delay_seconds=60)
```

---

## Rule 9: Multi-Tenant Data Isolation

**RULE**: Company data MUST be completely isolated. No data leakage between companies.

**Enforcement**:
```python
# ✅ CORRECT - Always filter by company_id
async def get_drafts(company_id: str, user_id: str):
    # Verify user belongs to company
    user = await get_user(user_id)
    if user.company_id != company_id:
        raise PermissionError("User not in company")
    
    # Query with company filter via artifacts table
    return await db.execute(
        """
        SELECT d.* FROM drafts d
        JOIN artifacts a ON d.artifact_id = a.id
        WHERE a.company_id = $1
        """,
        company_id
    )

# ❌ WRONG - No company filter
async def get_drafts(user_id: str):
    return await db.execute("SELECT * FROM drafts")  # Returns ALL companies!
```

**API Middleware**:
```python
async def enforce_company_context(request: Request, call_next):
    """Middleware to inject and verify company context."""
    user = request.state.user
    
    # All requests must have company context
    if not user.company_id:
        raise HTTPException(status_code=403, detail="No company context")
    
    # Inject into request state
    request.state.company_id = user.company_id
    
    response = await call_next(request)
    return response
```

---

## Rule 10: No Posting in dev/staging

**RULE**: Actual Reddit posting MUST be disabled in dev and staging environments.

**Environment Check**:
```python
def post_to_reddit(draft: Draft):
    """Post to Reddit - production only."""
    
    # HARD CHECK
    if settings.ENV != "prod":
        raise Exception(f"Posting disabled in {settings.ENV} environment")
    
    if not settings.ALLOW_POSTS:
        raise Exception("ALLOW_POSTS=false")
    
    # Additional safety check
    if settings.ENV == "prod" and not settings.ALLOW_POSTS:
        logger.critical("Production environment but ALLOW_POSTS=false")
        raise Exception("Configuration error")
    
    # Now safe to post
    return reddit_client.post(draft.body)
```

**Mock in Non-Prod**:
```python
class RedditClient:
    def post(self, body: str, thread_id: str):
        if settings.ENV != "prod":
            # Mock the post in dev/staging
            logger.info(f"[MOCK POST] Would post: {body[:100]}...")
            return {
                "id": f"mock_{uuid.uuid4().hex[:8]}",
                "permalink": f"/r/test/comments/mock/test",
                "created_utc": datetime.now().timestamp()
            }
        
        # Real post in production
        return self._real_post(body, thread_id)
```

---

## Enforcement Checklist

Before deploying ANY code that touches posting:

- [ ] Human approval check implemented and tested
- [ ] Link detection regex tested with 100+ examples
- [ ] LLM judge gates enforce hard stops (not warnings)
- [ ] Company credentials are isolated (no shared credentials)
- [ ] All credentials encrypted with KMS (no plain text)
- [ ] Rate limiting enforced at API and queue level
- [ ] RLS policies on all tenant tables
- [ ] Post verification task scheduled after posting
- [ ] Multi-tenant isolation tested (can't see other company data)
- [ ] Posting disabled in dev/staging (ALLOW_POSTS=false)

---

## Violations and Consequences

| Violation | Consequence | Recovery |
|-----------|-------------|----------|
| Post without approval | Immediate rollback, alert, code review | Add approval gate, deploy fix |
| Link in reply | Reddit shadow-ban, account suspension | Manual appeal, change draft process |
| Bypass LLM judge | Poor quality posts, spam flags | Re-implement gate, retrain model |
| Shared credentials | Rate limit issues, ban affects multiple companies | Separate apps, rotate credentials |
| Plain text credentials | Security breach, credential theft | Rotate all credentials, enable KMS |
| Ignore rate limits | Account ban, IP ban | Manual Reddit appeal, backoff |
| No RLS | Data leakage, compliance violation | Immediate fix, audit all data access |
| Skip verification | Shadow-banned posts go unnoticed | Implement verification, monitor metrics |
| Data leakage | Loss of trust, legal issues | Data isolation audit, notify affected parties |
| Post in staging | Accidental spam, account ban | Environment checks, CI/CD gates |

---

## Testing Hard Rules

All hard rules MUST have automated tests:

```python
# Test: Cannot post without approval
def test_post_requires_approval():
    draft = create_draft(status="pending")
    
    with pytest.raises(Exception, match="unapproved"):
        post_to_reddit(draft.id, user.id)

# Test: Link detection works
def test_link_detection():
    tests = [
        ("Check out https://example.com", False),
        ("Visit example.com", False),
        ("This is helpful advice", True),
    ]
    
    for text, should_pass in tests:
        is_valid, _ = validate_no_links(text)
        assert is_valid == should_pass

# Test: Company isolation
def test_company_isolation():
    company_a_user = create_user(company_id="company_a")
    company_b_draft = create_draft(company_id="company_b")
    
    # Company A user should NOT see Company B draft
    drafts = get_drafts(company_a_user.company_id, company_a_user.id)
    assert company_b_draft.id not in [d.id for d in drafts]
```

---

## Final Word

These rules exist because Reddit is **very good** at detecting and punishing spam. A single violation can result in permanent account or IP bans.

**When in doubt, be more conservative.**

If you're unsure whether something violates a rule, **it probably does**. Ask before implementing.

Remember: We're building a tool to help companies participate **authentically** in conversations, not to spam Reddit.

