# Workflow Visibility Update

## Summary

Fixed the LangGraph workflow issues and added comprehensive visibility so both you (the developer) and your users can see exactly what's happening during the discovery workflow.

## Changes Made

### 1. Fixed LangGraph PostgreSQL Connection Errors ✅

**Problems**: 
1. `Invalid connection type: <class 'psycopg2.extensions.connection'>`
2. `NotImplementedError` from `checkpointer.aget_tuple` - async operations not supported
3. `RuntimeError: asyncio.run() cannot be called from a running event loop`
4. `401 Unauthorized` on workflow status endpoint - Empty token issue

**Solutions**: 
- Installed `psycopg[binary,pool]>=3.2.0` (LangGraph requires psycopg3, not psycopg2)
- Switched to `AsyncPostgresSaver` for async workflow support
- Initialized checkpointer at app startup using FastAPI lifespan context manager
- Fixed token retrieval to use Supabase session instead of localStorage

**Files Modified**:
- `mentions_backend/requirements.txt` - Added psycopg3 with async pool support
- `mentions_backend/graph/checkpointer.py` - Split into `initialize_checkpointer()` and `get_checkpointer()`
- `mentions_backend/graph/build.py` - Removed asyncio.run, now just calls sync `get_checkpointer()`
- `mentions_backend/main.py` - Added lifespan handler to initialize checkpointer at startup
- `mentions_backend/api/workflow_status.py` - Token authentication via query param
- `mentions_frontend/app/dashboard/settings/keywords/page.tsx` - Get token from Supabase session

### 2. Added Detailed Backend Logging 📊

**What You See Now**:
When you run `cd mentions_backend && source venv/bin/activate && uvicorn main:app --reload`, you'll see detailed, emoji-enhanced logging like:

```
🚀 STARTING generation workflow for keyword: 'manufacturing'
   Keyword ID: 9629cd16-0cce-43e9-8587-94b352b21987
   Company ID: c6bee5f7-a8f0-46ba-b7f5-77546cbfe024
   User ID: 1a21b29c-9490-46ee-b66d-7beb0d43e517
   Thread ID: c6bee5f7-a8f0-46ba-b7f5-77546cbfe024:manufacturing:3a2f8b1c
📊 Building LangGraph workflow...
▶️  Executing workflow (this may take a few minutes)...
============================================================
✓ Step 1: fetch_subreddits
  └─ Found 5 subreddits
✓ Step 2: judge_subreddit
  └─ Subreddit ✓ suitable
✓ Step 3: fetch_threads
  └─ Found 10 threads
✓ Step 4: rank_threads
  └─ Ranked 10 threads
✓ Step 5: rag_retrieve
  └─ Retrieved 3 context chunks
✓ Step 6: draft_compose
  └─ Composed draft (342 chars)
✓ Step 7: vary_draft
  └─ Created 2 variations
✓ Step 8: judge_draft
  └─ Draft quality ✓ approved
✓ Step 9: emit_ready
  └─ Saved artifact and draft
============================================================
✅ Generation workflow COMPLETED successfully!
   Artifact ID: abc123...
   Draft ID: def456...
```

**Files Modified**:
- `mentions_backend/api/generate.py` - Enhanced with detailed step-by-step logging

### 3. Added Real-Time Status Updates for Users 🔄

**What Your Users See Now**:
When users click "Discover Now" on a keyword, they see a modal with:
- Spinning loader
- **Live status updates** showing exactly what the workflow is doing
- Real-time progress messages like:
  - "Starting discovery workflow for 'manufacturing'"
  - "Building LangGraph workflow..."
  - "Step 1: fetch_subreddits - Found 5 subreddits"
  - "Step 2: judge_subreddit - Subreddit suitable"
  - etc.

**How It Works**:
1. Backend streams workflow status via **Server-Sent Events (SSE)**
2. Frontend connects to `/workflow/status/{keyword_id}` endpoint
3. Status updates flow in real-time from backend to frontend
4. When workflow completes/fails, connection closes automatically

**New Files**:
- `mentions_backend/api/workflow_status.py` - SSE status streaming endpoint

**Files Modified**:
- `mentions_backend/main.py` - Registered workflow status router
- `mentions_backend/api/generate.py` - Calls `update_workflow_status()` at each step
- `mentions_backend/api/keywords.py` - Passes `keyword_id` to workflow
- `mentions_frontend/app/dashboard/settings/keywords/page.tsx` - Connects to SSE stream

## API Endpoints Added

### GET `/workflow/status/{keyword_id}`
Server-Sent Events stream providing real-time workflow status updates.

**Events**:
- `connected`: Initial connection established
- `starting`: Workflow initialization
- `building`: Building LangGraph
- `running`: Workflow executing (with step details)
- `completed`: Workflow finished successfully
- `failed`: Workflow encountered an error

**Example Usage** (Frontend):
```typescript
const sse = new EventSource(`${apiUrl}/workflow/status/${keywordId}`)

sse.onmessage = (event) => {
  const data = JSON.parse(event.data)
  console.log(data.status, data.details)
}
```

### GET `/workflow/status/{keyword_id}/current`
Get current workflow status (non-streaming) for polling-based clients.

## Testing the Changes

1. **Start Backend** (if not already running):
   ```bash
   cd /Users/amelton/mentions/mentions_backend
   source venv/bin/activate
   uvicorn main:app --reload
   ```

2. **Start Frontend** (if not already running):
   ```bash
   cd /Users/amelton/mentions/mentions_frontend
   npm run dev
   ```

3. **Test Workflow**:
   - Go to http://localhost:3000/dashboard/settings/keywords
   - Click "Discover Now" on any keyword
   - Watch the modal for live updates!
   - Check backend terminal for detailed logs

## Benefits

✅ **Developer Visibility**: Detailed logs in terminal show exactly what's happening at each step

✅ **User Visibility**: Real-time status updates in the UI keep users informed

✅ **Fixed Connection Error**: psycopg3 properly integrated with LangGraph

✅ **Better UX**: Users know the system is working and can see progress

✅ **Debugging**: Easy to identify which step is slow or failing

## Next Steps (Optional Improvements)

1. **Persist Status**: Store workflow status in database for history/debugging
2. **Progress Bar**: Convert step count to percentage-based progress bar
3. **Estimated Time**: Show estimated completion time based on historical data
4. **Notifications**: Send browser notification when workflow completes
5. **Retry Logic**: Add automatic retry on transient failures

## Technical Notes

- **SSE vs WebSockets**: Chose SSE for simplicity (one-way communication is sufficient)
- **In-Memory Storage**: Currently using `_workflow_updates` dict. For production with multiple servers, use Redis.
- **Authentication**: SSE endpoint requires authentication via existing auth middleware
- **Timeout**: Stream times out after 5 minutes to prevent zombie connections
- **Cleanup**: EventSource properly cleaned up on component unmount

---

**Status**: ✅ Complete and Ready to Test

**Date**: November 7, 2025

