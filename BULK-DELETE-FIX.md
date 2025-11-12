# Bulk Delete Fix - Foreign Key Constraint Error

## Problem
The bulk delete operation was failing with a foreign key constraint violation error:

```
APIError: {'message': 'update or delete on table "drafts" violates foreign key constraint "drafts_source_draft_id_fkey" on table "drafts"', 'code': '23503', 'details': 'Key (id)=(35646b5c-9785-42bd-aad9-512fe03b7e11) is still referenced from table "drafts".'}
```

This occurred when trying to delete drafts that had nested variations (variations of variations).

## Root Cause
The original implementation only deleted direct variations (children) of the selected drafts:

```python
# Delete variations first (drafts that reference these drafts as source)
supabase.table("drafts").delete().in_("source_draft_id", draft_ids).execute()
```

However, when a draft structure looked like this:
- Draft A (primary)
  - Draft B (variation of A)
    - Draft C (variation of B)

If you tried to bulk delete both A and B, the code would:
1. Try to delete B (as a variation of A)
2. But C still references B, causing a foreign key constraint violation

## Solution
Implemented recursive variation discovery before deletion:

1. **Recursively collect all variations**: Start with the requested draft IDs and repeatedly query for drafts that reference any draft we've found so far
2. **Continue until no more descendants**: Keep checking for child drafts until we find no new variations
3. **Delete all at once**: Delete approval records and all drafts (including all nested variations) in one operation

### Code Changes
**File:** `mentions_backend/api/drafts.py`

The `bulk_delete_drafts` function now:
```python
# Recursively find all variations (including nested ones)
all_draft_ids = set(draft_ids)
to_check = list(draft_ids)

while to_check:
    # Find all drafts that reference the current batch
    variations_response = supabase.table("drafts").select(
        "id"
    ).in_("source_draft_id", to_check).execute()
    
    # Get the IDs of variations
    variation_ids = [v["id"] for v in (variations_response.data or [])]
    
    # Filter to only new IDs we haven't seen yet
    new_ids = [vid for vid in variation_ids if vid not in all_draft_ids]
    
    if not new_ids:
        break
        
    # Add to our set and check their children next
    all_draft_ids.update(new_ids)
    to_check = new_ids
```

## Benefits
- **Handles nested variations**: Properly deletes drafts with any level of nesting
- **Prevents orphaned records**: Ensures all child drafts are deleted
- **Maintains data integrity**: Respects foreign key constraints
- **Better logging**: Reports both requested count and total deleted (including variations)

## Testing
To verify the fix works:
1. Create a draft with variations (edit it multiple times)
2. Select multiple drafts (including ones with variations)
3. Bulk delete them
4. Should succeed without foreign key errors

## Status
✅ **FIXED** - Backend server restarted with changes applied

