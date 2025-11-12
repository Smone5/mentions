# Company Goal Fix

## Summary

The workflow is **working correctly now**! The "error" you're seeing is actually the AI judge doing its job - it's **rejecting** the subreddit because it doesn't know what your company does.

## The Issue

Your company `goal` and `description` are empty in the database. The AI judge cannot assess if r/manufacturing is appropriate for your company without knowing:
- What your company does
- What your goals are
- How you want to participate in Reddit communities

## The Fix (Completed)

✅ Updated `api/keywords.py` to fetch company goal and description from the database and pass them to the workflow

## What You Need to Do

You have two options:

### Option 1: Use the API directly (quick fix)

Update your company via the API:

```bash
# Get your access token from the browser (localStorage or Supabase session)
# Get your company ID from the database

curl -X PUT "http://localhost:8000/companies/YOUR_COMPANY_ID" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "goal": "Help manufacturing companies optimize their production processes and reduce costs",
    "description": "We provide AI-powered manufacturing optimization software that helps factories improve efficiency, reduce waste, and increase profitability."
  }'
```

### Option 2: Add a Company Settings UI (recommended)

Create a settings page in the frontend where you can manage:
- Company name
- Company goal
- Company description

## Testing After Fix

Once you've set your company goal and description:

1. Click **"Discover Now"** again on the `manufacturing` keyword
2. You should see the AI judge either:
   - ✅ **Approve** the subreddit (if it matches your goal)
   - ❌ **Reject** it with a **specific reason** related to your company goal

## Example Output (After Setting Company Goal)

**If approved:**
```
✓ Step 2: judge_subreddit
  └─ Subreddit ✓ suitable
```

**If rejected (with good reason):**
```
✓ Step 2: judge_subreddit
  └─ Subreddit ✗ not suitable
❌ Generation workflow FAILED at judge_subreddit: Subreddit rejected: 
   While r/manufacturing is relevant to manufacturing topics, it's a highly 
   professional community that discourages promotional content. Given your 
   company's goal of selling optimization software, this community is unlikely 
   to be receptive to your participation without extensive value-first, 
   non-promotional contributions.
```

## Why This Is Actually Good

The AI judge is **protecting you** from:
- Posting in inappropriate subreddits
- Getting banned for self-promotion
- Wasting time on communities that won't convert
- Damaging your brand reputation

It's doing exactly what it should do: being **conservative** and only approving subreddits where your company can provide genuine value and be well-received.

## Next Steps

1. Set your company goal and description (use Option 1 for now)
2. Try discovery again
3. If still rejected, try a different keyword that better matches your actual company offering
4. Implement Option 2 (Company Settings UI) for long-term usability

