#!/bin/bash

# Fix Supabase Signup Issues
# This script runs the migration to fix the signup trigger

set -e

echo "🔧 Fixing Supabase Signup Configuration..."
echo ""

# Check if DB_CONN is set
if [ -z "$DB_CONN" ]; then
    echo "❌ Error: DB_CONN environment variable not set"
    echo ""
    echo "Please set your Supabase connection string:"
    echo ""
    echo "  export DB_CONN='postgresql://postgres.[YOUR-PROJECT-REF]:[YOUR-PASSWORD]@aws-0-us-east-1.pooler.supabase.com:6543/postgres'"
    echo ""
    echo "You can find this in your Supabase dashboard:"
    echo "  1. Go to https://supabase.com/dashboard"
    echo "  2. Select your project"
    echo "  3. Go to Settings → Database"
    echo "  4. Copy the 'Connection string' (Transaction mode)"
    echo ""
    exit 1
fi

echo "📍 Database: $DB_CONN"
echo ""

# Test connection
echo "🔌 Testing database connection..."
if ! psql "$DB_CONN" -c "SELECT 1" > /dev/null 2>&1; then
    echo "❌ Failed to connect to database"
    echo "Please check your DB_CONN string"
    exit 1
fi
echo "✅ Connected successfully"
echo ""

# Run the fix migration
echo "🚀 Running migration 004_fix_user_signup_trigger.sql..."
psql "$DB_CONN" -f mentions_backend/db/migrations/004_fix_user_signup_trigger.sql

echo ""
echo "✅ Migration complete!"
echo ""
echo "📋 Verifying trigger installation..."
psql "$DB_CONN" -c "
SELECT 
    trigger_name,
    event_object_table,
    action_timing,
    event_manipulation
FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created';
"

echo ""
echo "🎉 Signup should now work! Try signing up again."
echo ""
echo "If you still have issues, check the logs:"
echo "  1. Go to your Supabase dashboard"
echo "  2. Click on 'Logs' in the sidebar"
echo "  3. Look for any errors during signup"

