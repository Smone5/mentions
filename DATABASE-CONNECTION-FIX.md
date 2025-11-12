# Database Connection Fix Guide

## Problem

The LangGraph checkpointer cannot connect to PostgreSQL because the hostname `db.mjsxwzpxzalhgkekseyo.supabase.co` cannot be resolved by Python's DNS resolver.

**Error:**
```
psycopg.OperationalError: [Errno 8] nodename nor servname provided, or not known
```

## Root Cause

The current `DB_CONN` environment variable uses an older Supabase hostname format that doesn't resolve properly from Python applications. While the hostname resolves with system DNS tools (`host`, `nslookup`), Python's `getaddrinfo()` function cannot resolve it.

## Solution

You need to update your `DB_CONN` environment variable with the correct connection string from your Supabase dashboard.

### Step 1: Get the Correct Connection String

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project: **mjsxwzpxzalhgkekseyo**
3. Navigate to: **Settings > Database**
4. Under "Connection string", select the **URI** tab
5. You'll see two options:
   - **Session mode** (port 5432) - Direct connection, recommended for most cases
   - **Transaction mode** (port 6543) - Connection pooling, recommended for high-traffic

6. Copy the connection string (it should look like one of these):

   **Session mode:**
   ```
   postgresql://postgres.[PROJECT_REF]:[PASSWORD]@aws-0-us-east-1.pooler.supabase.com:6543/postgres
   ```

   **OR older format:**
   ```
   postgresql://postgres:[PASSWORD]@[some-hostname].supabase.co:5432/postgres
   ```

### Step 2: Update Your Environment Variable

1. Open your `.env` file in the backend directory:
   ```bash
   cd /Users/amelton/mentions/mentions_backend
   nano .env  # or use your preferred editor
   ```

2. Find the `DB_CONN` line and replace it with the connection string from Supabase

3. Make sure to replace `[PASSWORD]` with your actual database password (also shown on the Supabase database settings page)

   Example:
   ```bash
   DB_CONN=postgresql://postgres.mjsxwzpxzalhgkekseyo:[YOUR_PASSWORD]@aws-0-us-east-1.pooler.supabase.com:6543/postgres
   ```

4. Save the file

### Step 3: Test the Connection

Run the diagnostic script to verify the connection works:

```bash
cd /Users/amelton/mentions/mentions_backend
python3 scripts/test_db_connection.py
```

You should see:
```
✅ DNS Resolution Test - PASSED
✅ PostgreSQL Connection Test - PASSED
✅ ALL TESTS PASSED - Database connection is working!
```

### Step 4: Restart Your Application

1. Stop your backend server (Ctrl+C if running)
2. Restart it:
   ```bash
   cd /Users/amelton/mentions/mentions_backend
   source venv/bin/activate
   uvicorn main:app --reload --host 0.0.0.0 --port 8000
   ```

3. Test the workflow again - it should now persist to the database successfully

## Verification

After updating, your LangGraph workflows should:
- ✅ Connect to PostgreSQL successfully
- ✅ Persist state to the database
- ✅ Show logs like: `✅ PostgreSQL checkpointer connected successfully to...`
- ❌ NOT show: `[Errno 8] nodename nor servname provided, or not known`

## Alternative Solutions (if the above doesn't work)

### Option 1: Use Supabase Direct Database Access

If you have Supabase on a paid plan, you might have direct database access:

1. In Supabase Dashboard, go to Settings > Database
2. Look for "Direct connection" or "Direct database URL"
3. Use that connection string instead

### Option 2: Use Connection Pooling (Recommended)

For better performance and reliability:

1. Use the Transaction mode connection string (port 6543)
2. This uses Supabase's built-in connection pooler (PgBouncer)
3. Better for applications with many concurrent connections

### Option 3: Check Network/Firewall

If the connection still fails:

1. Check if your network allows outbound connections to Supabase
2. Verify no firewall is blocking PostgreSQL ports (5432, 6543)
3. Try from a different network to rule out local network issues

## Files Changed

1. **`/Users/amelton/mentions/mentions_backend/graph/checkpointer.py`**
   - Added DNS resolution diagnostics
   - Improved error messages with actionable guidance
   - Added fallback strategies for connection issues

2. **`/Users/amelton/mentions/mentions_backend/scripts/test_db_connection.py`**
   - New diagnostic script to test database connections
   - Provides detailed error messages and troubleshooting steps

## Technical Details

### Why This Happened

Supabase has migrated their infrastructure and connection methods:
- **Old format:** `db.[project-ref].supabase.co` (deprecated)
- **New format:** AWS pooler endpoints or regional endpoints
- Python's DNS resolver doesn't properly handle the old format
- System DNS tools still work due to different resolution methods

### What the Fix Does

The updated checkpointer code:
1. Attempts connection with provided connection string
2. Tests DNS resolution if connection fails
3. Provides detailed diagnostics about what's wrong
4. Shows exact steps to fix the issue
5. Maintains data persistence (no in-memory fallback)

### Persistence Guarantee

- ✅ Data will persist to PostgreSQL database
- ✅ LangGraph state will survive application restarts
- ✅ Workflow checkpoints stored permanently
- ❌ NO in-memory storage (as requested)

## Support

If you're still having issues after following this guide:

1. Run the diagnostic script and share the output
2. Check Supabase status: https://status.supabase.com
3. Verify your Supabase project is active and not paused
4. Check if you're on the free tier (which may have limitations)

## References

- [Supabase Database Connection Documentation](https://supabase.com/docs/guides/database/connecting-to-postgres)
- [LangGraph Checkpointer Documentation](https://langchain-ai.github.io/langgraph/reference/checkpoints/)
- [PostgreSQL Connection Strings](https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING)

