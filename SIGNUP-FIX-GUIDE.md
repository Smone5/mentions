# Fixing Supabase Signup 500 Error

## Problem

Your signup is failing with a 500 error from Supabase. This happens because the database trigger that creates user profiles and companies on signup is either:
1. Not installed yet
2. Failing due to missing tables/columns
3. Blocked by Row Level Security (RLS) policies

## Quick Fix (Recommended)

### Step 1: Get Your Supabase Connection String

1. Go to [supabase.com/dashboard](https://supabase.com/dashboard)
2. Select your project
3. Go to **Settings → Database**
4. Under "Connection string", select **Transaction mode**
5. Copy the connection string (it looks like: `postgresql://postgres.[REF]:[PASSWORD]@aws-0-us-east-1.pooler.supabase.com:6543/postgres`)
6. Replace `[YOUR-PASSWORD]` with your actual database password

### Step 2: Set Environment Variable

```bash
export DB_CONN='postgresql://postgres.[YOUR-REF]:[YOUR-PASSWORD]@aws-0-us-east-1.pooler.supabase.com:6543/postgres'
```

### Step 3: Run the Fix Script

```bash
cd /Users/amelton/mentions
./scripts/fix-supabase-signup.sh
```

This will:
- Test your database connection
- Run the migration that fixes the signup trigger
- Verify the trigger is installed correctly

### Step 4: Test Signup

1. Go to your frontend: `http://localhost:3000/signup`
2. Fill out the signup form
3. Submit
4. You should now be redirected to check your email!

---

## Manual Fix (Alternative)

If the script doesn't work, you can run the migration manually:

### Option A: Using Supabase SQL Editor

1. Go to your Supabase Dashboard
2. Click on **SQL Editor** in the sidebar
3. Click **New Query**
4. Copy the entire contents of `mentions_backend/db/migrations/004_fix_user_signup_trigger.sql`
5. Paste into the SQL editor
6. Click **Run**

### Option B: Using psql Command Line

```bash
psql "$DB_CONN" -f mentions_backend/db/migrations/004_fix_user_signup_trigger.sql
```

---

## What the Migration Does

The migration:

1. **Fixes column conflicts** - Makes `company_id` nullable to allow the signup flow
2. **Adds missing columns** - Adds `full_name`, `phone_number`, `birthdate`, `sms_consent` to `user_profiles`
3. **Creates/fixes trigger** - Ensures `handle_new_user_signup()` function works correctly
4. **Sets up RLS policies** - Configures Row Level Security to allow user creation
5. **Adds error handling** - The trigger now logs errors to help debugging

---

## Verifying the Fix

### Check if trigger exists:

```bash
psql "$DB_CONN" -c "
SELECT trigger_name, event_object_table 
FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';
"
```

You should see:
```
     trigger_name      | event_object_table 
-----------------------+-------------------
 on_auth_user_created  | users
```

### Check user_profiles columns:

```bash
psql "$DB_CONN" -c "
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'user_profiles' 
AND column_name IN ('full_name', 'phone_number', 'birthdate', 'sms_consent');
"
```

You should see all four columns listed.

---

## Troubleshooting

### Error: "relation 'companies' does not exist"

You need to run the initial schema migration first:

```bash
psql "$DB_CONN" -f mentions_backend/db/migrations/001_initial_schema.sql
```

### Error: "permission denied for table auth.users"

Your database user doesn't have permission to create triggers on `auth.users`. You need to:

1. Go to Supabase Dashboard → SQL Editor
2. Run the migration there (it runs as the postgres superuser)

### Still getting 500 errors after migration

1. **Check Supabase Logs:**
   - Go to Dashboard → Logs
   - Look for errors during signup
   - The trigger now logs detailed error messages

2. **Verify email confirmation settings:**
   - Go to Dashboard → Authentication → Settings
   - Check "Enable email confirmations" setting
   - Make sure redirect URLs include your callback URL

3. **Check auth callback URL:**
   - Go to Dashboard → Authentication → URL Configuration  
   - Add: `http://localhost:3000/auth/callback`
   - For production, add your production URL too

### Email confirmation not arriving

This is separate from the 500 error. If signup succeeds but no email arrives:

1. Go to Dashboard → Authentication → Email Templates
2. Test the email provider configuration
3. Check your spam folder
4. For development, you can disable email confirmation temporarily:
   - Go to Authentication → Settings
   - Disable "Enable email confirmations"
   - Users will be able to log in immediately

---

## Understanding the Signup Flow

When a user signs up:

1. **Frontend** calls `supabase.auth.signUp()` with email, password, and metadata
2. **Supabase Auth** creates a new user in `auth.users` table
3. **Database Trigger** (`on_auth_user_created`) automatically:
   - Creates a new company
   - Creates a user_profile linked to that company
   - Sets the user as the company owner
4. **Email** is sent to user for verification (if enabled)
5. **Callback** handles the email verification link

The 500 error means step 3 is failing.

---

## Next Steps

After fixing signup:

1. **Test the full auth flow:**
   - Sign up with a new email
   - Check your email for verification link
   - Click the verification link
   - You should be redirected to `/dashboard`

2. **Check database:**
   ```bash
   psql "$DB_CONN" -c "
   SELECT u.email, up.full_name, c.name as company_name
   FROM auth.users u
   JOIN user_profiles up ON u.id = up.id
   JOIN companies c ON up.company_id = c.id;
   "
   ```

3. **If everything works**, commit your changes:
   ```bash
   git add mentions_backend/db/migrations/004_fix_user_signup_trigger.sql
   git add mentions_frontend/app/auth/callback/route.ts
   git add mentions_frontend/app/(auth)/login/page.tsx
   git commit -m "Fix signup 500 error with improved database trigger"
   ```

---

## Need More Help?

1. **Check Supabase Logs** - Most issues will show detailed error messages there
2. **Run diagnostic script:**
   ```bash
   ./scripts/check-supabase-schema.sh
   ```
3. **Check the error in browser console** - With the new error handling, you'll see specific error messages

---

## Files Changed

- ✅ `mentions_frontend/app/auth/callback/route.ts` - Added error handling
- ✅ `mentions_frontend/app/(auth)/login/page.tsx` - Shows error messages from failed auth
- ✅ `mentions_backend/db/migrations/004_fix_user_signup_trigger.sql` - Fixes database trigger
- ✅ `scripts/fix-supabase-signup.sh` - Automated fix script
- ✅ `scripts/check-supabase-schema.sh` - Diagnostic script

