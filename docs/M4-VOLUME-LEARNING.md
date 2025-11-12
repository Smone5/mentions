# Milestone 4: Volume & Learning

**Duration**: Weeks 7-8 (2 weeks)  
**Prerequisites**: M1, M2, M3 complete

---

## Overview

Scale the system to handle production volume and collect training data for continuous improvement.

**Goals**:
- Handle ~200 posts/week across all companies
- Enforce rate limits to prevent spam flags
- Log all interactions for future fine-tuning
- Export training data for model improvement
- Analytics dashboard for monitoring

---

## Task Breakdown

### Task 4.1: Rate Limiting Service
**Time**: 4 hours

```python
# services/rate_limiter.py
from datetime import datetime, timedelta

# Volume limits (from 22-HARD-RULES.md Rule 6)
MAX_POSTS_PER_ACCOUNT_PER_DAY = 10
MAX_POSTS_PER_SUBREDDIT_PER_ACCOUNT_PER_WEEK = 3
MIN_MINUTES_BETWEEN_POSTS = 15
MAX_POSTS_PER_COMPANY_PER_DAY = 50

async def check_post_eligibility(
    company_id: str,
    reddit_account_id: str,
    subreddit: str
) -> tuple[bool, str]:
    """
    Check if account is eligible to post based on rate limits.
    Returns (is_eligible, reason).
    """
    
    # Check account daily limit
    posts_today = await db.fetchval(
        """
        SELECT COUNT(*) FROM posts
        WHERE reddit_account_id = $1
        AND created_at >= NOW() - INTERVAL '24 hours'
        AND status NOT IN ('failed', 'removed')
        """,
        reddit_account_id
    )
    
    if posts_today >= MAX_POSTS_PER_ACCOUNT_PER_DAY:
        return False, f"Account daily limit reached ({posts_today}/{MAX_POSTS_PER_ACCOUNT_PER_DAY})"
    
    # Check subreddit weekly limit
    posts_this_week = await db.fetchval(
        """
        SELECT COUNT(*) FROM posts
        WHERE reddit_account_id = $1
        AND subreddit = $2
        AND created_at >= NOW() - INTERVAL '7 days'
        AND status NOT IN ('failed', 'removed')
        """,
        reddit_account_id,
        subreddit
    )
    
    if posts_this_week >= MAX_POSTS_PER_SUBREDDIT_PER_ACCOUNT_PER_WEEK:
        return False, f"Subreddit weekly limit reached ({posts_this_week}/{MAX_POSTS_PER_SUBREDDIT_PER_ACCOUNT_PER_WEEK})"
    
    # Check time since last post
    last_post = await db.fetchrow(
        """
        SELECT created_at FROM posts
        WHERE reddit_account_id = $1
        AND status NOT IN ('failed', 'removed')
        ORDER BY created_at DESC
        LIMIT 1
        """,
        reddit_account_id
    )
    
    if last_post:
        minutes_since = (datetime.now() - last_post["created_at"]).total_seconds() / 60
        if minutes_since < MIN_MINUTES_BETWEEN_POSTS:
            wait_minutes = MIN_MINUTES_BETWEEN_POSTS - minutes_since
            return False, f"Must wait {wait_minutes:.0f} more minutes before posting"
    
    # Check company daily limit
    company_posts_today = await db.fetchval(
        """
        SELECT COUNT(*) FROM posts p
        JOIN drafts d ON p.draft_id = d.id
        JOIN artifacts a ON d.artifact_id = a.id
        WHERE a.company_id = $1
        AND p.created_at >= NOW() - INTERVAL '24 hours'
        AND p.status NOT IN ('failed', 'removed')
        """,
        company_id
    )
    
    if company_posts_today >= MAX_POSTS_PER_COMPANY_PER_DAY:
        return False, f"Company daily limit reached ({company_posts_today}/{MAX_POSTS_PER_COMPANY_PER_DAY})"
    
    return True, "Eligible"


async def get_account_eligibility_status(reddit_account_id: str) -> dict:
    """Get current rate limit status for an account."""
    now = datetime.now()
    
    # Posts today
    posts_today = await db.fetchval(
        "SELECT COUNT(*) FROM posts WHERE reddit_account_id = $1 AND created_at >= $2",
        reddit_account_id,
        now - timedelta(days=1)
    )
    
    # Time until next eligible post
    last_post = await db.fetchrow(
        """
        SELECT created_at FROM posts
        WHERE reddit_account_id = $1
        ORDER BY created_at DESC
        LIMIT 1
        """,
        reddit_account_id
    )
    
    next_eligible = None
    if last_post:
        next_eligible = last_post["created_at"] + timedelta(minutes=MIN_MINUTES_BETWEEN_POSTS)
    
    return {
        "posts_today": posts_today,
        "daily_limit": MAX_POSTS_PER_ACCOUNT_PER_DAY,
        "remaining_today": max(0, MAX_POSTS_PER_ACCOUNT_PER_DAY - posts_today),
        "next_eligible_at": next_eligible,
        "is_eligible": next_eligible is None or next_eligible <= now
    }
```

**Verification**:
- [ ] Rate limits enforced correctly
- [ ] Returns accurate wait times
- [ ] Prevents over-posting

---

### Task 4.2: Training Events Logger
**Time**: 3 hours

```python
# services/training_events.py
import json

async def log_training_event(
    draft_id: str = None,
    post_id: str = None,
    event_type: str = None,
    user_id: str = None,
    data: dict = None
):
    """
    Log training event for future fine-tuning.
    
    Event Types:
    - draft_approved: User approved draft
    - draft_rejected: User rejected draft
    - draft_edited: User edited draft text
    - post_created: Draft posted to Reddit
    - post_verified: Post verified as visible
    - post_removed: Post detected as removed
    """
    
    event_id = str(uuid.uuid4())
    
    await db.execute(
        """
        INSERT INTO training_events (
            id, draft_id, post_id, event_type, user_id, data, created_at
        ) VALUES ($1, $2, $3, $4, $5, $6, NOW())
        """,
        event_id,
        draft_id,
        post_id,
        event_type,
        user_id,
        json.dumps(data) if data else None
    )
    
    logger.info(f"Logged training event: {event_type} for draft {draft_id}")
    
    return event_id
```

**Integration Points** (add to existing code):
```python
# In api/drafts.py - approve endpoint
await log_training_event(
    draft_id=draft_id,
    event_type="draft_approved",
    user_id=user.id,
    data={}
)

# In api/drafts.py - reject endpoint
await log_training_event(
    draft_id=draft_id,
    event_type="draft_rejected",
    user_id=user.id,
    data={"reason": request.reason}
)

# In api/drafts.py - update endpoint
await log_training_event(
    draft_id=draft_id,
    event_type="draft_edited",
    user_id=user.id,
    data={"old_body": draft["body"], "new_body": request.body}
)

# In services/post.py - after posting
await log_training_event(
    draft_id=draft_id,
    post_id=post_id,
    event_type="post_created",
    data={"reddit_post_id": result["id"], "permalink": result["permalink"]}
)

# In tasks/verify_post.py - after verification
await log_training_event(
    post_id=post_id,
    event_type="post_verified" if visible else "post_removed",
    data={"score": score, "reason": reason}
)
```

**Verification**:
- [ ] Events logged for all actions
- [ ] Contains complete context for training
- [ ] Query-able for analytics

---

### Task 4.3: Analytics API & Dashboard
**Time**: 6 hours

```python
# api/analytics.py
from fastapi import APIRouter, Depends
from core.auth import get_current_user

router = APIRouter()

@router.get("/analytics/overview")
async def get_analytics_overview(
    user = Depends(get_current_user),
    days: int = 30
):
    """Get high-level analytics for company."""
    
    company_id = user.company_id
    since = datetime.now() - timedelta(days=days)
    
    # Total posts
    total_posts = await db.fetchval(
        """
        SELECT COUNT(*) FROM posts p
        JOIN drafts d ON p.draft_id = d.id
        JOIN artifacts a ON d.artifact_id = a.id
        WHERE a.company_id = $1 AND p.created_at >= $2
        """,
        company_id, since
    )
    
    # Verified posts (successful)
    verified_posts = await db.fetchval(
        """
        SELECT COUNT(*) FROM posts p
        JOIN drafts d ON p.draft_id = d.id
        JOIN artifacts a ON d.artifact_id = a.id
        WHERE a.company_id = $1 AND p.status = 'verified' AND p.created_at >= $2
        """,
        company_id, since
    )
    
    # Removed posts
    removed_posts = await db.fetchval(
        """
        SELECT COUNT(*) FROM posts p
        JOIN drafts d ON p.draft_id = d.id
        JOIN artifacts a ON d.artifact_id = a.id
        WHERE a.company_id = $1 AND p.status IN ('removed', 'spam') AND p.created_at >= $2
        """,
        company_id, since
    )
    
    # Draft approval rate
    total_drafts = await db.fetchval(
        """
        SELECT COUNT(*) FROM drafts d
        JOIN artifacts a ON d.artifact_id = a.id
        WHERE a.company_id = $1 AND d.created_at >= $2
        """,
        company_id, since
    )
    
    approved_drafts = await db.fetchval(
        """
        SELECT COUNT(*) FROM drafts d
        JOIN artifacts a ON d.artifact_id = a.id
        WHERE a.company_id = $1 AND d.status = 'approved' AND d.created_at >= $2
        """,
        company_id, since
    )
    
    # Top subreddits
    top_subreddits = await db.fetch(
        """
        SELECT p.subreddit, COUNT(*) as count
        FROM posts p
        JOIN drafts d ON p.draft_id = d.id
        JOIN artifacts a ON d.artifact_id = a.id
        WHERE a.company_id = $1 AND p.created_at >= $2
        GROUP BY p.subreddit
        ORDER BY count DESC
        LIMIT 10
        """,
        company_id, since
    )
    
    # Posts by day (for chart)
    posts_by_day = await db.fetch(
        """
        SELECT DATE(p.created_at) as date, COUNT(*) as count
        FROM posts p
        JOIN drafts d ON p.draft_id = d.id
        JOIN artifacts a ON d.artifact_id = a.id
        WHERE a.company_id = $1 AND p.created_at >= $2
        GROUP BY DATE(p.created_at)
        ORDER BY date
        """,
        company_id, since
    )
    
    return {
        "total_posts": total_posts,
        "verified_posts": verified_posts,
        "removed_posts": removed_posts,
        "success_rate": verified_posts / total_posts if total_posts > 0 else 0,
        "total_drafts": total_drafts,
        "approved_drafts": approved_drafts,
        "approval_rate": approved_drafts / total_drafts if total_drafts > 0 else 0,
        "top_subreddits": [dict(r) for r in top_subreddits],
        "posts_by_day": [dict(r) for r in posts_by_day]
    }
```

**Frontend** (`app/analytics/page.tsx`):
```tsx
'use client'

import { useEffect, useState } from 'use'
import { StatsCard } from '@/components/analytics/StatsCard'
import { PostsChart } from '@/components/analytics/PostsChart'
import { SubredditTable } from '@/components/analytics/SubredditTable'

export default function AnalyticsPage() {
  const [data, setData] = useState(null)
  const [days, setDays] = useState(30)
  
  useEffect(() => {
    fetchAnalytics()
  }, [days])
  
  const fetchAnalytics = async () => {
    const response = await fetch(`/api/analytics/overview?days=${days}`)
    const data = await response.json()
    setData(data)
  }
  
  if (!data) return <div>Loading...</div>
  
  return (
    <div className="container mx-auto px-4 py-6">
      <h1 className="text-3xl font-bold mb-6">Analytics</h1>
      
      {/* Time period selector */}
      <select value={days} onChange={(e) => setDays(parseInt(e.target.value))}>
        <option value={7}>Last 7 days</option>
        <option value={30}>Last 30 days</option>
        <option value={90}>Last 90 days</option>
      </select>
      
      {/* Key metrics */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <StatsCard
          title="Total Posts"
          value={data.total_posts}
          icon="📊"
        />
        <StatsCard
          title="Success Rate"
          value={`${(data.success_rate * 100).toFixed(1)}%`}
          icon="✅"
        />
        <StatsCard
          title="Approval Rate"
          value={`${(data.approval_rate * 100).toFixed(1)}%`}
          icon="👍"
        />
        <StatsCard
          title="Removed"
          value={data.removed_posts}
          icon="❌"
        />
      </div>
      
      {/* Posts chart */}
      <div className="bg-white rounded-lg p-6 mb-8">
        <h2 className="text-xl font-bold mb-4">Posts Over Time</h2>
        <PostsChart data={data.posts_by_day} />
      </div>
      
      {/* Top subreddits */}
      <div className="bg-white rounded-lg p-6">
        <h2 className="text-xl font-bold mb-4">Top Subreddits</h2>
        <SubredditTable data={data.top_subreddits} />
      </div>
    </div>
  )
}
```

**Verification**:
- [ ] Dashboard shows accurate metrics
- [ ] Charts render correctly
- [ ] Can filter by time period

---

### Task 4.4: Fine-Tuning Export
**Time**: 5 hours

```python
# services/fine_tuning.py
import json

async def export_training_data(
    company_id: str,
    start_date: datetime,
    end_date: datetime
) -> str:
    """
    Export training data for company-specific fine-tuning.
    
    Format: OpenAI JSONL fine-tuning format
    {"messages": [{"role": "system", "content": "..."}, {"role": "user", "content": "..."}, {"role": "assistant", "content": "..."}]}
    """
    
    # Fetch approved/posted drafts with full context
    drafts = await db.fetch(
        """
        SELECT
            d.id as draft_id,
            d.body as draft_body,
            a.keyword,
            a.subreddit,
            a.thread_title,
            a.thread_body,
            a.top_comments,
            p.body as prompt_body,
            r.company_data,
            posts.status as post_status,
            posts.reddit_post_id
        FROM drafts d
        JOIN artifacts a ON d.artifact_id = a.id
        JOIN prompts p ON a.prompt_id = p.id
        LEFT JOIN posts ON posts.draft_id = d.id
        LEFT JOIN (
            SELECT company_id, STRING_AGG(chunk_text, '\n\n') as company_data
            FROM rag_chunks
            GROUP BY company_id
        ) r ON a.company_id = r.company_id
        WHERE a.company_id = $1
        AND d.created_at BETWEEN $2 AND $3
        AND d.status IN ('approved', 'posted')
        ORDER BY d.created_at
        """,
        company_id, start_date, end_date
    )
    
    # Convert to OpenAI format
    training_examples = []
    
    for draft in drafts:
        # System prompt
        system_message = f"""You are a helpful assistant for {company_id}. Your goal is to participate authentically in Reddit conversations. You must:
- Be helpful and informative
- Ground responses in the company's knowledge
- Never include links or URLs
- Follow subreddit rules"""
        
        # User prompt (input)
        user_message = f"""Keyword: {draft['keyword']}
Subreddit: r/{draft['subreddit']}
Thread Title: {draft['thread_title']}
Thread Body: {draft['thread_body']}
Top Comments: {draft['top_comments']}

Company Data:
{draft['company_data'][:1000]}  # Truncate for context limit

Draft a helpful reply."""
        
        # Assistant response (expected output)
        assistant_message = draft['draft_body']
        
        training_examples.append({
            "messages": [
                {"role": "system", "content": system_message},
                {"role": "user", "content": user_message},
                {"role": "assistant", "content": assistant_message}
            ]
        })
    
    # Save to JSONL file
    export_id = str(uuid.uuid4())
    filename = f"training_export_{company_id}_{start_date.date()}_{end_date.date()}_{export_id}.jsonl"
    filepath = f"/tmp/{filename}"
    
    with open(filepath, 'w') as f:
        for example in training_examples:
            f.write(json.dumps(example) + '\n')
    
    # Upload to GCS
    gcs_path = f"gs://mentions-training-data/{company_id}/{filename}"
    # TODO: Implement GCS upload
    
    # Record export
    await db.execute(
        """
        INSERT INTO fine_tuning_exports (
            id, company_id, start_date, end_date, num_examples, gcs_path, created_at
        ) VALUES ($1, $2, $3, $4, $5, $6, NOW())
        """,
        export_id, company_id, start_date, end_date, len(training_examples), gcs_path
    )
    
    logger.info(f"Exported {len(training_examples)} training examples for company {company_id}")
    
    return export_id


@router.post("/fine-tuning/export")
async def export_training_data_endpoint(
    request: ExportRequest,
    user = Depends(get_current_user)
):
    """Export training data for fine-tuning."""
    export_id = await export_training_data(
        company_id=user.company_id,
        start_date=request.start_date,
        end_date=request.end_date
    )
    
    return {"success": True, "export_id": export_id}
```

**Verification**:
- [ ] Exports correct JSONL format
- [ ] Includes complete context
- [ ] Uploads to GCS successfully
- [ ] Records export in database

---

## Success Criteria

By end of M4:
- ✅ Rate limits prevent over-posting
- ✅ All events logged for training
- ✅ Analytics dashboard shows insights
- ✅ Can export training data in OpenAI format
- ✅ System handles 200+ posts/week
- ✅ No Reddit bans or spam flags

---

## Next Steps

After M4 complete, proceed to:
- **[M5-PRODUCTION.md](./M5-PRODUCTION.md)** - Production readiness, testing, deployment



