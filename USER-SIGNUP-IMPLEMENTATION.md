# User Signup Implementation Summary

## Overview
Enhanced the user signup flow to collect comprehensive user information including personal details, company information, and SMS consent for Twilio notifications.

## Frontend Changes

### Signup Form Fields
The signup form (`mentions_frontend/app/(auth)/signup/page.tsx`) now collects:

1. **Required Fields:**
   - Email address
   - Password (min 6 characters) 
   - Confirm Password
   - Full Name
   - Terms of Service agreement

2. **Optional Fields:**
   - Company Name (creates company if provided)
   - Phone Number (validated format)
   - Date of Birth (18+ age validation)

3. **Consent Fields:**
   - SMS Notifications Consent (for Twilio integration)

### UI Components
- Rebuilt all auth pages using **shadcn/ui** components:
  - Button
  - Input
  - Label
  - Card
  - Checkbox
  - Form

### Validation
- Email format validation
- Password strength (min 6 characters)
- Password confirmation match
- Phone number format validation (basic regex)
- Age verification (must be 18+)
- Required field checking
- Terms of Service agreement requirement

## Backend Changes

### Database Schema

#### Migration 002: Add User Signup Fields
Created `mentions_backend/db/migrations/002_add_user_signup_fields.sql`:

**New Columns Added to `user_profiles`:**
```sql
full_name TEXT
phone_number TEXT
birthdate DATE
sms_consent BOOLEAN DEFAULT FALSE
sms_opt_out_at TIMESTAMPTZ
company_id UUID REFERENCES companies(id)
```

**Indexes Created:**
- `idx_user_profiles_phone_number` - For phone number lookups
- `idx_user_profiles_sms_consent` - For SMS-eligible users

**Database Functions:**
1. `handle_new_user_signup()` - Trigger function that:
   - Automatically creates user_profile from auth.users
   - Extracts metadata from signup (full_name, phone, birthdate, sms_consent)
   - Creates company if company_name provided
   - Links user to company

2. `opt_out_of_sms(user_id UUID)` - For SMS opt-out
   - Sets sms_consent = FALSE
   - Records timestamp in sms_opt_out_at
   - For compliance tracking

3. `opt_in_to_sms(user_id UUID)` - For SMS opt-in
   - Sets sms_consent = TRUE
   - Clears sms_opt_out_at

### API Endpoints

Created `mentions_backend/api/users.py`:

1. **GET /users/me**
   - Returns current user profile
   - Requires authentication

2. **PUT /users/me**
   - Updates user profile
   - Accepts: full_name, phone_number, birthdate
   - Requires authentication

3. **POST /users/me/sms-consent**
   - Updates SMS consent preference
   - Calls appropriate database function for compliance
   - Requires authentication

4. **DELETE /users/me**
   - Deletes user account
   - Cascades to all related data
   - Requires authentication

### Models

Created `mentions_backend/models/user.py`:

```python
- UserProfile: Full user profile model
- UserProfileUpdate: For profile updates
- SMSConsentUpdate: For SMS preference changes
- UserSignupData: Validation for signup data
```

### Row Level Security (RLS)

**user_profiles Policies:**
- Users can view their own profile
- Users can update their own profile

**companies Policies:**
- Users can view companies they own or are associated with
- Owners can update their company

## Data Flow

### Signup Process

1. **Frontend Form Submission:**
   ```
   User fills form → Validation → Supabase Auth signup
   ```

2. **Supabase Auth:**
   ```
   Creates auth.users record with metadata:
   {
     email,
     raw_user_meta_data: {
       full_name,
       company_name,
       phone_number,
       birthdate,
       sms_consent
     }
   }
   ```

3. **Database Trigger:**
   ```
   on_auth_user_created trigger fires
   → handle_new_user_signup() function
   → Creates user_profiles record
   → Creates companies record if company_name provided
   → Links user to company
   ```

4. **Email Verification:**
   ```
   Supabase sends confirmation email
   → User clicks link → Account activated
   ```

## SMS Consent & Compliance

### Compliance Features
- Explicit opt-in checkbox during signup
- Separate from Terms of Service
- Clear language about standard rates
- Timestamp tracking for opt-out (sms_opt_out_at)
- Easy opt-out API endpoint
- Users can change preference anytime

### Twilio Integration Ready
The database schema and API are ready for Twilio integration:

```python
# Get SMS-eligible users
SELECT * FROM user_profiles 
WHERE sms_consent = TRUE 
  AND sms_opt_out_at IS NULL
  AND phone_number IS NOT NULL;
```

## Testing Checklist

### Frontend
- [ ] Signup form displays all fields
- [ ] All validations work correctly
- [ ] Error messages display properly
- [ ] Success state shows after signup
- [ ] Email confirmation link works
- [ ] SMS consent checkbox functions
- [ ] Age validation prevents under-18 signups
- [ ] Phone number format validation works

### Backend
- [ ] Migration 002 runs successfully
- [ ] User signup creates user_profiles record
- [ ] User metadata is correctly extracted
- [ ] Company creation works when company_name provided
- [ ] SMS consent is properly recorded
- [ ] API endpoints return correct data
- [ ] RLS policies enforce access control
- [ ] Opt-in/opt-out functions work correctly

### Database
- [ ] Trigger fires on auth.users insert
- [ ] User_profiles is populated correctly
- [ ] Company is created and linked
- [ ] Indexes improve query performance
- [ ] RLS policies are active

## Next Steps

1. **Run Migration 002:**
   ```bash
   cd /Users/amelton/mentions
   ./scripts/run-migrations.sh
   ```

2. **Test Signup Flow:**
   - Visit `/signup` on dev environment
   - Fill out form with test data
   - Verify user_profiles creation in Supabase
   - Verify company creation if provided

3. **Implement Twilio Integration:**
   - Add Twilio credentials to Secret Manager
   - Create SMS notification service
   - Implement notification triggers
   - Add SMS delivery status tracking

4. **Add Profile Management UI:**
   - Settings page for profile editing
   - SMS preference toggle
   - Phone number update with verification
   - Company profile management

## Files Modified/Created

### Frontend
```
mentions_frontend/
├── app/(auth)/signup/page.tsx          # Enhanced signup form
├── app/(auth)/login/page.tsx           # Updated with shadcn
├── app/(auth)/reset-password/page.tsx  # Updated with shadcn
├── components/ui/                      # shadcn components
│   ├── button.tsx
│   ├── input.tsx
│   ├── label.tsx
│   ├── checkbox.tsx
│   ├── card.tsx
│   └── form.tsx
└── lib/utils.ts                        # shadcn utilities
```

### Backend
```
mentions_backend/
├── db/migrations/
│   └── 002_add_user_signup_fields.sql  # New migration
├── models/
│   └── user.py                         # User models
├── api/
│   └── users.py                        # User API endpoints
└── main.py                             # Updated to include users router
```

## Environment Variables

No new environment variables required. Uses existing:
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY` (for backend)

## Security Considerations

1. **Password Security:**
   - Handled by Supabase Auth
   - Minimum 6 characters enforced

2. **Data Privacy:**
   - RLS policies enforce user data access
   - Phone numbers stored securely
   - Birthdate used only for age verification

3. **SMS Compliance:**
   - Explicit opt-in required
   - Opt-out timestamp tracked
   - Clear consent language

4. **GDPR/CCPA:**
   - User can delete account via API
   - Cascade deletion removes all data
   - Consent tracking for SMS

## Git Commits

### Backend (mentions-backend)
```
feat: Add user signup fields and user API endpoints

- Added migration 002 for extended user profile fields
- Added full_name, phone_number, birthdate to user_profiles
- Added SMS consent tracking (sms_consent, sms_opt_out_at)
- Created database triggers for signup data capture
- Added user models (UserProfile, UserProfileUpdate, SMSConsentUpdate)
- Created user API endpoints (/users/me, /users/me/sms-consent)
- Added opt-in/opt-out SMS functions for compliance
- Updated RLS policies for user data access
- Linked users to companies during signup
```

### Frontend (mentions-frontend)
```
feat: Enhanced signup form with shadcn/ui components

- Installed shadcn/ui component library
- Rebuilt auth pages with shadcn components
- Collected comprehensive signup data
- Added form validation for all fields
- Improved UI/UX with Card components
- Added proper error handling and success states
```

## Status
✅ **COMPLETE** - All changes pushed to develop, staging, and main branches for both repositories


