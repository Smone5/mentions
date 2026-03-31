# Milestone 5: Production Ready

**Duration**: Weeks 9-10 (2 weeks)  
**Prerequisites**: M1, M2, M3, M4 complete

---

## Overview

Prepare the system for production deployment with comprehensive testing, monitoring, and multi-environment setup.

**Goals**:
- Comprehensive test coverage (>80%)
- Staging environment mirrors production
- CI/CD pipeline deploys automatically
- Monitoring and alerts configured
- Row Level Security (RLS) fully tested
- Production deployment successful
- Documentation complete

---

## Task Breakdown

### Task 5.1: Comprehensive Testing
**Time**: 16 hours  
**Priority**: Critical

#### Unit Tests

**Backend Tests** (`tests/unit/`):
```python
# tests/unit/test_rate_limiter.py
import pytest
from services.rate_limiter import check_post_eligibility

@pytest.mark.asyncio
async def test_account_daily_limit():
    """Test account daily posting limit."""
    company_id = "test-company"
    account_id = "test-account"
    subreddit = "test"
    
    # Create 10 posts today
    for i in range(10):
        await create_test_post(account_id)
    
    # Should be over limit
    is_eligible, reason = await check_post_eligibility(company_id, account_id, subreddit)
    
    assert is_eligible == False
    assert "daily limit" in reason.lower()


@pytest.mark.asyncio
async def test_subreddit_weekly_limit():
    """Test subreddit weekly posting limit."""
    # Create 3 posts to same subreddit this week
    for i in range(3):
        await create_test_post(account_id, subreddit="test")
    
    # Should be over limit for this subreddit
    is_eligible, reason = await check_post_eligibility(company_id, account_id, "test")
    
    assert is_eligible == False
    assert "subreddit weekly limit" in reason.lower()


@pytest.mark.asyncio
async def test_minimum_time_between_posts():
    """Test minimum time gap between posts."""
    # Create post just now
    await create_test_post(account_id)
    
    # Should need to wait 15 minutes
    is_eligible, reason = await check_post_eligibility(company_id, account_id, "test")
    
    assert is_eligible == False
    assert "wait" in reason.lower()


# tests/unit/test_hard_rules.py
@pytest.mark.asyncio
async def test_no_links_validation():
    """Test link detection (Rule 2)."""
    from services.post import validate_no_links
    
    test_cases = [
        ("Check out https://example.com", False),
        ("Visit www.example.com", False),
        ("Go to example.com", False),
        ("example dot com", False),
        ("Link in bio", False),
        ("DM me for more", False),
        ("This is helpful advice without links", True),
    ]
    
    for text, should_pass in test_cases:
        is_valid, reason = validate_no_links(text)
        assert is_valid == should_pass, f"Failed for: {text}"


@pytest.mark.asyncio
async def test_approval_required():
    """Test approval required before posting (Rule 1)."""
    draft = await create_test_draft(status="pending")
    
    # Should raise exception for unapproved draft
    with pytest.raises(Exception, match="not approved"):
        await post_to_reddit(draft.id)
    
    # Approve draft
    await approve_draft(draft.id, user_id="test-user")
    
    # Should succeed now
    result = await post_to_reddit(draft.id)
    assert result["success"] == True


@pytest.mark.asyncio
async def test_environment_gate():
    """Test posting disabled in non-production (Rule 10)."""
    import os
    os.environ["ENV"] = "dev"
    os.environ["ALLOW_POSTS"] = "false"
    
    draft = await create_test_draft(status="approved", approved_by="test-user")
    
    # Should return mock in dev
    result = await post_to_reddit(draft.id)
    assert result.get("mock") == True


# tests/unit/test_company_isolation.py
@pytest.mark.asyncio
async def test_rls_company_isolation():
    """Test Row Level Security enforces company isolation (Rule 9)."""
    # Create two companies
    company_a = await create_test_company(name="Company A")
    company_b = await create_test_company(name="Company B")
    
    # Create user for company A
    user_a = await create_test_user(company_id=company_a.id)
    
    # Create draft for company B
    draft_b = await create_test_draft(company_id=company_b.id)
    
    # User A should NOT see company B's draft
    drafts = await get_drafts(company_a.id, user_a.id)
    draft_ids = [d.id for d in drafts]
    
    assert draft_b.id not in draft_ids, "RLS violation: User saw other company's draft"


@pytest.mark.asyncio
async def test_encrypted_credentials():
    """Test credentials are encrypted at rest (Rule 5)."""
    from reddit.encryption import encrypt_token, decrypt_token
    
    plaintext = "test_refresh_token_abc123"
    
    # Encrypt
    ciphertext = encrypt_token(plaintext)
    
    # Should not be plain text
    assert ciphertext != plaintext
    assert "abc123" not in ciphertext
    
    # Should decrypt correctly
    decrypted = decrypt_token(ciphertext)
    assert decrypted == plaintext
```

#### Integration Tests

**API Tests** (`tests/integration/`):
```python
# tests/integration/test_generation_flow.py
@pytest.mark.asyncio
async def test_full_generation_flow():
    """Test complete generation pipeline."""
    # Setup
    company = await create_test_company()
    user = await create_test_user(company_id=company.id)
    keyword = await create_test_keyword(company_id=company.id, keyword="test")
    
    # Trigger generation
    response = await client.post(
        "/api/generate",
        json={"keywords": ["test"], "reddit_account_id": account.id},
        headers={"Authorization": f"Bearer {user.token}"}
    )
    
    assert response.status_code == 200
    artifact_id = response.json()["artifact_id"]
    
    # Check draft was created
    drafts = await get_drafts(company.id, user.id)
    assert len(drafts) > 0
    
    # Check draft content
    draft = drafts[0]
    assert draft.artifact_id == artifact_id
    assert draft.status == "pending"
    assert len(draft.body) > 0


# tests/integration/test_approval_posting_flow.py
@pytest.mark.asyncio
async def test_approve_and_post_flow():
    """Test approval and posting flow."""
    # Create approved draft
    draft = await create_test_draft(status="pending")
    
    # Approve
    response = await client.post(
        f"/api/drafts/{draft.id}/approve",
        headers={"Authorization": f"Bearer {user.token}"}
    )
    
    assert response.status_code == 200
    
    # Check draft status
    updated_draft = await get_draft(draft.id)
    assert updated_draft.status == "approved"
    assert updated_draft.approved_by == user.id
    
    # Verify task was enqueued
    # (Check Cloud Tasks queue or mock)
```

#### E2E Tests

**Frontend Tests** (`tests/e2e/` using Playwright):
```typescript
// tests/e2e/inbox.spec.ts
import { test, expect } from '@playwright/test'

test.describe('Inbox', () => {
  test('user can view and filter drafts', async ({ page }) => {
    // Login
    await page.goto('/login')
    await page.fill('[name=email]', 'test@example.com')
    await page.fill('[name=password]', 'password')
    await page.click('button[type=submit]')
    
    // Navigate to inbox
    await page.goto('/inbox')
    
    // Should see drafts
    await expect(page.locator('[data-testid=draft-card]')).toHaveCount(3)
    
    // Filter by status
    await page.selectOption('[name=status]', 'pending')
    await page.waitForURL('**/inbox?status=pending')
    
    // Should only see pending drafts
    await expect(page.locator('[data-testid=draft-card]')).toHaveCount(2)
  })
  
  test('user can approve draft', async ({ page }) => {
    await login(page)
    await page.goto('/inbox')
    
    // Click first draft
    await page.click('[data-testid=draft-card]:first-child')
    
    // Should see draft detail
    await expect(page).toHaveURL(/\/drafts\/[a-f0-9-]+/)
    
    // Approve draft
    await page.click('[data-testid=approve-button]')
    
    // Should redirect to inbox
    await expect(page).toHaveURL('/inbox?status=approved')
    
    // Should see success message
    await expect(page.locator('text=Draft approved')).toBeVisible()
  })
})
```

**Test Coverage Requirements**:
- [ ] >80% code coverage
- [ ] All 10 hard rules tested
- [ ] Company isolation tested
- [ ] Rate limiting tested
- [ ] Generation flow tested
- [ ] Approval/posting flow tested

**Verification**:
- [ ] All tests pass
- [ ] Coverage report generated
- [ ] No flaky tests

---

### Task 5.2: Observability
**Time**: 6 hours  
**Priority**: High

#### Structured Logging (Already implemented in 24-LOGGING-DEBUGGING.md)

**Enhance with context**:
```python
# core/logging.py
import structlog
from contextvars import ContextVar

# Context variables for request tracking
request_id_var = ContextVar('request_id', default=None)
company_id_var = ContextVar('company_id', default=None)

def setup_logging():
    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.processors.add_log_level,
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.JSONRenderer() if settings.LOG_JSON else structlog.dev.ConsoleRenderer()
        ],
        wrapper_class=structlog.make_filtering_bound_logger(settings.LOG_LEVEL),
    )

# Middleware to inject context
@app.middleware("http")
async def logging_middleware(request: Request, call_next):
    request_id = str(uuid.uuid4())
    request_id_var.set(request_id)
    
    if hasattr(request.state, 'company_id'):
        company_id_var.set(request.state.company_id)
    
    structlog.contextvars.clear_contextvars()
    structlog.contextvars.bind_contextvars(
        request_id=request_id,
        company_id=request.state.company_id if hasattr(request.state, 'company_id') else None
    )
    
    response = await call_next(request)
    return response
```

#### Metrics Collection

**GCP Cloud Monitoring**:
```python
# services/metrics.py
from google.cloud import monitoring_v3
import time

metrics_client = monitoring_v3.MetricServiceClient()
project_name = f"projects/{settings.GOOGLE_PROJECT_ID}"

def record_draft_generated(company_id: str):
    """Record draft generation metric."""
    series = monitoring_v3.TimeSeries()
    series.metric.type = "custom.googleapis.com/mentions/drafts_generated"
    series.resource.type = "global"
    series.metric.labels["company_id"] = company_id
    
    point = monitoring_v3.Point()
    point.value.int64_value = 1
    point.interval.end_time.seconds = int(time.time())
    series.points = [point]
    
    metrics_client.create_time_series(name=project_name, time_series=[series])


def record_post_status(status: str, company_id: str):
    """Record post status metric."""
    series = monitoring_v3.TimeSeries()
    series.metric.type = "custom.googleapis.com/mentions/posts"
    series.resource.type = "global"
    series.metric.labels["status"] = status
    series.metric.labels["company_id"] = company_id
    
    point = monitoring_v3.Point()
    point.value.int64_value = 1
    point.interval.end_time.seconds = int(time.time())
    series.points = [point]
    
    metrics_client.create_time_series(name=project_name, time_series=[series])
```

#### Alerts

**Set up alerts in GCP**:
```yaml
# alerts/high-error-rate.yaml
displayName: "High Error Rate"
conditions:
  - displayName: "Error rate > 5%"
    conditionThreshold:
      filter: 'resource.type="cloud_run_revision" AND metric.type="run.googleapis.com/request_count" AND metric.label.response_code_class="5xx"'
      comparison: COMPARISON_GT
      thresholdValue: 0.05
      duration: 300s
notificationChannels:
  - projects/mentions-prod/notificationChannels/email-alerts
```

**Verification**:
- [ ] Logs include request_id and company_id
- [ ] Metrics recorded in GCP
- [ ] Alerts configured
- [ ] Can trace requests end-to-end

---

### Task 5.3: Staging Environment
**Time**: 4 hours  
**Priority**: Critical

**Terraform Apply for Staging**:
```bash
cd mentions_terraform/environments/staging

# Initialize
terraform init

# Plan
terraform plan -out=tfplan

# Review plan carefully

# Apply
terraform apply tfplan
```

**Deploy to Staging**:
```bash
# Backend
cd mentions_backend
gcloud builds submit --tag gcr.io/mentions-staging/backend:latest
gcloud run deploy mentions-backend \
  --image gcr.io/mentions-staging/backend:latest \
  --platform managed \
  --region us-central1 \
  --set-env-vars ENV=staging,ALLOW_POSTS=false

# Frontend
cd mentions_frontend
vercel deploy --target=staging
```

**Smoke Tests in Staging**:
```bash
# Health check
curl https://backend-staging-xxx.run.app/health

# Login flow
# Draft generation
# Approval flow
# Mock posting (ALLOW_POSTS=false)
```

**Verification**:
- [ ] Staging environment deployed
- [ ] All endpoints accessible
- [ ] Posting disabled (ALLOW_POSTS=false)
- [ ] Can test full flow without posting to Reddit

---

### Task 5.4: CI/CD Pipeline
**Time**: 6 hours  
**Priority**: High

**GitHub Actions Workflows**:

`.github/workflows/test.yml`:
```yaml
name: Test

on:
  pull_request:
    branches: [main]

jobs:
  backend-tests:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: pgvector/pgvector:pg16
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: |
          cd mentions_backend
          pip install -r requirements.txt
          pip install pytest pytest-asyncio pytest-cov
      
      - name: Run tests
        run: |
          cd mentions_backend
          pytest --cov=. --cov-report=xml
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./mentions_backend/coverage.xml
  
  frontend-tests:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Node
        uses: actions/setup-node@v3
        with:
          node-version: '18'
      
      - name: Install dependencies
        run: |
          cd mentions_frontend
          npm install
      
      - name: Type check
        run: |
          cd mentions_frontend
          npm run type-check
      
      - name: Lint
        run: |
          cd mentions_frontend
          npm run lint
```

`.github/workflows/deploy-production.yml`:
```yaml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  deploy-backend:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Authenticate to GCP
        uses: google-github-actions/auth@v1
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY_PROD }}
      
      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v1
      
      - name: Build and push
        run: |
          cd mentions_backend
          gcloud builds submit \
            --tag gcr.io/mentions-prod/backend:${{ github.sha }} \
            --tag gcr.io/mentions-prod/backend:latest
      
      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy mentions-backend \
            --image gcr.io/mentions-prod/backend:${{ github.sha }} \
            --region us-central1 \
            --platform managed \
            --set-env-vars ENV=prod,ALLOW_POSTS=true \
            --max-instances 50 \
            --min-instances 1
      
      - name: Run smoke tests
        run: |
          SERVICE_URL=$(gcloud run services describe mentions-backend \
            --region us-central1 \
            --format 'value(status.url)')
          curl -f $SERVICE_URL/health || exit 1
  
  deploy-frontend:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Deploy to Vercel
        uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          vercel-args: '--prod'
```

**Verification**:
- [ ] Tests run on every PR
- [ ] Deploys automatically on merge to main
- [ ] Smoke tests pass after deployment
- [ ] Can rollback if deployment fails

---

### Task 5.5: Production Deployment
**Time**: 4 hours  
**Priority**: Critical

**Pre-Deployment Checklist**:
- [ ] All tests passing
- [ ] Staging tested thoroughly
- [ ] Secrets configured in production
- [ ] RLS policies enabled
- [ ] Rate limits configured
- [ ] Monitoring/alerts set up
- [ ] Backup strategy in place

**Deploy Infrastructure**:
```bash
cd mentions_terraform/environments/prod
terraform init
terraform plan
# Review carefully!
terraform apply
```

**Deploy Application**:
```bash
# Backend
cd mentions_backend
gcloud builds submit --tag gcr.io/mentions-prod/backend:v1.0.0
gcloud run deploy mentions-backend \
  --image gcr.io/mentions-prod/backend:v1.0.0 \
  --region us-central1 \
  --set-env-vars ENV=prod,ALLOW_POSTS=true \
  --max-instances 50 \
  --min-instances 1

# Frontend
cd mentions_frontend
vercel deploy --prod
```

**Post-Deployment Verification**:
```bash
# Health check
curl https://api.mentions.ai/health

# Full flow test
# 1. Sign up
# 2. Connect Reddit account
# 3. Upload RAG docs
# 4. Trigger generation
# 5. Review drafts
# 6. Approve and post
# 7. Verify post appears on Reddit
```

**Monitor First 24 Hours**:
- [ ] Check error rates
- [ ] Monitor Reddit API usage
- [ ] Watch for rate limit issues
- [ ] Check post verification success rate
- [ ] Monitor for spam flags

**Verification**:
- [ ] Production deployed successfully
- [ ] All systems operational
- [ ] No errors in logs
- [ ] Users can complete full flow
- [ ] Posts appear on Reddit

---

## Success Criteria

By end of M5:
- ✅ >80% test coverage
- ✅ All hard rules tested
- ✅ Staging environment fully functional
- ✅ CI/CD pipeline deploys automatically
- ✅ Production deployed and stable
- ✅ Monitoring and alerts active
- ✅ Documentation complete
- ✅ First production posts successful

---

## Production Monitoring

### Key Metrics to Watch

1. **System Health**:
   - API response times (p50, p95, p99)
   - Error rates (<1%)
   - CPU/memory usage

2. **Business Metrics**:
   - Drafts generated per day
   - Approval rate (target: >80%)
   - Post success rate (target: >95%)
   - Posts removed/flagged (target: <5%)

3. **Rate Limits**:
   - Posts per account per day
   - Time between posts
   - Company daily limits

4. **Reddit API**:
   - API call volume
   - Rate limit headroom
   - OAuth token refresh success

### Alerts

Critical alerts (page on-call):
- Error rate >5%
- Post verification failure rate >20%
- Reddit API errors >10/hour
- Database connection failures

Warning alerts (email):
- Draft generation slowing (>2 min)
- Approval rate <70%
- Rate limit approaching (>90%)

---

## Rollback Plan

If issues in production:

1. **Quick Rollback**:
```bash
# Rollback to previous Cloud Run revision
gcloud run services update-traffic mentions-backend \
  --to-revisions mentions-backend-00042-abc=100 \
  --region us-central1
```

2. **Disable Posting**:
```bash
# Emergency disable posting
gcloud run services update mentions-backend \
  --set-env-vars ALLOW_POSTS=false \
  --region us-central1
```

3. **Database Rollback**:
```bash
# If schema issues, rollback migration
psql $DB_CONN -f db/migrations/rollback_xyz.sql
```

---

## Documentation Checklist

- [ ] README.md with quick start
- [ ] API documentation (Swagger/OpenAPI)
- [ ] Deployment guide
- [ ] Troubleshooting guide
- [ ] User guide for content reviewers
- [ ] Admin guide for company setup

---

## Go-Live Plan

**Day 0 (Pre-Launch)**:
- Final staging tests
- Team training
- Support channels ready

**Day 1 (Soft Launch)**:
- Deploy to production
- 1-2 pilot companies only
- Monitor closely

**Week 1**:
- Onboard 5-10 companies
- Gather feedback
- Fix any issues

**Week 2-4**:
- Open to all customers
- Scale monitoring
- Optimize based on usage

**Success = No major incidents, users happy, posts successful!** 🚀

---

## Congratulations!

If you've completed M1-M5, you have a **production-ready Reddit Reply Assistant** with:
- ✅ AI-powered draft generation
- ✅ Human review and approval
- ✅ Safe posting with verification
- ✅ Rate limiting and compliance
- ✅ Training data collection
- ✅ Company-specific customization
- ✅ Multi-tenant architecture
- ✅ Comprehensive testing
- ✅ Full observability

**Ship it!** 🚀






