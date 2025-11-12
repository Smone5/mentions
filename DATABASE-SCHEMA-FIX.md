# Database Schema Fix - emit_ready Node

## Summary

Fixed the final workflow error where the `emit_ready` node was trying to insert data with column names that didn't match the actual database schema.

## The Error

```
Could not find the 'context_data' column of 'artifacts' in the schema cache
```

## Root Cause

The `emit_ready_node` was written for a different database schema than what actually exists. Specifically:

1. **Missing `context_data` column**: The node tried to insert a `context_data` JSON field, but the `artifacts` table doesn't have this column
2. **Wrong field names**: The node used field names like `keyword_id`, `version`, `status` that didn't match the actual schema
3. **Missing thread record**: The node didn't create a `threads` table record first (required foreign key)

## The Fix

Updated `/Users/amelton/mentions/mentions_backend/graph/nodes/emit_ready.py` to match the actual database schema from `001_initial_schema.sql`:

### Changes Made:

1. **Create or fetch thread record first** (required FK for artifacts table):
   ```python
   # Check if thread exists, create if not
   thread_result = supabase.table("threads").select("id").eq(
       "company_id", state["company_id"]
   ).eq("reddit_id", thread_reddit_id).execute()
   ```

2. **Map state fields to correct artifact table columns**:
   ```python
   artifact_data = {
       "id": artifact_id,
       "company_id": state["company_id"],
       "reddit_account_id": state["reddit_account_id"],
       "thread_id": thread_id_db,  # FK to threads table
       "subreddit": state["current_subreddit"],
       "keyword": state["keyword"],
       "company_goal": state.get("company_goal"),
       "thread_reddit_id": thread_reddit_id,
       "thread_title": state["thread_title"],
       "thread_body": state.get("thread_body"),
       "thread_url": f"https://reddit.com/comments/{thread_reddit_id}",
       "rules_summary": state.get("subreddit_rules"),  # JSONB
       "draft_primary": state["draft_body"],
       "draft_variants": state.get("draft_variations", []),  # text[]
       "rag_context": state.get("rag_contexts"),  # JSONB
       "judge_subreddit": judge_subreddit_data,  # JSONB
       "judge_draft": judge_draft_data,  # JSONB
       "status": "new",
   }
   ```

3. **Map state fields to correct drafts table columns**:
   ```python
   draft_data = {
       "id": draft_id,
       "artifact_id": artifact_id,
       "kind": "generated",  # Not "version"
       "text": state["draft_body"],  # Not "body"
       "risk": state.get("draft_risk_level", "medium"),  # Not "risk_level"
   }
   ```

4. **Save variations as linked drafts**:
   ```python
   # Each variation is a separate draft record linked via source_draft_id
   variation_data = {
       "id": variation_id,
       "artifact_id": artifact_id,
       "kind": "generated",
       "text": variation,
       "risk": state.get("draft_risk_level", "medium"),
       "source_draft_id": draft_id,  # Link to original
   }
   ```

## Actual Database Schema (from 001_initial_schema.sql)

### threads table:
```sql
CREATE TABLE threads (
  id uuid PRIMARY KEY,
  company_id uuid NOT NULL REFERENCES companies(id),
  subreddit text NOT NULL,
  reddit_id text NOT NULL,
  title text,
  body text,
  url text,
  author text,
  created_utc timestamptz,
  score int,
  num_comments int,
  discovered_at timestamptz DEFAULT now(),
  rank_score numeric,
  metadata jsonb
);
```

### artifacts table:
```sql
CREATE TABLE artifacts (
  id uuid PRIMARY KEY,
  company_id uuid NOT NULL REFERENCES companies(id),
  reddit_account_id uuid REFERENCES reddit_connections(id),
  thread_id uuid NOT NULL REFERENCES threads(id),
  subreddit text NOT NULL,
  keyword text NOT NULL,
  company_goal text,
  thread_reddit_id text NOT NULL,
  thread_title text,
  thread_body text,
  thread_url text,
  rules_summary jsonb,
  draft_primary text NOT NULL,
  draft_variants text[],
  rag_context jsonb,
  judge_subreddit jsonb,
  judge_draft jsonb,
  prompt_id uuid REFERENCES prompts(id),
  status text CHECK (status IN ('new','edited','approved','posted','failed')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
```

### drafts table:
```sql
CREATE TABLE drafts (
  id uuid PRIMARY KEY,
  artifact_id uuid NOT NULL REFERENCES artifacts(id) ON DELETE CASCADE,
  kind text CHECK (kind IN ('generated','edited')) DEFAULT 'generated',
  text text NOT NULL,
  source_draft_id uuid REFERENCES drafts(id),
  risk text CHECK (risk IN ('low', 'medium', 'high')),
  edit_meta jsonb,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamptz DEFAULT now()
);
```

## Testing

The server will automatically reload with the fix. Try clicking **"Discover Now"** again and the workflow should complete successfully!

You should see:
- ✅ All 10 steps complete
- ✅ Artifact saved to database
- ✅ Draft saved to database
- ✅ Variations saved as linked drafts
- ✅ "Workflow completed successfully!" message

## Next Steps

1. Test the workflow with your company goal set
2. Check the `artifacts` and `drafts` tables in Supabase to see your generated content
3. Build a UI to display these drafts in the "Inbox" for review

