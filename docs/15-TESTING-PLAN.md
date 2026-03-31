# Testing Plan

Complete testing strategy for comprehensive coverage.

**Goal**: >80% code coverage, all hard rules tested

---

## Test Types

### 1. Unit Tests

**Backend** (`tests/unit/`):
- Services (rate_limiter, post, rag)
- LLM clients
- Validators (no links, eligibility)
- Hard rules (see [22-HARD-RULES.md](./22-HARD-RULES.md))

**Example**:
```python
# tests/unit/test_hard_rules.py
@pytest.mark.asyncio
async def test_approval_required():
    """Test Rule 1: Human approval required."""
    draft = await create_test_draft(status="pending")
    
    with pytest.raises(Exception, match="not approved"):
        await post_to_reddit(draft.id)
    
    # Approve and retry
    await approve_draft(draft.id, user_id="test-user")
    result = await post_to_reddit(draft.id)
    assert result["success"] == True

@pytest.mark.asyncio
async def test_no_links_validation():
    """Test Rule 2: No links allowed."""
    test_cases = [
        ("Check out https://example.com", False),
        ("Visit www.example.com", False),
        ("Helpful advice without links", True),
    ]
    
    for text, should_pass in test_cases:
        is_valid, _ = validate_no_links(text)
        assert is_valid == should_pass
```

---

### 2. Integration Tests

**API Tests** (`tests/integration/`):
- Full endpoints with database
- Auth flow
- Draft approval → posting flow
- RAG upload → retrieval

**Example**:
```python
@pytest.mark.asyncio
async def test_draft_approval_flow():
    """Test complete draft approval and posting flow."""
    # Create draft
    draft = await create_test_draft()
    
    # Approve via API
    response = await client.post(
        f"/api/drafts/{draft.id}/approve",
        headers={"Authorization": f"Bearer {user_token}"}
    )
    
    assert response.status_code == 200
    
    # Check task was enqueued
    assert response.json()["task_id"] is not None
```

---

### 3. E2E Tests

**Frontend Tests** (`tests/e2e/` using Playwright):
```typescript
// tests/e2e/approval-flow.spec.ts
test('user can approve draft and see success', async ({ page }) => {
  await login(page)
  await page.goto('/inbox')
  
  // Click first draft
  await page.click('[data-testid=draft-card]:first-child')
  
  // Approve
  await page.click('[data-testid=approve-button]')
  
  // Should see success
  await expect(page.locator('text=Draft approved')).toBeVisible()
})
```

---

## Critical Test Cases

### Hard Rules (Priority 1)
- [ ] Rule 1: Approval required
- [ ] Rule 2: No links validation
- [ ] Rule 3: LLM judges enforce gates
- [ ] Rule 4: One Reddit app per company
- [ ] Rule 5: Encrypted credentials
- [ ] Rule 6: Rate limiting enforced
- [ ] Rule 7: RLS enforced
- [ ] Rule 8: Post verification runs
- [ ] Rule 9: Company isolation
- [ ] Rule 10: Posting disabled in dev

### Core Flows (Priority 2)
- [ ] Generation pipeline end-to-end
- [ ] Draft approval → posting
- [ ] Post verification detects removal
- [ ] RAG retrieval returns relevant docs
- [ ] Rate limits prevent over-posting

### Edge Cases (Priority 3)
- [ ] Invalid inputs handled gracefully
- [ ] Concurrent requests don't break state
- [ ] Failed LLM calls retry
- [ ] Database connection failures handled

---

## Test Commands

```bash
# Backend
cd mentions_backend
pytest                      # All tests
pytest --cov=. --cov-report=html  # With coverage
pytest tests/unit/          # Unit only
pytest tests/integration/   # Integration only
pytest -k "test_hard_rules" # Specific tests

# Frontend
cd mentions_frontend
npm run type-check         # TypeScript
npm run lint               # ESLint
npm test                   # Unit tests
npm run test:e2e           # Playwright E2E
```

---

## CI Integration

Tests run on every PR (see [M5-PRODUCTION.md](./M5-PRODUCTION.md), Task 5.4):

```.github/workflows/test.yml
name: Test
on: [pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run tests
        run: |
          cd mentions_backend
          pytest --cov=. --cov-report=xml
```

---

## Coverage Requirements

- **Backend**: >80% coverage
- **Critical paths**: 100% coverage
  - services/post.py
  - services/rate_limiter.py
  - reddit/encryption.py

---

## Test Data

Use fixtures for consistent test data:

```python
# tests/conftest.py
@pytest.fixture
async def test_company():
    company_id = str(uuid.uuid4())
    await db.execute(
        "INSERT INTO companies (id, name) VALUES ($1, 'Test Company')",
        company_id
    )
    yield company_id
    await db.execute("DELETE FROM companies WHERE id = $1", company_id)

@pytest.fixture
async def test_user(test_company):
    user_id = str(uuid.uuid4())
    await db.execute(
        "INSERT INTO auth.users (id, company_id, email) VALUES ($1, $2, 'test@example.com')",
        user_id, test_company
    )
    yield user_id
    await db.execute("DELETE FROM auth.users WHERE id = $1", user_id)
```

---

## Verification

- [ ] All tests pass
- [ ] Coverage >80%
- [ ] All hard rules tested
- [ ] No flaky tests
- [ ] Fast (<5 min total)

**Reference**: [M5-PRODUCTION.md](./M5-PRODUCTION.md), [22-HARD-RULES.md](./22-HARD-RULES.md)






