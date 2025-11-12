#!/bin/bash
# Vercel Setup Helper Script
# Guides you through setting up Vercel projects

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo "=========================================="
echo "  Vercel Setup Helper"
echo "=========================================="
echo ""

echo -e "${BLUE}This script will guide you through Vercel setup.${NC}"
echo ""
echo "You need to:"
echo "  1. Go to https://vercel.com and sign in"
echo "  2. Create three projects (or use environments)"
echo "  3. Configure environment variables"
echo ""

read -p "Have you created your Vercel account? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please create a Vercel account first at https://vercel.com"
    exit 0
fi

echo ""
echo -e "${BLUE}Step 1: Create Projects${NC}"
echo ""
echo "Create three projects in Vercel:"
echo "  1. mentions-dev (Development)"
echo "  2. mentions-staging (Staging/Testing)"
echo "  3. mentions-prod (Production)"
echo ""
echo "Or use one project with three environments:"
echo "  - Development (for dev branch)"
echo "  - Preview (for staging branches)"
echo "  - Production (for main branch)"
echo ""

read -p "Have you created the projects? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Please create projects in Vercel, then run this script again."
    exit 0
fi

echo ""
echo -e "${BLUE}Step 2: Environment Variables${NC}"
echo ""

# Get current values from .env.local if it exists
if [ -f ".env.local" ]; then
    echo "Found .env.local file. Current values:"
    grep "NEXT_PUBLIC" .env.local | sed 's/=.*/=***/' || echo "No NEXT_PUBLIC variables found"
    echo ""
fi

echo "For each environment, you need to set these variables in Vercel:"
echo ""
echo "Required Variables:"
echo "  - NEXT_PUBLIC_ENV (dev/staging/prod)"
echo "  - NEXT_PUBLIC_SUPABASE_URL"
echo "  - NEXT_PUBLIC_SUPABASE_ANON_KEY"
echo "  - NEXT_PUBLIC_API_URL"
echo ""

echo -e "${YELLOW}Development Environment:${NC}"
echo "  NEXT_PUBLIC_ENV=dev"
if [ -f ".env.local" ]; then
    SUPABASE_URL=$(grep "NEXT_PUBLIC_SUPABASE_URL" .env.local | cut -d '=' -f2)
    SUPABASE_KEY=$(grep "NEXT_PUBLIC_SUPABASE_ANON_KEY" .env.local | cut -d '=' -f2)
    if [ -n "$SUPABASE_URL" ]; then
        echo "  NEXT_PUBLIC_SUPABASE_URL=$SUPABASE_URL"
    fi
    if [ -n "$SUPABASE_KEY" ]; then
        echo "  NEXT_PUBLIC_SUPABASE_ANON_KEY=$SUPABASE_KEY"
    fi
fi
echo "  NEXT_PUBLIC_API_URL=http://localhost:8000  # Or dev Cloud Run URL"
echo ""

echo -e "${YELLOW}Staging Environment:${NC}"
echo "  NEXT_PUBLIC_ENV=staging"
echo "  NEXT_PUBLIC_SUPABASE_URL=https://xxx-staging.supabase.co  # Staging Supabase"
echo "  NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...  # Staging anon key"
echo "  NEXT_PUBLIC_API_URL=https://backend-staging-xxx.run.app  # Staging backend"
echo ""

echo -e "${YELLOW}Production Environment:${NC}"
echo "  NEXT_PUBLIC_ENV=prod"
echo "  NEXT_PUBLIC_SUPABASE_URL=https://xxx-prod.supabase.co  # Production Supabase"
echo "  NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...  # Production anon key"
echo "  NEXT_PUBLIC_API_URL=https://backend-prod-xxx.run.app  # Production backend"
echo ""

echo ""
echo -e "${BLUE}Step 3: Configure in Vercel Dashboard${NC}"
echo ""
echo "For each project:"
echo "  1. Go to Project Settings → Environment Variables"
echo "  2. Add each variable"
echo "  3. Select which environments to apply to:"
echo "     - Development: Development environment"
echo "     - Staging: Preview environment"
echo "     - Production: Production environment"
echo ""

read -p "Have you configured environment variables in Vercel? (y/n) " -n 1 -r
echo

echo ""
echo -e "${BLUE}Step 4: Update Supabase Redirect URLs${NC}"
echo ""
echo "For each Supabase project, add Vercel deployment URLs:"
echo ""
echo "Development:"
echo "  - Site URL: https://mentions-dev.vercel.app"
echo "  - Redirect URL: https://mentions-dev.vercel.app/auth/callback"
echo ""
echo "Staging:"
echo "  - Site URL: https://mentions-staging.vercel.app"
echo "  - Redirect URL: https://mentions-staging.vercel.app/auth/callback"
echo ""
echo "Production:"
echo "  - Site URL: https://mentions-prod.vercel.app (or your custom domain)"
echo "  - Redirect URL: https://mentions-prod.vercel.app/auth/callback"
echo ""

read -p "Have you updated Supabase redirect URLs? (y/n) " -n 1 -r
echo

echo ""
echo "=========================================="
echo -e "${GREEN}Vercel Setup Complete!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Trigger a deployment (push to GitHub or deploy manually)"
echo "  2. Verify deployment works"
echo "  3. Test authentication flow"
echo "  4. Build authentication system"
echo ""

