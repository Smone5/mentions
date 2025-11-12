# Draft Retry & Thread Fallback Implementation

## Overview
Implemented intelligent retry logic in the LangGraph workflow to handle draft rejections gracefully. The system now:
1. Retries draft composition with feedback when the judge rejects a draft
2. Falls back to trying different (more recent) threads if draft retries are exhausted
3. Provides detailed logging throughout the retry process

## Key Changes

### 1. State Management (`graph/state.py`)
Added retry tracking fields:
- `draft_retry_count: int` - Tracks draft rewrite attempts for current thread
- `draft_feedback: Optional[str]` - Stores judge's rejection reason for next attempt
- `thread_attempt_count: int` - Tracks how many threads we've tried
- `attempted_thread_ids: List[str]` - List of thread IDs already attempted

### 2. Judge Draft Node (`graph/nodes/judge_draft.py`)
**Retry Strategy:**
- **First 3 attempts**: Retry draft composition with feedback
- **After 3 draft failures**: Try a different thread (reset draft counter)
- **After 3 threads × 3 drafts = 9 attempts**: Hard stop with error

**Configuration:**
```python
MAX_DRAFT_RETRIES = 2  # 3 total attempts per draft
MAX_THREAD_ATTEMPTS = 3  # 3 total threads to try
```

**Behavior:**
- On rejection, captures judge feedback into state
- Increments `draft_retry_count` if retries remain
- Resets `draft_retry_count` and increments `thread_attempt_count` when switching threads
- Tracks attempted thread IDs to avoid retrying the same thread

### 3. Draft Compose Node (`graph/nodes/draft_compose.py`)
**Retry Behavior:**
- Detects when `draft_retry_count > 0` (retry scenario)
- Builds a `feedback_context` with the judge's rejection reason
- Passes feedback to LLM: "PREVIOUS ATTEMPT WAS REJECTED. Judge feedback: ..."
- LLM receives this context and addresses the issues in the new draft

### 4. LLM Client (`llm/client.py`)
**compose_draft Enhancement:**
- Added `feedback_context` parameter
- Appends feedback to the prompt when retrying
- Instructs the model to address previous rejection reasons

### 5. Rank Threads Node (`graph/nodes/rank_threads.py`)
**Thread Selection on Retry:**
- Filters out already-attempted threads using `attempted_thread_ids`
- Sorts threads by relevance score AND recency (via `created_utc`)
- **First attempt**: Randomly selects from top 3 (diversity)
- **Retry attempts**: Selects the best (most recent with highest score)
- Logs filtering and selection strategy

### 6. Workflow Routing (`graph/build.py`)
**New Routing Function: `should_retry_draft()`**
Three possible outcomes:
- `"retry_draft"` → Loop back to `draft_compose` (with feedback)
- `"retry_thread"` → Loop back to `rank_threads` (for new thread)
- `"continue"` → Proceed to `emit_ready` (draft approved)
- `"end"` → Stop workflow (max attempts exceeded)

**Logic:**
```python
if error:
    return "end"
if not draft_approved:
    if draft_retry_count > 0 and draft_feedback exists:
        return "retry_draft"  # Retry same thread
    else:
        return "retry_thread"  # Try new thread
return "continue"  # Approved
```

### 7. Workflow Initialization (`api/generate.py`)
Initialize retry counters in initial state:
```python
initial_state = {
    ...
    "draft_retry_count": 0,
    "thread_attempt_count": 0,
    "attempted_thread_ids": [],
}
```

## Workflow Flow

```
┌─────────────────┐
│ Fetch Threads   │
└────────┬────────┘
         ↓
┌─────────────────┐
│ Rank Threads    │◄──────────────┐
└────────┬────────┘               │
         ↓                         │ retry_thread
┌─────────────────┐               │ (new thread)
│ RAG Retrieve    │               │
└────────┬────────┘               │
         ↓                         │
┌─────────────────┐               │
│ Draft Compose   │◄─────┐        │
└────────┬────────┘      │        │
         ↓                │        │
┌─────────────────┐      │        │
│ Vary Draft      │      │        │
└────────┬────────┘      │        │
         ↓                │        │
┌─────────────────┐      │ retry_draft
│ Judge Draft     │──────┤ (with feedback)
└────────┬────────┘      │        │
         │                │        │
         ├────────────────┘        │
         │                         │
         ├─────────────────────────┘
         ↓
┌─────────────────┐
│ Emit Ready      │
└─────────────────┘
```

## Retry Scenarios

### Scenario 1: Draft Rejected, Retry with Feedback
```
1. Draft composed
2. Judge rejects: "Too promotional"
3. draft_retry_count: 0 → 1
4. draft_feedback: "Too promotional"
5. Loop to Draft Compose
6. New draft addresses feedback
7. Judge approves ✓
```

### Scenario 2: Multiple Draft Failures, Try New Thread
```
1. Thread A, Draft 1: Rejected "Too promotional"
2. Thread A, Draft 2: Rejected "Not answering question"
3. Thread A, Draft 3: Rejected "Low effort"
4. draft_retry_count exhausted (3 attempts)
5. thread_attempt_count: 0 → 1
6. attempted_thread_ids: ["thread_a"]
7. Loop to Rank Threads
8. Selects Thread B (filtered A, prefers recent)
9. Thread B, Draft 1: Approved ✓
```

### Scenario 3: Max Attempts Exhausted
```
1. 3 threads tried (A, B, C)
2. Each thread: 3 draft attempts
3. Total: 9 rejections
4. Error: "Failed after trying 3 threads. Last rejection: ..."
5. Workflow stops
```

## Benefits

1. **Resilience**: System doesn't give up after first rejection
2. **Learning**: Uses judge feedback to improve subsequent drafts
3. **Diversity**: Tries different threads if draft quality is the issue
4. **Recency**: Prefers more recent threads on retry
5. **Visibility**: Detailed logging shows retry strategy in action

## Configuration

Adjust retry limits in `graph/nodes/judge_draft.py`:
```python
MAX_DRAFT_RETRIES = 2  # Total: 3 attempts (0, 1, 2)
MAX_THREAD_ATTEMPTS = 3  # Total: 3 threads
```

## Testing

To test the retry logic:
1. Start a keyword discovery
2. Monitor logs for rejection messages
3. Observe retry attempts with feedback
4. Watch thread switching when draft retries exhausted
5. Verify new threads are more recent and not duplicated

## Future Enhancements

- [ ] Make retry limits configurable per company
- [ ] Track retry success rates in analytics
- [ ] Add retry attempt info to draft metadata
- [ ] Implement exponential backoff for API rate limiting
- [ ] Add retry history to workflow status events

