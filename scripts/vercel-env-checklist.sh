#!/bin/bash
# Vercel Environment Setup Checklist
# Interactive guide for setting up Vercel environments

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo "=========================================="
echo "  Vercel Environment Setup Checklist"
echo "=========================================="
echo ""

echo -e "${BLUE}Choose your setup approach:${NC}"
echo ""
echo "1) Single Project with Three Environments (Recommended)"
echo "2) Three Separate Projects"
echo ""
read -p "Enter choice (1 or 2): " choice

echo ""
echo "=========================================="
echo "  Setup Instructions"
echo "=========================================="
echo ""

if [ "$choice" = "1" ]; then
    echo -e "${GREEN}Option 1: Single Project with Environments${NC}"
    echo ""
    echo "Step 1: Create Project"
    echo "  → Go to https://vercel.com/new"
    echo "  → Import repository: mentions-frontend"
    echo "  → Project Name: mentions-frontend"
    echo "  → Root Directory: mentions_frontend (or . if package.json is at root)"
    echo "  → Framework: Next.js"
    echo "  → Click Deploy"
    echo ""
    echo "Step 2: Add Environment Variables"
    echo "  → Go to Settings → Environment Variables"
    echo "  → Add variables for each environment:"
    echo ""
    echo -e "${CYAN}Development Variables (select Development only):${NC}"
    echo "  NEXT_PUBLIC_ENV=dev"
    echo "  NEXT_PUBLIC_SUPABASE_URL=https://mjsxwzpxzalhgkekseyo.supabase.co"
    echo "  NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    echo "  NEXT_PUBLIC_API_URL=http://localhost:8000"
    echo ""
    echo -e "${CYAN}Preview/Staging Variables (select Preview only):${NC}"
    echo "  NEXT_PUBLIC_ENV=staging"
    echo "  NEXT_PUBLIC_SUPABASE_URL=https://xxx-staging.supabase.co"
    echo "  NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ..."
    echo "  NEXT_PUBLIC_API_URL=https://backend-staging-xxx.run.app"
    echo ""
    echo -e "${CYAN}Production Variables (select Production only):${NC}"
    echo "  NEXT_PUBLIC_ENV=prod"
    echo "  NEXT_PUBLIC_SUPABASE_URL=https://xxx-prod.supabase.co"
    echo "  NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ..."
    echo "  NEXT_PUBLIC_API_URL=https://backend-prod-xxx.run.app"
    echo ""
    echo "Step 3: Configure Git"
    echo "  → Settings → Git"
    echo "  → Production Branch: main"
    echo "  → Preview: All branches"
    echo ""
    echo "How it works:"
    echo "  • Push to main → Production (uses Production vars)"
    echo "  • Push to other branches → Preview (uses Preview vars)"
    echo ""
    
elif [ "$choice" = "2" ]; then
    echo -e "${GREEN}Option 2: Three Separate Projects${NC}"
    echo ""
    echo "Project 1: mentions-dev"
    echo "  → Create project: mentions-dev"
    echo "  → Root Directory: mentions_frontend (or .)"
    echo "  → Add Development variables (all environments)"
    echo ""
    echo "Project 2: mentions-staging"
    echo "  → Create project: mentions-staging"
    echo "  → Root Directory: mentions_frontend (or .)"
    echo "  → Add Staging variables (all environments)"
    echo "  → Optional: Set Production Branch to 'staging'"
    echo ""
    echo "Project 3: mentions-prod"
    echo "  → Create project: mentions-prod"
    echo "  → Root Directory: mentions_frontend (or .)"
    echo "  → Add Production variables (all environments)"
    echo "  → Set Production Branch to 'main'"
    echo ""
else
    echo "Invalid choice. Exiting."
    exit 1
fi

echo ""
echo "=========================================="
echo "  Checklist"
echo "=========================================="
echo ""

echo -e "${YELLOW}Development Environment:${NC}"
echo "  [ ] Vercel project created"
echo "  [ ] Development environment variables added"
echo "  [ ] First deployment successful"
echo "  [ ] Deployment URL obtained"
echo "  [ ] Supabase redirect URL updated"
echo ""

echo -e "${YELLOW}Staging Environment:${NC}"
echo "  [ ] Staging Supabase project created (if needed)"
echo "  [ ] Staging environment variables added"
echo "  [ ] Staging branch created (if using single project)"
echo "  [ ] First staging deployment successful"
echo "  [ ] Supabase redirect URL updated"
echo ""

echo -e "${YELLOW}Production Environment:${NC}"
echo "  [ ] Production Supabase project created (if needed)"
echo "  [ ] Production environment variables added"
echo "  [ ] Production branch (main) configured"
echo "  [ ] First production deployment successful"
echo "  [ ] Custom domain configured (optional)"
echo "  [ ] Supabase redirect URL updated"
echo ""

echo ""
echo "=========================================="
echo -e "${GREEN}Next Steps${NC}"
echo "=========================================="
echo ""
echo "1. Complete the checklist above"
echo "2. Update Supabase redirect URLs for each environment"
echo "3. Test deployments"
echo "4. Build authentication system"
echo ""

