#!/bin/bash

# Check Supabase Schema Status
# This script checks if required tables and triggers exist

echo "🔍 Checking Supabase Schema Status..."
echo ""

# Check if DB_CONN is set
if [ -z "$DB_CONN" ]; then
    echo "❌ Error: DB_CONN environment variable not set"
    echo "Please set it first:"
    echo "  export DB_CONN='postgresql://postgres:password@db.xxx.supabase.co:5432/postgres'"
    exit 1
fi

echo "📊 Checking tables..."
psql "$DB_CONN" -c "
SELECT 
    schemaname, 
    tablename 
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('companies', 'user_profiles', 'keywords', 'prompts')
ORDER BY tablename;
" 2>&1

echo ""
echo "🔧 Checking triggers..."
psql "$DB_CONN" -c "
SELECT 
    trigger_name,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created';
" 2>&1

echo ""
echo "📋 Checking user_profiles columns..."
psql "$DB_CONN" -c "
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'user_profiles'
ORDER BY ordinal_position;
" 2>&1

echo ""
echo "🔐 Checking RLS policies..."
psql "$DB_CONN" -c "
SELECT 
    tablename,
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies
WHERE schemaname = 'public'
AND tablename IN ('user_profiles', 'companies')
ORDER BY tablename, policyname;
" 2>&1

echo ""
echo "✅ Schema check complete!"

