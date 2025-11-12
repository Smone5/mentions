# Post Button Fix - Issue Resolution

## Problem
After approving a draft, the "Post to Reddit" button was not appearing on the draft detail page.

## Root Cause
The frontend was checking `draft.status === 'approved'` to determine when to show the Post button, but the backend was returning the approval status in a nested structure:

```json
{
  "id": "...",
  "body": "...",
  "approvals": [
    {
      "status": "approved",
      "approved_by": "...",
      "approved_at": "..."
    }
  ]
}
```

The frontend expected:
```json
{
  "id": "...",
  "body": "...",
  "status": "approved",
  "approvals": [...]
}
```

## Solution
Modified the backend to add a computed `status` field to draft objects in both endpoints:

### 1. List Drafts Endpoint (`GET /drafts`)
- Added logic to compute the status from the approvals array
- Status is set to the approval status if an approval exists, otherwise "pending"

### 2. Get Draft Endpoint (`GET /drafts/{draft_id}`)
- Added the same status computation logic
- Ensures the Post button appears after reloading the draft

### Code Changes
**File:** `mentions_backend/api/drafts.py`

Both `list_drafts()` and `get_draft()` now include:
```python
# Add computed status field
approvals = draft.get("approvals", [])
if approvals and len(approvals) > 0:
    draft["status"] = approvals[0].get("status", "pending")
else:
    draft["status"] = "pending"
```

## Testing
To verify the fix:
1. Navigate to a pending draft
2. Click "Approve"
3. The page will reload and show the "🚀 Post to Reddit" button
4. The status badge should show "approved" in green

## Status
✅ **FIXED** - Backend server restarted with changes applied

