# Rate Limiting

Complete guide to rate limiting to prevent spam flags and bans.

---

## Limits (from Rule 6)

```python
MAX_POSTS_PER_ACCOUNT_PER_DAY = 10
MAX_POSTS_PER_SUBREDDIT_PER_ACCOUNT_PER_WEEK = 3
MIN_MINUTES_BETWEEN_POSTS = 15
MAX_POSTS_PER_COMPANY_PER_DAY = 50
```

---

## Implementation

See complete implementation in [M4-VOLUME-LEARNING.md](./M4-VOLUME-LEARNING.md), Task 4.1.

```python
# services/rate_limiter.py
async def check_post_eligibility(company_id, account_id, subreddit) -> tuple[bool, str]:
    """Check all rate limits. Returns (is_eligible, reason)."""
    
    # Check account daily limit
    posts_today = await count_posts_today(account_id)
    if posts_today >= MAX_POSTS_PER_ACCOUNT_PER_DAY:
        return False, f"Account daily limit reached ({posts_today}/10)"
    
    # Check subreddit weekly limit  
    posts_this_week = await count_subreddit_posts_this_week(account_id, subreddit)
    if posts_this_week >= MAX_POSTS_PER_SUBREDDIT_PER_ACCOUNT_PER_WEEK:
        return False, f"Subreddit weekly limit reached ({posts_this_week}/3)"
    
    # Check time since last post
    last_post = await get_last_post(account_id)
    if last_post:
        minutes_since = (now() - last_post.created_at).total_seconds() / 60
        if minutes_since < MIN_MINUTES_BETWEEN_POSTS:
            return False, f"Must wait {15 - minutes_since:.0f} more minutes"
    
    # Check company daily limit
    company_posts_today = await count_company_posts_today(company_id)
    if company_posts_today >= MAX_POSTS_PER_COMPANY_PER_DAY:
        return False, f"Company daily limit reached ({company_posts_today}/50)"
    
    return True, "Eligible"
```

---

## Cloud Tasks Rate Limiting

```python
# Per-account queues enforce rate limiting
async def enqueue_post_task(draft_id: str):
    """Enqueue with automatic rate limiting via Cloud Tasks."""
    draft = await get_draft(draft_id)
    
    # Each account has its own queue
    queue_name = f"reddit-posts-{draft['reddit_account_id']}"
    
    # Calculate delay based on last post
    last_post_time = await get_last_post_time(draft["reddit_account_id"])
    delay_seconds = max(0, 15*60 - (now() - last_post_time).total_seconds())
    
    # Schedule task with delay
    task_client.create_task(
        parent=queue_path,
        task={
            "http_request": {"url": f"/internal/post/{draft_id}"},
            "schedule_time": now() + timedelta(seconds=delay_seconds)
        }
    )
```

---

## UI Indicator

```tsx
// components/inbox/EligibilityIndicator.tsx
export function EligibilityIndicator({ accountId }) {
  const [status, setStatus] = useState(null)
  
  useEffect(() => {
    fetch(`/api/rate-limits/status?account_id=${accountId}`)
      .then(r => r.json())
      .then(setStatus)
  }, [accountId])
  
  if (!status) return null
  
  return (
    <div>
      <div>Posts today: {status.posts_today} / {status.daily_limit}</div>
      {!status.is_eligible && (
        <div className="text-orange-600">
          Next eligible: {formatDistanceToNow(status.next_eligible_at)}
        </div>
      )}
    </div>
  )
}
```

---

## Verification

- [ ] Rate limits prevent over-posting
- [ ] Cloud Tasks enforce delays
- [ ] UI shows eligibility status
- [ ] No Reddit bans

**Reference**: [22-HARD-RULES.md](./22-HARD-RULES.md) (Rule 6), [M4-VOLUME-LEARNING.md](./M4-VOLUME-LEARNING.md)

