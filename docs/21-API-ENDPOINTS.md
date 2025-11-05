# API Endpoints Reference

Complete backend API specification.

**Base URL**: `https://api.mentions.ai` (production)  
**Auth**: Bearer token (JWT from Supabase Auth)

---

## Authentication

### POST /api/auth/login
```typescript
Request: { email: string, password: string }
Response: { access_token: string, refresh_token: string, user: User }
```

### POST /api/auth/signup
```typescript
Request: { email: string, password: string, company_name: string }
Response: { access_token: string, user: User }
```

### GET /api/auth/me
```typescript
Response: { user: User }
```

---

## Companies

### GET /api/companies/:id
```typescript
Response: { id: string, name: string, goal: string }
```

### PUT /api/companies/:id
```typescript
Request: { name?: string, goal?: string }
Response: { success: true }
```

---

## Reddit Accounts

### GET /api/reddit-accounts
```typescript
Response: { accounts: Array<{ id: string, username: string, connected_at: string }> }
```

### POST /api/reddit-accounts/connect
Initiates Reddit OAuth flow

### DELETE /api/reddit-accounts/:id
Disconnects Reddit account

---

## Keywords

### GET /api/keywords
```typescript
Response: { keywords: Array<{ id: string, keyword: string, active: boolean }> }
```

### POST /api/keywords
```typescript
Request: { keyword: string }
Response: { id: string }
```

---

## Generation

### POST /api/generate
```typescript
Request: {
  keywords: string[],
  reddit_account_id: string,
  prompt_id?: string,
  company_goal: string
}
Response: {
  success: boolean,
  artifact_id?: string,
  error?: string,
  thread_id: string
}
```

---

## Drafts

### GET /api/drafts
```typescript
Query: { status?, risk?, keyword?, subreddit?, limit?, offset? }
Response: {
  drafts: Array<Draft>,
  total: number
}
```

### GET /api/drafts/:id
```typescript
Response: {
  id: string,
  body: string,
  risk: 'low' | 'medium' | 'high',
  status: 'pending' | 'approved' | 'rejected' | 'posted',
  artifact_id: string,
  thread_title: string,
  subreddit: string,
  created_at: string
}
```

### PUT /api/drafts/:id
```typescript
Request: { body: string }
Response: { success: true }
```

### POST /api/drafts/:id/approve
```typescript
Response: {
  success: true,
  status: 'approved',
  task_id: string
}
```

### POST /api/drafts/:id/reject
```typescript
Request: { reason: string }
Response: { success: true }
```

---

## Posts

### GET /api/posts
```typescript
Query: { status?, limit?, offset? }
Response: {
  posts: Array<Post>,
  total: number
}
```

### GET /api/posts/:id
```typescript
Response: {
  id: string,
  draft_id: string,
  reddit_post_id: string,
  permalink: string,
  status: 'pending' | 'verified' | 'removed',
  created_at: string,
  verified_at?: string
}
```

---

## RAG

### POST /api/rag/upload
```typescript
Content-Type: multipart/form-data
file: File
Response: { success: true, document_id: string }
```

### GET /api/rag/documents
```typescript
Response: {
  documents: Array<{
    id: string,
    filename: string,
    file_type: string,
    created_at: string
  }>
}
```

### DELETE /api/rag/documents/:id
```typescript
Response: { success: true }
```

---

## Prompts

### GET /api/prompts
```typescript
Response: { prompts: Array<Prompt> }
```

### POST /api/prompts
```typescript
Request: { name: string, body: string, temperature?: number }
Response: { id: string }
```

### PUT /api/prompts/:id
```typescript
Request: { body?: string, temperature?: number }
Response: { success: true }
```

---

## Analytics

### GET /api/analytics/overview
```typescript
Query: { days?: number }
Response: {
  total_posts: number,
  verified_posts: number,
  removed_posts: number,
  success_rate: number,
  approval_rate: number,
  top_subreddits: Array<{ subreddit: string, count: number }>,
  posts_by_day: Array<{ date: string, count: number }>
}
```

---

## Rate Limits

### GET /api/rate-limits/status
```typescript
Query: { account_id: string }
Response: {
  posts_today: number,
  daily_limit: number,
  remaining_today: number,
  next_eligible_at?: string,
  is_eligible: boolean
}
```

---

## Internal Endpoints (Cloud Tasks)

### POST /internal/post/:draft_id
Post draft to Reddit (called by Cloud Tasks)

### POST /internal/verify-post/:post_id
Verify post visibility (called by Cloud Tasks)

---

## Error Responses

```typescript
{
  detail: string,  // Error message
  status_code: number
}
```

**Common Status Codes**:
- 400: Bad Request (validation error)
- 401: Unauthorized (no/invalid token)
- 403: Forbidden (RLS violation)
- 404: Not Found
- 429: Too Many Requests (rate limit)
- 500: Internal Server Error

---

## Authentication

All endpoints (except /auth/*) require JWT:

```http
Authorization: Bearer eyJ...
```

Get token from Supabase Auth, passed to backend for validation.

---

## Complete API Documentation

See FastAPI auto-generated docs at `/docs` when backend is running:
```
http://localhost:8000/docs
```

**Reference**: [M1-FOUNDATIONS.md](./M1-FOUNDATIONS.md), [M3-REVIEW-UI.md](./M3-REVIEW-UI.md), [M4-VOLUME-LEARNING.md](./M4-VOLUME-LEARNING.md)

