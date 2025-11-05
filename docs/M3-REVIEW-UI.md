# Milestone 3: Review UI & Approval/Post Flow

**Duration**: Weeks 5-6 (2 weeks)  
**Prerequisites**: M1 (Foundations) and M2 (Generation Flow) complete

---

## Overview

Build the human review interface where users can:
- View generated drafts in an inbox
- See thread context (original post, comments)
- Edit draft text
- Approve or reject drafts
- Trigger posting to Reddit
- Monitor post status

**Critical**: All posts require human approval (Rule 1 from [22-HARD-RULES.md](./22-HARD-RULES.md))

---

## Goals

By the end of M3:
- ✅ Users can see all pending drafts in an inbox
- ✅ Users can filter/sort drafts by risk, keyword, subreddit
- ✅ Users can view full thread context before approving
- ✅ Users can edit draft text before posting
- ✅ Approved drafts are posted to Reddit with verification
- ✅ Users can monitor post status (pending, posted, verified, removed)
- ✅ All hard rules enforced (especially Rule 1, 2, 6, 8, 10)

---

## Architecture

```
Frontend (Next.js)           Backend (FastAPI)                Reddit
─────────────────           ──────────────────                ──────
Inbox Page                  GET /api/drafts                   
  ├─ DraftCard              │                                 
  ├─ Filters                │                                 
  └─ Pagination             └─> Query drafts                  
                                (filtered, sorted)            
                                                              
Draft Detail Page           GET /api/drafts/:id               
  ├─ Thread Context         │                                 
  ├─ Draft Editor           │                                 
  ├─ Approval Controls      └─> Fetch draft + thread          
  └─ Risk Assessment                                          
                                                              
[User Approves]             POST /api/drafts/:id/approve      
                            │                                 
                            ├─> Validate approval             
                            ├─> Check rate limits (Rule 6)    
                            ├─> Enqueue to Cloud Tasks        
                            │                                 
                            └─> Cloud Task Handler            
                                  ├─> Check environment (Rule 10)
                                  ├─> Validate no links (Rule 2)
                                  ├─> Post to Reddit ────────> Comment API
                                  └─> Schedule verification    
                                                              
                                                              
Verification Task           POST /internal/verify-post/:id    
(60 seconds later)          │                                 
                            ├─> Fetch as anonymous ─────────> Reddit Public API
                            └─> Update post status            
```

---

## Task Breakdown

### Task 3.1: Drafts API (Backend)
**Time**: 4 hours  
**Priority**: Critical

#### Endpoints

**1. List Drafts**
```python
# api/drafts.py
from fastapi import APIRouter, Depends, Query
from typing import Optional
from core.auth import get_current_user

router = APIRouter()

@router.get("/drafts")
async def list_drafts(
    user = Depends(get_current_user),
    status: Optional[str] = Query(None),  # pending, approved, rejected, posted
    risk: Optional[str] = Query(None),    # low, medium, high
    keyword: Optional[str] = Query(None),
    subreddit: Optional[str] = Query(None),
    limit: int = Query(20, le=100),
    offset: int = Query(0)
):
    """
    List drafts for user's company with filtering and pagination.
    """
    # Build query with filters
    query = """
        SELECT 
            d.*,
            a.id as artifact_id,
            a.keyword,
            a.subreddit,
            a.thread_id,
            a.thread_title,
            a.status,
            rc.reddit_username
        FROM drafts d
        JOIN artifacts a ON d.artifact_id = a.id
        LEFT JOIN reddit_connections rc ON a.reddit_account_id = rc.id
        WHERE a.company_id = $1
    """
    
    params = [user.company_id]
    param_idx = 2
    
    if status:
        query += f" AND d.status = ${param_idx}"
        params.append(status)
        param_idx += 1
    
    if risk:
        query += f" AND d.risk = ${param_idx}"
        params.append(risk)
        param_idx += 1
    
    if keyword:
        query += f" AND a.keyword = ${param_idx}"
        params.append(keyword)
        param_idx += 1
    
    if subreddit:
        query += f" AND a.subreddit = ${param_idx}"
        params.append(subreddit)
        param_idx += 1
    
    query += f" ORDER BY d.created_at DESC LIMIT ${param_idx} OFFSET ${param_idx + 1}"
    params.extend([limit, offset])
    
    drafts = await db.fetch(query, *params)
    
    # Get total count for pagination
    count_query = "SELECT COUNT(*) FROM drafts d JOIN artifacts a ON d.artifact_id = a.id WHERE a.company_id = $1"
    total = await db.fetchval(count_query, user.company_id)
    
    return {
        "drafts": [dict(d) for d in drafts],
        "total": total,
        "limit": limit,
        "offset": offset
    }
```

**2. Get Single Draft**
```python
@router.get("/drafts/{draft_id}")
async def get_draft(
    draft_id: str,
    user = Depends(get_current_user)
):
    """
    Get single draft with full context (thread, comments, rules).
    """
    query = """
        SELECT 
            d.*,
            a.id as artifact_id,
            a.keyword,
            a.subreddit,
            a.thread_id,
            a.thread_title,
            a.thread_body,
            a.thread_url,
            a.thread_reddit_id,
            a.rules_summary,
            a.rag_context,
            a.status,
            rc.id as reddit_account_id,
            rc.reddit_username,
            p.body as approved_prompt_body
        FROM drafts d
        JOIN artifacts a ON d.artifact_id = a.id
        LEFT JOIN reddit_connections rc ON a.reddit_account_id = rc.id
        LEFT JOIN prompts p ON a.prompt_id = p.id
        WHERE d.id = $1 AND a.company_id = $2
    """
    
    draft = await db.fetchrow(query, draft_id, user.company_id)
    
    if not draft:
        raise HTTPException(status_code=404, detail="Draft not found")
    
    return dict(draft)
```

**3. Update Draft**
```python
@router.put("/drafts/{draft_id}")
async def update_draft(
    draft_id: str,
    request: UpdateDraftRequest,
    user = Depends(get_current_user)
):
    """
    Update draft body (user edited the text).
    """
    # Verify ownership
    draft = await get_draft(draft_id, user)
    
    if draft["status"] not in ["pending", "rejected"]:
        raise HTTPException(status_code=400, detail="Cannot edit approved or posted draft")
    
    # CRITICAL: Validate no links (Rule 2)
    is_valid, reason = validate_no_links(request.body)
    if not is_valid:
        raise HTTPException(status_code=400, detail=f"Draft contains links: {reason}")
    
    # Update draft
    await db.execute(
        """
        UPDATE drafts 
        SET body = $1, edited_by = $2, edited_at = NOW(), updated_at = NOW()
        WHERE id = $3
        """,
        request.body,
        user.id,
        draft_id
    )
    
    # Log training event (user edited)
    await log_training_event(
        draft_id=draft_id,
        event_type="draft_edited",
        user_id=user.id,
        data={"old_body": draft["body"], "new_body": request.body}
    )
    
    return {"success": True}
```

**4. Approve Draft**
```python
@router.post("/drafts/{draft_id}/approve")
async def approve_draft(
    draft_id: str,
    user = Depends(get_current_user)
):
    """
    Approve draft and enqueue for posting.
    """
    # Get draft
    draft = await get_draft(draft_id, user)
    
    if draft["status"] != "pending":
        raise HTTPException(status_code=400, detail=f"Draft is {draft['status']}, cannot approve")
    
    # CRITICAL: Check rate limits (Rule 6)
    is_eligible, reason = await check_post_eligibility(
        company_id=user.company_id,
        reddit_account_id=draft["reddit_account_id"],
        subreddit=draft["subreddit"]
    )
    
    if not is_eligible:
        raise HTTPException(status_code=429, detail=f"Rate limit exceeded: {reason}")
    
    # Update draft status
    await db.execute(
        """
        UPDATE drafts 
        SET status = 'approved', approved_by = $1, approved_at = NOW(), updated_at = NOW()
        WHERE id = $2
        """,
        user.id,
        draft_id
    )
    
    # Log training event
    await log_training_event(
        draft_id=draft_id,
        event_type="draft_approved",
        user_id=user.id,
        data={}
    )
    
    # Enqueue posting task
    task_id = await enqueue_post_task(draft_id)
    
    return {
        "success": True,
        "status": "approved",
        "task_id": task_id,
        "message": "Draft approved and queued for posting"
    }
```

**5. Reject Draft**
```python
@router.post("/drafts/{draft_id}/reject")
async def reject_draft(
    draft_id: str,
    request: RejectDraftRequest,
    user = Depends(get_current_user)
):
    """
    Reject draft with reason.
    """
    draft = await get_draft(draft_id, user)
    
    if draft["status"] not in ["pending", "approved"]:
        raise HTTPException(status_code=400, detail="Cannot reject this draft")
    
    # Update draft status
    await db.execute(
        """
        UPDATE drafts 
        SET status = 'rejected', rejected_by = $1, rejected_at = NOW(), 
            rejection_reason = $2, updated_at = NOW()
        WHERE id = $3
        """,
        user.id,
        request.reason,
        draft_id
    )
    
    # Log training event
    await log_training_event(
        draft_id=draft_id,
        event_type="draft_rejected",
        user_id=user.id,
        data={"reason": request.reason}
    )
    
    return {"success": True, "status": "rejected"}
```

#### Models
```python
# models/requests.py
from pydantic import BaseModel

class UpdateDraftRequest(BaseModel):
    body: str

class RejectDraftRequest(BaseModel):
    reason: str
```

**Verification**:
- [ ] Can list drafts with filters
- [ ] Pagination works correctly
- [ ] Can get single draft with full context
- [ ] Can update draft body
- [ ] Can approve draft (enqueues task)
- [ ] Can reject draft
- [ ] RLS enforced (can only see own company's drafts)

---

### Task 3.2: Inbox UI (Frontend)
**Time**: 6 hours  
**Priority**: Critical

#### Components

**1. Inbox Page**
```tsx
// app/inbox/page.tsx
import { DraftTable } from '@/components/inbox/DraftTable'
import { DraftCardList } from '@/components/inbox/DraftCardList'
import { FilterBar } from '@/components/inbox/FilterBar'

export default async function InboxPage({
  searchParams
}: {
  searchParams: { status?: string; risk?: string; keyword?: string; page?: string }
}) {
  const page = parseInt(searchParams.page || '1')
  const limit = 20
  const offset = (page - 1) * limit
  
  // Fetch drafts from API
  const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/api/drafts?${new URLSearchParams({
    status: searchParams.status || '',
    risk: searchParams.risk || '',
    keyword: searchParams.keyword || '',
    limit: limit.toString(),
    offset: offset.toString()
  })}`, {
    headers: {
      'Authorization': `Bearer ${getToken()}` // Get JWT from cookie
    }
  })
  
  const { drafts, total } = await response.json()
  
  return (
    <div className="container mx-auto px-4 py-6">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-3xl font-bold">Content Review</h1>
        <div className="text-sm text-gray-600">
          {drafts.length} of {total} drafts
        </div>
      </div>
      
      {/* Filters */}
      <FilterBar initialFilters={searchParams} />
      
      {/* Desktop: Table View */}
      <div className="hidden lg:block">
        <DraftTable drafts={drafts} />
      </div>
      
      {/* Mobile: Card View */}
      <div className="lg:hidden">
        <DraftCardList drafts={drafts} />
      </div>
      
      {/* Pagination */}
      <Pagination 
        currentPage={page}
        totalItems={total}
        itemsPerPage={limit}
      />
    </div>
  )
}
```

**2. Filter Bar**
```tsx
// components/inbox/FilterBar.tsx
'use client'

import { useRouter, useSearchParams } from 'next/navigation'
import { Select } from '@/components/ui/select'

export function FilterBar({ initialFilters }) {
  const router = useRouter()
  const searchParams = useSearchParams()
  
  const updateFilter = (key: string, value: string) => {
    const params = new URLSearchParams(searchParams)
    if (value) {
      params.set(key, value)
    } else {
      params.delete(key)
    }
    params.delete('page') // Reset to page 1
    router.push(`/inbox?${params.toString()}`)
  }
  
  return (
    <div className="flex flex-wrap gap-4 mb-6">
      <Select
        value={initialFilters.status || ''}
        onValueChange={(value) => updateFilter('status', value)}
      >
        <option value="">All Statuses</option>
        <option value="pending">Pending</option>
        <option value="approved">Approved</option>
        <option value="posted">Posted</option>
        <option value="rejected">Rejected</option>
      </Select>
      
      <Select
        value={initialFilters.risk || ''}
        onValueChange={(value) => updateFilter('risk', value)}
      >
        <option value="">All Risk Levels</option>
        <option value="low">Low Risk</option>
        <option value="medium">Medium Risk</option>
        <option value="high">High Risk</option>
      </Select>
      
      {/* TODO: Fetch and populate keyword/subreddit options from company data */}
    </div>
  )
}
```

**3. Draft Table (Desktop)**
```tsx
// components/inbox/DraftTable.tsx
import Link from 'next/link'
import { RiskBadge } from './RiskBadge'
import { StatusBadge } from './StatusBadge'

export function DraftTable({ drafts }) {
  return (
    <table className="w-full border-collapse">
      <thead className="bg-gray-50 border-b">
        <tr>
          <th className="text-left py-3 px-4">Subreddit</th>
          <th className="text-left py-3 px-4">Thread</th>
          <th className="text-left py-3 px-4">Keyword</th>
          <th className="text-left py-3 px-4">Risk</th>
          <th className="text-left py-3 px-4">Status</th>
          <th className="text-left py-3 px-4">Created</th>
          <th className="text-right py-3 px-4">Actions</th>
        </tr>
      </thead>
      <tbody>
        {drafts.map((draft) => (
          <tr key={draft.id} className="border-b hover:bg-gray-50">
            <td className="py-3 px-4">
              <span className="font-medium text-blue-600">r/{draft.subreddit}</span>
            </td>
            <td className="py-3 px-4 max-w-xs truncate">
              {draft.thread_title}
            </td>
            <td className="py-3 px-4">
              <span className="px-2 py-1 bg-gray-100 rounded text-sm">{draft.keyword}</span>
            </td>
            <td className="py-3 px-4">
              <RiskBadge risk={draft.risk} />
            </td>
            <td className="py-3 px-4">
              <StatusBadge status={draft.status} />
            </td>
            <td className="py-3 px-4 text-sm text-gray-600">
              {formatDistanceToNow(new Date(draft.created_at))} ago
            </td>
            <td className="py-3 px-4 text-right">
              <Link
                href={`/drafts/${draft.id}`}
                className="text-blue-600 hover:text-blue-800 font-medium"
              >
                View
              </Link>
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  )
}
```

**4. Draft Card List (Mobile)**
```tsx
// components/inbox/DraftCardList.tsx
import Link from 'next/link'
import { RiskBadge } from './RiskBadge'
import { StatusBadge } from './StatusBadge'

export function DraftCardList({ drafts }) {
  return (
    <div className="space-y-3">
      {drafts.map((draft) => (
        <Link
          key={draft.id}
          href={`/drafts/${draft.id}`}
          className="block bg-white rounded-lg border p-4 hover:shadow-md transition-shadow"
        >
          <div className="flex justify-between items-start mb-2">
            <span className="font-medium text-blue-600">r/{draft.subreddit}</span>
            <div className="flex gap-2">
              <RiskBadge risk={draft.risk} />
              <StatusBadge status={draft.status} />
            </div>
          </div>
          
          <h3 className="font-medium mb-2 line-clamp-2">
            {draft.thread_title}
          </h3>
          
          <div className="flex justify-between items-center text-sm text-gray-600">
            <span className="px-2 py-1 bg-gray-100 rounded">{draft.keyword}</span>
            <span>{formatDistanceToNow(new Date(draft.created_at))} ago</span>
          </div>
        </Link>
      ))}
    </div>
  )
}
```

**Verification**:
- [ ] Inbox displays drafts
- [ ] Filters work correctly
- [ ] Desktop table view works
- [ ] Mobile card view works
- [ ] Pagination works
- [ ] Can navigate to draft detail

---

### Task 3.3: Draft Detail View (Frontend)
**Time**: 6 hours  
**Priority**: Critical

```tsx
// app/drafts/[id]/page.tsx
'use client'

import { useEffect, useState } from 'react'
import { DraftEditor } from '@/components/drafts/DraftEditor'
import { ThreadContext } from '@/components/drafts/ThreadContext'
import { ApprovalControls } from '@/components/drafts/ApprovalControls'
import { useRouter } from 'next/navigation'

export default function DraftDetailPage({ params }: { params: { id: string } }) {
  const router = useRouter()
  const [draft, setDraft] = useState(null)
  const [loading, setLoading] = useState(true)
  const [editing, setEditing] = useState(false)
  
  useEffect(() => {
    fetchDraft()
  }, [params.id])
  
  const fetchDraft = async () => {
    const response = await fetch(`/api/drafts/${params.id}`, {
      headers: { 'Authorization': `Bearer ${getToken()}` }
    })
    const data = await response.json()
    setDraft(data)
    setLoading(false)
  }
  
  const handleUpdate = async (newBody: string) => {
    await fetch(`/api/drafts/${params.id}`, {
      method: 'PUT',
      headers: {
        'Authorization': `Bearer ${getToken()}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ body: newBody })
    })
    
    setDraft({ ...draft, body: newBody })
    setEditing(false)
  }
  
  const handleApprove = async () => {
    const response = await fetch(`/api/drafts/${params.id}/approve`, {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${getToken()}` }
    })
    
    if (response.ok) {
      router.push('/inbox?status=approved')
    } else {
      const error = await response.json()
      alert(error.detail) // TODO: Better error handling
    }
  }
  
  const handleReject = async (reason: string) => {
    await fetch(`/api/drafts/${params.id}/reject`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${getToken()}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ reason })
    })
    
    router.push('/inbox?status=rejected')
  }
  
  if (loading) return <div>Loading...</div>
  if (!draft) return <div>Draft not found</div>
  
  return (
    <div className="container mx-auto px-4 py-6">
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Left: Thread Context */}
        <ThreadContext draft={draft} />
        
        {/* Right: Draft Editor & Controls */}
        <div className="space-y-6">
          <DraftEditor
            body={draft.body}
            editing={editing}
            onEdit={() => setEditing(true)}
            onSave={handleUpdate}
            onCancel={() => setEditing(false)}
          />
          
          <ApprovalControls
            draft={draft}
            onApprove={handleApprove}
            onReject={handleReject}
            disabled={editing}
          />
        </div>
      </div>
    </div>
  )
}
```

**Verification**:
- [ ] Shows thread context (original post, comments, rules)
- [ ] Can edit draft body
- [ ] Can save changes
- [ ] Can approve draft
- [ ] Can reject draft with reason
- [ ] Mobile responsive

---

### Task 3.4: Posting Backend
**Time**: 8 hours  
**Priority**: **CRITICAL** (Enforces all hard rules)

```python
# services/post.py
from reddit.client import get_reddit_client
from reddit.encryption import decrypt_kms
from core.config import settings
import logging

logger = logging.getLogger(__name__)

async def post_to_reddit(draft_id: str) -> dict:
    """
    Post approved draft to Reddit.
    
    CRITICAL: This function enforces multiple hard rules:
    - Rule 1: Human approval required
    - Rule 2: No links in replies
    - Rule 6: Rate limiting
    - Rule 8: Verify post visibility
    - Rule 10: No posting in dev/staging
    """
    
    # Fetch draft
    draft = await db.fetchrow(
        """
        SELECT d.*, a.company_id, a.reddit_account_id, a.subreddit, a.thread_id
        FROM drafts d
        JOIN artifacts a ON d.artifact_id = a.id
        WHERE d.id = $1
        """,
        draft_id
    )
    
    if not draft:
        raise Exception(f"Draft {draft_id} not found")
    
    # RULE 1: Check approval
    if draft["status"] != "approved":
        raise Exception(f"Draft {draft_id} is not approved (status: {draft['status']})")
    
    if not draft["approved_by"]:
        raise Exception(f"Draft {draft_id} has no approver")
    
    # Check approval is recent (not stale)
    approval_age = (datetime.now() - draft["approved_at"]).total_seconds() / 3600
    if approval_age > 24:
        raise Exception(f"Approval expired ({approval_age:.1f} hours old)")
    
    # RULE 10: Check environment
    if settings.ENV != "prod":
        logger.warning(f"Posting disabled in {settings.ENV} environment, returning mock response")
        return await mock_post(draft)
    
    if not settings.ALLOW_POSTS:
        raise Exception("ALLOW_POSTS=false, posting disabled")
    
    # RULE 2: Validate no links (double-check, should have been checked earlier)
    is_valid, reason = validate_no_links(draft["body"])
    if not is_valid:
        raise Exception(f"Draft contains links: {reason}")
    
    # RULE 6: Check rate limits (should have been checked at approval, but double-check)
    is_eligible, reason = await check_post_eligibility(
        draft["company_id"],
        draft["reddit_account_id"],
        draft["subreddit"]
    )
    if not is_eligible:
        raise Exception(f"Rate limit exceeded: {reason}")
    
    # Get Reddit client
    reddit_client = await get_reddit_client(
        draft["company_id"],
        draft["reddit_account_id"]
    )
    
    # Post to Reddit
    logger.info(f"Posting draft {draft_id} to r/{draft['subreddit']}")
    
    try:
        result = await reddit_client.comment(
            thread_id=draft["thread_id"],
            body=draft["body"]
        )
        
        # Create post record
        post_id = str(uuid.uuid4())
        await db.execute(
            """
            INSERT INTO posts (
                id, draft_id, reddit_account_id, subreddit, thread_id,
                reddit_post_id, permalink, body, status, created_at
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'pending', NOW())
            """,
            post_id,
            draft_id,
            draft["reddit_account_id"],
            draft["subreddit"],
            draft["thread_id"],
            result["id"],
            result["permalink"],
            draft["body"]
        )
        
        # Update draft status
        await db.execute(
            "UPDATE drafts SET status = 'posted', posted_at = NOW() WHERE id = $1",
            draft_id
        )
        
        # RULE 8: Schedule verification
        await schedule_verification_task(post_id, delay_seconds=60)
        
        # Log training event
        await log_training_event(
            draft_id=draft_id,
            post_id=post_id,
            event_type="post_created",
            data={"reddit_post_id": result["id"], "permalink": result["permalink"]}
        )
        
        logger.info(f"Posted draft {draft_id} successfully: {result['permalink']}")
        
        return {
            "success": True,
            "post_id": post_id,
            "reddit_post_id": result["id"],
            "permalink": result["permalink"]
        }
        
    except Exception as e:
        logger.error(f"Failed to post draft {draft_id}: {e}")
        
        # Mark draft as failed
        await db.execute(
            "UPDATE drafts SET status = 'failed', error_message = $1 WHERE id = $2",
            str(e),
            draft_id
        )
        
        raise


async def mock_post(draft: dict) -> dict:
    """Mock post for dev/staging environments."""
    mock_id = f"mock_{uuid.uuid4().hex[:8]}"
    mock_permalink = f"/r/{draft['subreddit']}/comments/mock/test/{mock_id}"
    
    logger.info(f"[MOCK POST] Would post to r/{draft['subreddit']}: {draft['body'][:100]}...")
    
    # Create mock post record
    post_id = str(uuid.uuid4())
    await db.execute(
        """
        INSERT INTO posts (
            id, draft_id, reddit_account_id, subreddit, thread_id,
            reddit_post_id, permalink, body, status, is_mock, created_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'verified', true, NOW())
        """,
        post_id,
        draft["id"],
        draft["reddit_account_id"],
        draft["subreddit"],
        draft["thread_id"],
        mock_id,
        mock_permalink,
        draft["body"]
    )
    
    await db.execute(
        "UPDATE drafts SET status = 'posted', posted_at = NOW() WHERE id = $1",
        draft["id"]
    )
    
    return {
        "success": True,
        "post_id": post_id,
        "reddit_post_id": mock_id,
        "permalink": mock_permalink,
        "mock": True
    }


# Cloud Tasks handler
@router.post("/internal/post/{draft_id}")
async def post_task_handler(draft_id: str):
    """
    Cloud Tasks handler for posting.
    This endpoint is called by Cloud Tasks queue.
    """
    try:
        result = await post_to_reddit(draft_id)
        return result
    except Exception as e:
        logger.error(f"Post task failed for draft {draft_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))
```

**Verification**:
- [ ] All hard rules enforced (1, 2, 6, 8, 10)
- [ ] Posts successfully in production
- [ ] Mocks correctly in dev/staging
- [ ] Creates post record
- [ ] Schedules verification task
- [ ] Handles errors gracefully

---

### Task 3.5: Post Verification
**Time**: 3 hours  
**Priority**: Critical (Rule 8)

```python
# tasks/verify_post.py
import httpx
from core.config import settings
import logging

logger = logging.getLogger(__name__)

async def verify_post_visibility(post_id: str):
    """
    Verify post is visible on Reddit (not shadow-banned or removed).
    
    RULE 8: Must verify post visibility after posting.
    """
    # Get post
    post = await db.fetchrow(
        "SELECT * FROM posts WHERE id = $1",
        post_id
    )
    
    if not post:
        raise Exception(f"Post {post_id} not found")
    
    # Skip verification for mock posts
    if post["is_mock"]:
        logger.info(f"Skipping verification for mock post {post_id}")
        return
    
    # Wait a bit for Reddit to process
    await asyncio.sleep(30)
    
    # Fetch post as unauthenticated user
    reddit_post_id = post["reddit_post_id"]
    url = f"https://www.reddit.com/comments/{reddit_post_id}.json"
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                url,
                headers={"User-Agent": "Mozilla/5.0"}
            )
        
        if response.status_code == 404:
            # Post not found - likely removed or shadow-banned
            logger.warning(f"Post {post_id} returned 404, marking as removed")
            
            await db.execute(
                """
                UPDATE posts 
                SET status = 'removed', verified_at = NOW(), updated_at = NOW()
                WHERE id = $1
                """,
                post_id
            )
            
            # Notify user
            await notify_user_post_removed(post_id)
            
            # Log training event
            await log_training_event(
                post_id=post_id,
                event_type="post_removed",
                data={"reason": "404 response"}
            )
            
            return {"visible": False, "reason": "404"}
        
        data = response.json()
        comment_data = data[1]["data"]["children"][0]["data"]
        
        # Check for removal indicators
        if comment_data.get("removed"):
            logger.warning(f"Post {post_id} marked as removed")
            await db.execute(
                "UPDATE posts SET status = 'removed', verified_at = NOW() WHERE id = $1",
                post_id
            )
            await notify_user_post_removed(post_id)
            return {"visible": False, "reason": "removed flag"}
        
        if comment_data.get("spam"):
            logger.warning(f"Post {post_id} marked as spam")
            await db.execute(
                "UPDATE posts SET status = 'spam', verified_at = NOW() WHERE id = $1",
                post_id
            )
            await notify_user_post_removed(post_id)
            return {"visible": False, "reason": "spam flag"}
        
        # Post is visible!
        logger.info(f"Post {post_id} verified as visible")
        
        await db.execute(
            """
            UPDATE posts 
            SET status = 'verified', verified_at = NOW(), updated_at = NOW()
            WHERE id = $1
            """,
            post_id
        )
        
        # Log training event
        await log_training_event(
            post_id=post_id,
            event_type="post_verified",
            data={"score": comment_data.get("score", 0)}
        )
        
        return {"visible": True}
        
    except Exception as e:
        logger.error(f"Failed to verify post {post_id}: {e}")
        
        # Mark as verification failed
        await db.execute(
            "UPDATE posts SET status = 'verification_failed', error_message = $1 WHERE id = $1",
            str(e),
            post_id
        )
        
        raise


# Cloud Tasks handler
@router.post("/internal/verify-post/{post_id}")
async def verify_post_task_handler(post_id: str):
    """
    Cloud Tasks handler for post verification.
    """
    try:
        result = await verify_post_visibility(post_id)
        return result
    except Exception as e:
        logger.error(f"Verification task failed for post {post_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))


async def notify_user_post_removed(post_id: str):
    """
    Notify user that their post was removed.
    TODO: Implement email/in-app notification.
    """
    logger.info(f"TODO: Notify user about removed post {post_id}")
```

**Verification**:
- [ ] Verification runs 60 seconds after posting
- [ ] Correctly identifies visible posts
- [ ] Correctly identifies removed posts
- [ ] Updates post status
- [ ] Logs training events
- [ ] Handles errors gracefully

---

### Task 3.6: Cloud Tasks Integration
**Time**: 4 hours  
**Priority**: High

```python
# services/tasks.py
from google.cloud import tasks_v2
from google.protobuf import timestamp_pb2
from datetime import datetime, timedelta
from core.config import settings

task_client = tasks_v2.CloudTasksClient()

async def enqueue_post_task(draft_id: str) -> str:
    """
    Enqueue posting task with rate limiting.
    
    RULE 6: Use Cloud Tasks to enforce rate limits.
    """
    # Get draft info
    draft = await db.fetchrow(
        "SELECT reddit_account_id FROM drafts d JOIN artifacts a ON d.artifact_id = a.id WHERE d.id = $1",
        draft_id
    )
    
    # Get account's queue (one queue per account for rate limiting)
    queue_path = task_client.queue_path(
        settings.GOOGLE_PROJECT_ID,
        settings.GOOGLE_LOCATION,
        f"reddit-posts-{draft['reddit_account_id']}"
    )
    
    # Calculate delay based on last post
    last_post_time = await get_last_post_time(draft["reddit_account_id"])
    if last_post_time:
        minutes_since = (datetime.now() - last_post_time).total_seconds() / 60
        delay_seconds = max(0, (15 - minutes_since) * 60)  # 15 minute minimum gap
    else:
        delay_seconds = 0
    
    # Create task
    task = {
        "http_request": {
            "http_method": tasks_v2.HttpMethod.POST,
            "url": f"{settings.API_URL}/internal/post/{draft_id}",
            "headers": {
                "Content-Type": "application/json"
            }
        }
    }
    
    # Schedule task
    if delay_seconds > 0:
        schedule_time = timestamp_pb2.Timestamp()
        schedule_time.FromDatetime(datetime.now() + timedelta(seconds=delay_seconds))
        task["schedule_time"] = schedule_time
    
    # Create task
    response = task_client.create_task(parent=queue_path, task=task)
    
    logger.info(f"Enqueued post task for draft {draft_id}, delay: {delay_seconds}s")
    
    return response.name


async def schedule_verification_task(post_id: str, delay_seconds: int = 60):
    """
    Schedule post verification task.
    
    RULE 8: Must verify posts after posting.
    """
    queue_path = task_client.queue_path(
        settings.GOOGLE_PROJECT_ID,
        settings.GOOGLE_LOCATION,
        "verify-posts"
    )
    
    # Schedule task 60 seconds in the future
    schedule_time = timestamp_pb2.Timestamp()
    schedule_time.FromDatetime(datetime.now() + timedelta(seconds=delay_seconds))
    
    task = {
        "http_request": {
            "http_method": tasks_v2.HttpMethod.POST,
            "url": f"{settings.API_URL}/internal/verify-post/{post_id}",
        },
        "schedule_time": schedule_time
    }
    
    response = task_client.create_task(parent=queue_path, task=task)
    
    logger.info(f"Scheduled verification task for post {post_id}")
    
    return response.name
```

**Verification**:
- [ ] Tasks enqueue successfully
- [ ] Rate limiting enforced via queue delays
- [ ] Verification tasks schedule correctly
- [ ] Task handlers execute successfully

---

## Testing Checklist

### Unit Tests
- [ ] `test_list_drafts()` - Pagination, filters work
- [ ] `test_get_draft()` - Returns full context
- [ ] `test_update_draft()` - Validates no links
- [ ] `test_approve_draft()` - Checks rate limits
- [ ] `test_reject_draft()` - Logs event
- [ ] `test_post_to_reddit()` - Enforces all rules
- [ ] `test_verify_post_visibility()` - Detects removal

### Integration Tests
- [ ] Full flow: generate → inbox → approve → post → verify
- [ ] Rate limiting prevents over-posting
- [ ] Company isolation (can't see other company drafts)
- [ ] Environment gate (no posting in dev)

### E2E Tests
- [ ] User can see drafts in inbox
- [ ] User can filter drafts
- [ ] User can edit draft
- [ ] User can approve draft
- [ ] Post appears on Reddit (production only)
- [ ] Verification updates status correctly

---

## Deployment

1. Deploy backend to Cloud Run
2. Deploy frontend to Vercel
3. Create Cloud Tasks queues (via Terraform):
   - `reddit-posts-default`
   - `verify-posts`
4. Test in staging first (ALLOW_POSTS=false)
5. Enable posting in production (ALLOW_POSTS=true)

---

## Success Metrics

By end of M3:
- ✅ 100% of posts have human approval
- ✅ 0% of posts contain links
- ✅ Rate limits prevent over-posting
- ✅ 95%+ posts verified as visible
- ✅ Review flow takes <2 minutes per draft
- ✅ Mobile UI is fully functional

---

## Next Steps

After M3 complete, proceed to:
- **[M4-VOLUME-LEARNING.md](./M4-VOLUME-LEARNING.md)** - Scale to handle volume, collect training data

