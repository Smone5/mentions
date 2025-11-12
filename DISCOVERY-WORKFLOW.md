# Discovery Workflow Guide

## Overview

The discovery workflow is now fully functional! You can manually trigger Reddit thread discovery and draft generation through the UI.

---

## How It Works

### The Discovery Process

1. **Trigger**: User clicks "Discover Now" button
2. **Search**: System searches Reddit for posts matching the keyword
3. **Judge**: LangGraph evaluates if subreddits are appropriate
4. **Generate**: Creates draft replies using AI
5. **Queue**: Drafts appear in Inbox for review
6. **Approve**: User reviews and approves drafts
7. **Post**: Approved drafts are posted to Reddit

---

## How to Use

### Option 1: Discover Individual Keywords

1. Navigate to **Dashboard → Settings → Keywords**
2. Click **"Discover Now"** button next to any keyword
3. System will:
   - Find relevant Reddit threads for that keyword
   - Generate draft replies
   - Add them to your Inbox
4. Check the "Last Check" column to see when discovery last ran

### Option 2: Discover All Keywords at Once

1. Go to the main **Dashboard** page
2. Click the **"🔍 Start Discovery"** button (top right)
3. System will trigger discovery for ALL active keywords
4. You'll see a confirmation showing how many keywords started

### Viewing Results

1. Go to **Dashboard → Inbox**
2. View all generated drafts
3. Filter by:
   - Status (pending/approved/rejected)
   - Risk level (low/medium/high)
   - Keyword
   - Subreddit
4. Click **Approve** to queue for posting
5. Click **Reject** if draft isn't suitable

---

## Dashboard Features

### Quick Stats
- **Pending Drafts**: Number of drafts waiting for review
- **Active Keywords**: Keywords currently being monitored
- **Connected Accounts**: Active Reddit accounts

### Getting Started Guide
- Appears automatically if you haven't:
  - Connected a Reddit account
  - Added keywords
- Shows step-by-step setup instructions

---

## Keywords Page Features

### Keyword Management
- **Add Keyword**: Enter keyword + priority level
- **Priority Levels**:
  - **High**: Most important keywords
  - **Normal**: Standard monitoring
  - **Low**: Background tracking
- **Active/Inactive Toggle**: Enable/disable keywords
- **Last Check**: Shows when discovery last ran for each keyword
- **Discover Now**: Manual trigger for individual keywords

---

## Prerequisites

Before running discovery, ensure you have:

1. ✅ **Connected Reddit Account**
   - Go to Settings → Reddit App → Configure
   - Add your Reddit app credentials
   - Connect your Reddit account via OAuth

2. ✅ **Added Keywords**
   - Go to Settings → Keywords
   - Add keywords you want to track
   - Set appropriate priority levels

3. ✅ **Company Details** (Optional but recommended)
   - Go to Settings → Company
   - Add company goal and description
   - Used to generate better, more relevant replies

---

## Technical Details

### Backend Endpoint

**POST** `/keywords/{keyword_id}/discover`

**What it does:**
1. Fetches keyword details
2. Gets company's active Reddit account
3. Retrieves company goal/description
4. Starts LangGraph generation workflow in background
5. Updates `last_discovered_at` timestamp

**Returns:**
```json
{
  "success": true,
  "message": "Discovery started for keyword: nextjs",
  "thread_id": "comp-123:nextjs:abc12345",
  "keyword": "nextjs"
}
```

### Frontend Components

**Dashboard** (`/dashboard/page.tsx`):
- Shows quick stats
- "Start Discovery" button for all keywords
- Getting started guide

**Keywords Page** (`/dashboard/settings/keywords/page.tsx`):
- Individual "Discover Now" buttons
- Shows last discovery time
- Keyword management

---

## Workflow Timeline

```
User clicks "Discover Now"
    ↓
Backend receives request (immediate)
    ↓
LangGraph workflow starts (background)
    ↓ (1-3 minutes)
Searches Reddit for threads
    ↓
Judges subreddit appropriateness (LLM)
    ↓
Generates draft replies (LLM)
    ↓
Saves drafts to database
    ↓
Drafts appear in Inbox (ready for review!)
```

**Expected Time**: 1-3 minutes per keyword

---

## Next Steps (Future Enhancements)

These are NOT yet implemented but documented in `/docs/34-SCHEDULED-DISCOVERY.md`:

### Scheduled Discovery
- **Cloud Scheduler**: Auto-discover every 2 hours
- **High Priority**: Every 15 minutes for important keywords
- **Cloud Tasks**: Queue system for rate limiting

### Monitoring
- Discovery metrics and dashboards
- Success/failure rates
- Alert system for failures

### Advanced Features
- Per-keyword discovery frequency
- Daily/weekly artifact limits
- Smart scheduling based on subreddit activity

---

## Troubleshooting

### "No active Reddit account found"
→ Connect a Reddit account in Settings → Reddit App

### Discovery started but no drafts appear
- Check LangGraph workflow logs in backend console
- Keyword might not have matching threads
- Subreddits might be filtered out by judge node

### "Failed to start discovery"
- Ensure backend is running (`http://localhost:8000`)
- Check user has `company_id` in database
- Verify Reddit account is properly connected

---

## Current Limitations

1. **Manual Only**: Discovery must be triggered manually (no scheduling yet)
2. **No Progress Indicator**: Can't see workflow progress in UI
3. **No History**: Can't see past discovery runs
4. **Rate Limiting**: No built-in rate limiting (be careful with multiple keywords)

---

## Summary

✅ **What Works Now:**
- Manual discovery trigger per keyword
- Bulk discovery for all keywords
- Discovery status tracking (last check time)
- Full LangGraph workflow integration
- Draft generation and review

🚧 **What's Coming Next:**
- Automated scheduled discovery
- Progress indicators
- Discovery history and analytics
- Better error handling and retry logic

---

## Questions?

Check the documentation:
- `/docs/10-LANGGRAPH-FLOW.md` - Generation workflow details
- `/docs/34-SCHEDULED-DISCOVERY.md` - Future scheduled discovery
- `/docs/12-POSTING-FLOW.md` - How drafts get posted

The system is ready to use! Start by adding keywords and clicking "Discover Now" to generate your first drafts.

