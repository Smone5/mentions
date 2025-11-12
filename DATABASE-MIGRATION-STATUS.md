# Database Migration Status

## Summary
✅ **ALL MIGRATIONS COMPLETED SUCCESSFULLY**

Date: November 7, 2024

## Migrations Run

### Migration 001: Initial Schema
**Status:** ✅ Complete (Previously run)
- All core tables created
- Extensions enabled (vector, uuid-ossp)
- Indexes created
- Initial RLS policies applied

### Migration 002: User Signup Fields
**Status:** ✅ Complete
- Added user profile fields:
  - `full_name TEXT`
  - `phone_number TEXT`
  - `birthdate DATE`
  - `sms_consent BOOLEAN DEFAULT FALSE`
  - `sms_opt_out_at TIMESTAMPTZ`
  - `company_id UUID`

- Created database functions:
  - `handle_new_user_signup()` - Trigger function for new user creation
  - `opt_out_of_sms(user_id UUID)` - SMS opt-out with compliance tracking
  - `opt_in_to_sms(user_id UUID)` - SMS opt-in

- Created trigger:
  - `on_auth_user_created` - Automatically creates user_profiles and companies on signup

- Created indexes:
  - `idx_user_profiles_phone_number` - For phone lookups
  - `idx_user_profiles_sms_consent` - For SMS-eligible users

- Created RLS policies:
  - Users can view own profile
  - Users can update own profile

### Migration 003: Company Owner Column
**Status:** ✅ Complete
- Added `owner_id UUID` column to companies table
- Created index `idx_companies_owner`
- Fixed RLS policies for companies:
  - Users can view own company
  - Owners can update company
  - Owners can delete company

## Database Connection
- **Host:** db.mjsxwzpxzalhgkekseyo.supabase.co
- **Database:** postgres
- **User:** postgres
- **Extensions:** vector, uuid-ossp

## Tables Created (26 total)

### Core Tables
- ✅ companies
- ✅ user_profiles
- ✅ keywords
- ✅ prompts

### Reddit Integration
- ✅ company_reddit_apps
- ✅ reddit_connections
- ✅ posting_eligibility

### RAG / Knowledge Base
- ✅ company_docs
- ✅ company_doc_chunks

### Discovery & Threading
- ✅ subreddit_history
- ✅ threads
- ✅ artifacts

### Draft & Approval
- ✅ drafts
- ✅ approvals

### Posting
- ✅ posts
- ✅ moderation_events
- ✅ subreddit_feedback
- ✅ subreddit_accounts

### Learning & Fine-tuning
- ✅ training_events
- ✅ fine_tuning_jobs
- ✅ fine_tuning_exports

### Billing
- ✅ subscriptions
- ✅ plan_limits
- ✅ invoices

### LangGraph State
- ✅ langgraph_checkpoints
- ✅ langgraph_checkpoint_writes

## Verification

### User Profiles Table Structure
```sql
Column             | Type         | Description
-------------------|--------------|------------------------------------------
id                 | UUID         | Primary key, references auth.users(id)
company_id         | UUID         | References companies(id)
role               | TEXT         | User role (owner/admin/member)
full_name          | TEXT         | User's full name
phone_number       | TEXT         | Phone number for SMS
birthdate          | DATE         | Date of birth (18+ required)
sms_consent        | BOOLEAN      | SMS notification consent
sms_opt_out_at     | TIMESTAMPTZ  | When user opted out (compliance)
created_at         | TIMESTAMPTZ  | Creation timestamp
updated_at         | TIMESTAMPTZ  | Last update timestamp
```

### Companies Table Structure
```sql
Column             | Type         | Description
-------------------|--------------|------------------------------------------
id                 | UUID         | Primary key
name               | TEXT         | Company name
owner_id           | UUID         | References user_profiles(id)
created_at         | TIMESTAMPTZ  | Creation timestamp
updated_at         | TIMESTAMPTZ  | Last update timestamp
```

## Signup Flow Verification

### Expected Flow:
1. User submits signup form with:
   - Email, password (required)
   - Full name (required)
   - Company name (optional)
   - Phone number (optional)
   - Birthdate (optional)
   - SMS consent (optional)

2. Supabase Auth creates `auth.users` record with metadata

3. Trigger `on_auth_user_created` fires:
   - Creates `user_profiles` record
   - If company_name provided, creates `companies` record
   - Links user to company via `company_id`

4. Email verification sent

5. User confirms email

6. Account active

### Test Signup Data:
```json
{
  "email": "test@example.com",
  "password": "test123",
  "full_name": "Test User",
  "company_name": "Test Company",
  "phone_number": "+1 (555) 123-4567",
  "birthdate": "1990-01-01",
  "sms_consent": true
}
```

## API Endpoints Available

### User Profile Management
- `GET /users/me` - Get current user profile
- `PUT /users/me` - Update user profile
- `POST /users/me/sms-consent` - Update SMS consent
- `DELETE /users/me` - Delete account

## RLS Policies Active

### user_profiles
- ✅ Users can view own profile
- ✅ Users can update own profile

### companies
- ✅ Users can view companies they own or are associated with
- ✅ Owners can update their company
- ✅ Owners can delete their company

## Next Steps

1. **Test Signup Flow:**
   ```bash
   # Go to frontend /signup page
   # Fill out form
   # Check Supabase dashboard for:
   #   - auth.users record
   #   - user_profiles record
   #   - companies record (if company name provided)
   ```

2. **Test API Endpoints:**
   ```bash
   # After login, test:
   GET /users/me
   PUT /users/me (update phone/birthdate)
   POST /users/me/sms-consent (toggle SMS)
   ```

3. **Verify SMS Consent Query:**
   ```sql
   -- Get all users eligible for SMS
   SELECT id, email, full_name, phone_number, sms_consent, sms_opt_out_at
   FROM user_profiles
   WHERE sms_consent = TRUE 
     AND sms_opt_out_at IS NULL
     AND phone_number IS NOT NULL;
   ```

4. **Implement Twilio Integration:**
   - Add Twilio credentials to Secret Manager
   - Create SMS notification service in backend
   - Add notification triggers
   - Track SMS delivery status

## Warnings Encountered

### Non-Critical Warnings:
```
WARNING: invalid configuration parameter name "supautils.disable_program"
DETAIL: "supautils" is now a reserved prefix.
```

**Resolution:** This is a Supabase internal warning that can be safely ignored. It doesn't affect functionality.

## Files

### Migration Files
- `/mentions_backend/db/migrations/001_initial_schema.sql`
- `/mentions_backend/db/migrations/002_add_user_signup_fields.sql`
- `/mentions_backend/db/migrations/003_add_company_owner.sql`

### Backend Code
- `/mentions_backend/models/user.py` - User models
- `/mentions_backend/api/users.py` - User API endpoints
- `/mentions_backend/main.py` - FastAPI app with user routes

### Frontend Code
- `/mentions_frontend/app/(auth)/signup/page.tsx` - Enhanced signup form
- `/mentions_frontend/app/(auth)/login/page.tsx` - Login page
- `/mentions_frontend/contexts/AuthContext.tsx` - Auth context

## Git Status
✅ All changes committed and pushed to develop, staging, and main branches
- Backend: commit `6c9a52d` + owner fix
- Frontend: commit `0a66877`

---

**Status:** ✅ COMPLETE - Ready for testing and Twilio integration


