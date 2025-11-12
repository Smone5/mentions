#!/bin/bash
# Supabase Setup Checklist - Interactive helper

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo "=========================================="
echo "  Supabase Setup Checklist"
echo "=========================================="
echo ""

echo -e "${BLUE}Step 1: Create Supabase Project${NC}"
echo "  1. Go to https://supabase.com"
echo "  2. Sign in or create account"
echo "  3. Click 'New Project'"
echo "  4. Name: mentions-dev"
echo "  5. Set database password (save it!)"
echo "  6. Choose region"
echo "  7. Create project"
echo ""
read -p "Have you created the Supabase project? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please create the project first, then run this script again."
    exit 0
fi

echo ""
echo -e "${BLUE}Step 2: Enable Extensions${NC}"
echo "  1. Go to SQL Editor in Supabase dashboard"
echo "  2. Run these commands:"
echo ""
echo "     CREATE EXTENSION IF NOT EXISTS vector;"
echo "     CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"
echo ""
read -p "Have you enabled the extensions? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please enable the extensions, then continue."
fi

echo ""
echo -e "${BLUE}Step 3: Get Credentials${NC}"
echo "Go to Settings → API and get:"
echo "  - Project URL"
echo "  - Anon key (public)"
echo "  - Service role key (secret!)"
echo ""
echo "Go to Settings → Database and get:"
echo "  - Connection string (URI format)"
echo "  - Replace [YOUR-PASSWORD] with your actual password"
echo ""

read -p "Enter your Supabase Project URL: " SUPABASE_URL
read -p "Enter your Supabase Anon Key: " SUPABASE_ANON_KEY
read -p "Enter your Supabase Service Role Key: " SUPABASE_SERVICE_ROLE_KEY
read -p "Enter your Database Connection String: " DB_CONN

echo ""
echo -e "${GREEN}✓ Credentials collected${NC}"

echo ""
echo -e "${BLUE}Step 4: Configure Authentication${NC}"
echo "  1. Go to Authentication → URL Configuration"
echo "  2. Set Site URL: http://localhost:3000"
echo "  3. Add Redirect URL: http://localhost:3000/auth/callback"
echo ""
read -p "Have you configured authentication? (y/n) " -n 1 -r
echo

echo ""
echo -e "${BLUE}Step 5: Add to GCP Secret Manager${NC}"
read -p "Add credentials to GCP Secret Manager now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    gcloud config set project mention001
    
    echo "Adding Supabase service role key..."
    echo -n "$SUPABASE_SERVICE_ROLE_KEY" | gcloud secrets versions add supabase-service-role-key --data-file=-
    echo -e "${GREEN}✓ Service role key added${NC}"
    
    echo "Adding database connection string..."
    echo -n "$DB_CONN" | gcloud secrets versions add db-connection-string --data-file=-
    echo -e "${GREEN}✓ Database connection string added${NC}"
fi

echo ""
echo -e "${BLUE}Step 6: Update Terraform Variables${NC}"
read -p "Update terraform.tfvars with Supabase URL? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    TFVARS="mentions_terraform/environments/dev/terraform.tfvars"
    if grep -q "supabase_url.*xxx" "$TFVARS" 2>/dev/null; then
        sed -i.bak "s|supabase_url.*=.*|supabase_url    = \"$SUPABASE_URL\"|" "$TFVARS"
        rm -f "${TFVARS}.bak"
        echo -e "${GREEN}✓ terraform.tfvars updated${NC}"
    else
        echo "supabase_url already set or file not found"
    fi
fi

echo ""
echo -e "${BLUE}Step 7: Create Local Environment Files${NC}"
read -p "Create .env files for local development? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Backend .env
    BACKEND_ENV="mentions_backend/.env"
    if [ ! -f "$BACKEND_ENV" ]; then
        cat > "$BACKEND_ENV" << EOF
ENV=dev
SUPABASE_URL=$SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY=$SUPABASE_SERVICE_ROLE_KEY
DB_CONN=$DB_CONN
OPENAI_API_KEY=sk-...
GOOGLE_PROJECT_ID=mention001
GOOGLE_LOCATION=us-central1
KMS_KEYRING=reddit-secrets
KMS_KEY=reddit-token-key
ALLOW_POSTS=false
API_HOST=0.0.0.0
API_PORT=8000
LOG_LEVEL=DEBUG
LOG_JSON=false
EOF
        echo -e "${GREEN}✓ Created $BACKEND_ENV${NC}"
    else
        echo -e "${YELLOW}⚠ $BACKEND_ENV already exists${NC}"
    fi
    
    # Frontend .env.local
    FRONTEND_ENV="mentions_frontend/.env.local"
    if [ ! -f "$FRONTEND_ENV" ]; then
        cat > "$FRONTEND_ENV" << EOF
NEXT_PUBLIC_ENV=dev
NEXT_PUBLIC_SUPABASE_URL=$SUPABASE_URL
NEXT_PUBLIC_SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
NEXT_PUBLIC_API_URL=http://localhost:8000
EOF
        echo -e "${GREEN}✓ Created $FRONTEND_ENV${NC}"
    else
        echo -e "${YELLOW}⚠ $FRONTEND_ENV already exists${NC}"
    fi
fi

echo ""
echo "=========================================="
echo -e "${GREEN}Supabase Setup Complete!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Run database migrations (see docs/03-DATABASE-SCHEMA.md)"
echo "  2. Test database connection"
echo "  3. Set up OpenAI API key"
echo ""

