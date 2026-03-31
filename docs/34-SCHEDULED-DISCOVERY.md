# Scheduled Discovery & Monitoring

## Overview

This document defines how the system **continuously discovers** new subreddits and threads for tracked keywords. The discovery process runs automatically via Cloud Scheduler and Cloud Tasks.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Cloud Scheduler (Cron)                    │
│  • Every 2 hours: Trigger discovery for all active keywords │
│  • Every 15 minutes: Check high-priority keywords          │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│                     Cloud Tasks Queue                        │
│  • discovery-queue: One task per (company, keyword)         │
│  • Rate limiting: Max 50 concurrent, 100/min                │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│                  FastAPI Endpoint                            │
│  POST /internal/discover                                     │
│  • Receives: company_id, keyword, priority                   │
│  • Triggers: LangGraph generation flow                       │
│  • Returns: task_id for tracking                             │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│                  LangGraph Pipeline                          │
│  • Fetch subreddits from Reddit API                         │
│  • Filter by history (skip known bad)                        │
│  • Judge subreddit (LLM gate)                               │
│  • Fetch threads → Draft → Ready for review                 │
└─────────────────────────────────────────────────────────────┘
```

---

## Discovery Triggers

### 1. Scheduled Discovery (Primary)

**Cloud Scheduler Jobs**:

```yaml
# Job 1: Regular discovery (all keywords)
name: discovery-regular
schedule: "0 */2 * * *"  # Every 2 hours
description: "Discover new threads for all active keywords"
target: /internal/scheduler/trigger-discovery
body:
  priority: "normal"
  max_keywords_per_batch: 100

# Job 2: High-priority discovery (active campaigns)
name: discovery-priority
schedule: "*/15 * * * *"  # Every 15 minutes
description: "Fast discovery for high-priority keywords"
target: /internal/scheduler/trigger-discovery-priority
body:
  priority: "high"
  max_age_hours: 2  # Only keywords used in last 2 hours
```

### 2. Manual Trigger (User-Initiated)

Users can manually trigger discovery from the UI:

```typescript
// Frontend: Settings > Keywords > "Discover Now" button
async function triggerDiscovery(keywordId: string) {
  await fetch('/api/keywords/{keywordId}/discover', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` }
  });
}
```

### 3. On-Demand (New Keyword Added)

When a user adds a new keyword, trigger immediate discovery:

```python
# api/keywords.py
@router.post("/keywords")
async def create_keyword(keyword: KeywordCreate, user = Depends(get_current_user)):
    # Save keyword
    kw = await db.fetchrow(
        "INSERT INTO keywords (company_id, keyword, ...) VALUES (...) RETURNING *",
        ...
    )
    
    # Trigger immediate discovery
    await enqueue_discovery_task(
        company_id=user.company_id,
        keyword=kw["keyword"],
        priority="high"
    )
    
    return {"keyword": dict(kw)}
```

---

## Database Schema Addition

Add a `keywords` table to track what to monitor:

```sql
create table keywords (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  keyword text not null,
  is_active boolean default true,
  priority text check (priority in ('low', 'normal', 'high')) default 'normal',
  discovery_frequency_minutes int default 120,  -- How often to check
  last_discovered_at timestamptz,
  next_discovery_at timestamptz,
  total_discoveries int default 0,
  total_artifacts int default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create unique index idx_keywords_company_keyword on keywords(company_id, keyword);
create index idx_keywords_next_discovery on keywords(next_discovery_at) where is_active = true;
create index idx_keywords_company_active on keywords(company_id, is_active) where is_active = true;
```

---

## Implementation

### Step 1: Scheduler Endpoint

```python
# api/internal/scheduler.py
from fastapi import APIRouter, Depends, HTTPException
from google.cloud import tasks_v2
from core.auth import verify_cloud_scheduler_token
from core.config import settings
import uuid

router = APIRouter()

@router.post("/scheduler/trigger-discovery")
async def trigger_discovery(
    body: dict,
    _token = Depends(verify_cloud_scheduler_token)  # Verify it's from Cloud Scheduler
):
    """
    Cloud Scheduler calls this endpoint to trigger discovery.
    Enqueues one Cloud Tasks task per active keyword.
    """
    priority = body.get("priority", "normal")
    max_keywords = body.get("max_keywords_per_batch", 100)
    max_age_hours = body.get("max_age_hours")
    
    # Query active keywords
    query = """
        SELECT k.id, k.company_id, k.keyword, k.priority
        FROM keywords k
        WHERE k.is_active = true
          AND (k.next_discovery_at IS NULL OR k.next_discovery_at <= NOW())
    """
    
    params = []
    if priority == "high":
        query += " AND k.priority = 'high'"
    
    if max_age_hours:
        query += " AND k.updated_at > NOW() - INTERVAL '%s hours'"
        params.append(max_age_hours)
    
    query += f" ORDER BY k.priority DESC, k.last_discovered_at ASC NULLS FIRST LIMIT {max_keywords}"
    
    keywords = await db.fetch(query, *params)
    
    # Enqueue one task per keyword
    tasks_client = tasks_v2.CloudTasksClient()
    parent = tasks_client.queue_path(
        settings.gcp_project_id,
        settings.gcp_region,
        "discovery-queue"
    )
    
    enqueued = 0
    for kw in keywords:
        task = {
            "http_request": {
                "http_method": tasks_v2.HttpMethod.POST,
                "url": f"{settings.api_base_url}/internal/discover",
                "headers": {
                    "Content-Type": "application/json",
                    "Authorization": f"Bearer {settings.internal_api_token}"
                },
                "body": json.dumps({
                    "company_id": str(kw["company_id"]),
                    "keyword": kw["keyword"],
                    "keyword_id": str(kw["id"]),
                    "priority": kw["priority"]
                }).encode()
            }
        }
        
        tasks_client.create_task(request={"parent": parent, "task": task})
        enqueued += 1
    
    logger.info(f"Enqueued {enqueued} discovery tasks (priority={priority})")
    
    return {"enqueued": enqueued, "keywords": len(keywords)}
```

### Step 2: Discovery Worker Endpoint

```python
# api/internal/discover.py
from fastapi import APIRouter, Depends, BackgroundTasks
from core.auth import verify_internal_token
from graph.build import build_generate_graph
from graph.checkpointer import get_graph_checkpointer
import uuid

router = APIRouter()

@router.post("/discover")
async def discover_keyword(
    body: dict,
    background_tasks: BackgroundTasks,
    _token = Depends(verify_internal_token)
):
    """
    Worker endpoint that runs LangGraph discovery for one keyword.
    Called by Cloud Tasks.
    """
    company_id = body["company_id"]
    keyword = body["keyword"]
    keyword_id = body["keyword_id"]
    
    logger.info(f"Starting discovery for company={company_id}, keyword={keyword}")
    
    # Get company settings
    company = await db.fetchrow(
        "SELECT id, name FROM companies WHERE id = $1",
        company_id
    )
    
    if not company:
        raise HTTPException(status_code=404, detail="Company not found")
    
    # Get company's default Reddit account
    reddit_account = await db.fetchrow(
        """
        SELECT id FROM reddit_connections 
        WHERE company_id = $1 AND is_active = true 
        ORDER BY created_at DESC LIMIT 1
        """,
        company_id
    )
    
    if not reddit_account:
        logger.warning(f"No active Reddit account for company {company_id}")
        return {"status": "skipped", "reason": "no_reddit_account"}
    
    # Get company goal and prompt
    prompt = await db.fetchrow(
        "SELECT id FROM prompts WHERE company_id = $1 AND is_default = true",
        company_id
    )
    
    # Generate thread_id for LangGraph state persistence
    thread_id = f"{company_id}:{keyword}:{uuid.uuid4().hex[:8]}"
    
    # Build initial state
    initial_state = {
        "company_id": company_id,
        "company_goal": company.get("goal", "Helpful and informative responses"),
        "keywords": [keyword],
        "keyword": keyword,
        "reddit_account_id": reddit_account["id"],
        "prompt_id": prompt["id"] if prompt else None,
        "retry_count": 0
    }
    
    # Run LangGraph pipeline
    checkpointer = get_graph_checkpointer()
    graph = build_generate_graph(checkpointer=checkpointer)
    
    config = {
        "configurable": {
            "thread_id": thread_id,
            "checkpoint_ns": f"company:{company_id}"
        }
    }
    
    try:
        result = await graph.ainvoke(initial_state, config=config)
        
        # Update keyword discovery timestamp
        await db.execute(
            """
            UPDATE keywords 
            SET 
                last_discovered_at = NOW(),
                next_discovery_at = NOW() + INTERVAL '1 minute' * discovery_frequency_minutes,
                total_discoveries = total_discoveries + 1,
                total_artifacts = total_artifacts + COALESCE($2, 0)
            WHERE id = $1
            """,
            keyword_id,
            1 if result.get("artifact_id") else 0
        )
        
        if result.get("error"):
            logger.error(f"Discovery failed: {result['error']}")
            return {
                "status": "failed",
                "error": result["error"],
                "thread_id": thread_id
            }
        
        logger.info(f"Discovery complete: artifact_id={result.get('artifact_id')}")
        
        return {
            "status": "success",
            "artifact_id": result.get("artifact_id"),
            "thread_id": thread_id,
            "keyword": keyword
        }
        
    except Exception as e:
        logger.exception(f"Discovery exception: {e}")
        return {
            "status": "error",
            "error": str(e),
            "thread_id": thread_id
        }
```

### Step 3: User Manual Trigger

```python
# api/keywords.py
@router.post("/keywords/{keyword_id}/discover")
async def manual_discover(
    keyword_id: str,
    user = Depends(get_current_user)
):
    """
    User manually triggers discovery for a specific keyword.
    """
    # Verify keyword belongs to user's company
    keyword = await db.fetchrow(
        "SELECT * FROM keywords WHERE id = $1 AND company_id = $2",
        keyword_id,
        user.company_id
    )
    
    if not keyword:
        raise HTTPException(status_code=404, detail="Keyword not found")
    
    # Enqueue high-priority task
    await enqueue_discovery_task(
        company_id=user.company_id,
        keyword=keyword["keyword"],
        keyword_id=keyword_id,
        priority="high"
    )
    
    return {
        "status": "enqueued",
        "keyword": keyword["keyword"],
        "message": "Discovery started"
    }
```

---

## Discovery Frequency & Rate Limiting

### Per-Keyword Configuration

Companies can configure discovery frequency per keyword:

| Priority | Default Frequency | Use Case |
|----------|-------------------|----------|
| **High** | Every 15 minutes | Active campaigns, new products |
| **Normal** | Every 2 hours | Regular monitoring |
| **Low** | Every 6 hours | Background tracking |

### Global Rate Limits

**Cloud Tasks Queue Configuration**:

```python
# Terraform: mentions_terraform/modules/cloud-tasks/main.tf
resource "google_cloud_tasks_queue" "discovery" {
  name     = "discovery-queue"
  location = var.region
  
  rate_limits {
    max_concurrent_dispatches = 50    # Max 50 discovery tasks at once
    max_dispatches_per_second = 1.67  # ~100 per minute
  }
  
  retry_config {
    max_attempts       = 3
    max_retry_duration = "600s"  # 10 minutes
    min_backoff        = "10s"
    max_backoff        = "300s"
    max_doublings      = 3
  }
}
```

**Reddit API Rate Limits**:

```python
# Respect Reddit's rate limits
# - 60 requests per minute for authenticated users
# - Use exponential backoff for 429 responses

import asyncio
from datetime import datetime, timedelta

class RedditRateLimiter:
    def __init__(self):
        self.requests = []
        self.max_per_minute = 60
    
    async def acquire(self):
        now = datetime.utcnow()
        
        # Remove requests older than 1 minute
        self.requests = [r for r in self.requests if r > now - timedelta(minutes=1)]
        
        # Wait if at limit
        if len(self.requests) >= self.max_per_minute:
            sleep_time = (self.requests[0] + timedelta(minutes=1) - now).total_seconds()
            await asyncio.sleep(max(0, sleep_time))
        
        self.requests.append(now)
```

---

## Monitoring & Observability

### Metrics to Track

```python
# Export to Cloud Monitoring
from google.cloud import monitoring_v3

# Discovery metrics
discovery_runs_total = Counter("discovery_runs_total", ["company_id", "keyword", "status"])
discovery_duration_seconds = Histogram("discovery_duration_seconds", ["company_id"])
artifacts_created_total = Counter("artifacts_created_total", ["company_id", "keyword"])
subreddits_found_total = Counter("subreddits_found_total", ["company_id", "keyword"])
subreddits_rejected_total = Counter("subreddits_rejected_total", ["company_id", "keyword", "reason"])

# Queue metrics
tasks_enqueued_total = Counter("tasks_enqueued_total", ["queue", "priority"])
tasks_failed_total = Counter("tasks_failed_total", ["queue", "error_type"])
```

### Logs

```python
# Structured logging for discovery runs
logger.info(
    "Discovery run complete",
    extra={
        "company_id": company_id,
        "keyword": keyword,
        "duration_seconds": duration,
        "subreddits_found": len(subreddits),
        "subreddits_passed": passed_count,
        "artifacts_created": artifact_count,
        "thread_id": thread_id
    }
)
```

### Alerts

```yaml
# Cloud Monitoring alerts
alerts:
  - name: "Discovery Failure Rate High"
    condition: "discovery_runs_total{status='failed'} / discovery_runs_total > 0.1"
    duration: "5m"
    severity: "warning"
  
  - name: "No Discoveries in 6 Hours"
    condition: "rate(discovery_runs_total[6h]) == 0"
    severity: "critical"
  
  - name: "Task Queue Backlog"
    condition: "cloudtasks_queue_depth{queue='discovery-queue'} > 1000"
    severity: "warning"
```

---

## FAQ

### Q: How quickly will new threads be discovered?

**A**: Depends on keyword priority:
- **High priority**: Within 15 minutes
- **Normal priority**: Within 2 hours
- **Low priority**: Within 6 hours

### Q: What if Reddit is down?

**A**: Cloud Tasks will automatically retry with exponential backoff (up to 3 attempts over 10 minutes). If still failing, alert will trigger.

### Q: Can users see discovery status?

**A**: Yes, the keywords table tracks:
- `last_discovered_at` - When we last checked
- `next_discovery_at` - When we'll check next
- `total_discoveries` - How many runs
- `total_artifacts` - How many artifacts found

Display in UI:
```typescript
<KeywordCard>
  <p>Last checked: {formatDistance(keyword.last_discovered_at, new Date())} ago</p>
  <p>Next check: in {formatDistance(new Date(), keyword.next_discovery_at)}</p>
  <p>Found: {keyword.total_artifacts} replies ready for review</p>
</KeywordCard>
```

### Q: What if a keyword generates too many artifacts?

**A**: Add a daily/weekly limit in the keywords table:

```sql
alter table keywords add column max_artifacts_per_day int default 10;

-- Check in discovery endpoint
SELECT COUNT(*) FROM artifacts 
WHERE keyword = $1 
  AND created_at > NOW() - INTERVAL '24 hours';

-- If at limit, skip discovery and log
```

---

## Summary

**Discovery is triggered by**:
1. ✅ **Cloud Scheduler** (every 2 hours for all keywords, every 15 min for high-priority)
2. ✅ **User manual trigger** (UI button → API → Cloud Tasks)
3. ✅ **New keyword added** (immediate first discovery)

**Process**:
1. Scheduler → Cloud Tasks (one task per keyword)
2. Task → FastAPI `/internal/discover`
3. FastAPI → LangGraph pipeline
4. LangGraph → Reddit API → Discover subreddits → Draft replies
5. Update `keywords.last_discovered_at` and `keywords.next_discovery_at`

**Rate limiting**:
- Max 50 concurrent discoveries
- Max 100 discoveries per minute
- Respects Reddit's 60 req/min limit

This ensures continuous, automatic discovery of new opportunities while respecting all rate limits! 🚀






