#!/bin/bash
# Check which variables are configured and which are missing

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo "=========================================="
echo "  Variables Configuration Check"
echo "=========================================="
echo ""

# Check Terraform variables
echo -e "${BLUE}1. Terraform Variables${NC}"
echo "   Location: mentions_terraform/environments/dev/terraform.tfvars"
if [ -f "mentions_terraform/environments/dev/terraform.tfvars" ]; then
    echo -e "   ${GREEN}✓ File exists${NC}"
    
    # Check each variable
    if grep -q "project_id.*mention001" mentions_terraform/environments/dev/terraform.tfvars; then
        echo -e "   ${GREEN}✓ project_id set${NC}"
    else
        echo -e "   ${YELLOW}⚠ project_id needs to be set${NC}"
    fi
    
    if grep -q "billing_account.*XXXXX" mentions_terraform/environments/dev/terraform.tfvars; then
        echo -e "   ${RED}✗ billing_account needs to be set${NC}"
    elif grep -q "billing_account" mentions_terraform/environments/dev/terraform.tfvars; then
        echo -e "   ${GREEN}✓ billing_account set${NC}"
    else
        echo -e "   ${RED}✗ billing_account missing${NC}"
    fi
    
    if grep -q "supabase_url.*xxx" mentions_terraform/environments/dev/terraform.tfvars; then
        echo -e "   ${RED}✗ supabase_url needs to be set${NC}"
    elif grep -q "supabase_url" mentions_terraform/environments/dev/terraform.tfvars; then
        echo -e "   ${GREEN}✓ supabase_url set${NC}"
    else
        echo -e "   ${RED}✗ supabase_url missing${NC}"
    fi
else
    echo -e "   ${RED}✗ File does not exist${NC}"
    echo "   Run: cp mentions_terraform/environments/dev/terraform.tfvars.example mentions_terraform/environments/dev/terraform.tfvars"
fi

echo ""

# Check GCP project
echo -e "${BLUE}2. GCP Configuration${NC}"
if gcloud projects describe mention001 &>/dev/null 2>&1; then
    echo -e "   ${GREEN}✓ Project mention001 exists${NC}"
    
    # Check if APIs are enabled
    gcloud config set project mention001 &>/dev/null
    ENABLED_APIS=$(gcloud services list --enabled --format="value(config.name)" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$ENABLED_APIS" -gt 0 ]; then
        echo -e "   ${GREEN}✓ $ENABLED_APIS APIs enabled${NC}"
    else
        echo -e "   ${YELLOW}⚠ No APIs enabled yet${NC}"
    fi
    
    # Check state bucket
    if gcloud storage buckets describe gs://mention001-terraform-state &>/dev/null 2>&1; then
        echo -e "   ${GREEN}✓ Terraform state bucket exists${NC}"
    else
        echo -e "   ${RED}✗ Terraform state bucket missing${NC}"
    fi
    
    # Check secrets
    SECRET_COUNT=$(gcloud secrets list --format="value(name)" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$SECRET_COUNT" -gt 0 ]; then
        echo -e "   ${GREEN}✓ $SECRET_COUNT secrets exist${NC}"
        
        # Check specific secrets
        for SECRET in openai-api-key supabase-service-role-key db-connection-string; do
            if gcloud secrets describe "$SECRET" &>/dev/null 2>&1; then
                VERSION_COUNT=$(gcloud secrets versions list "$SECRET" --format="value(name)" 2>/dev/null | wc -l | tr -d ' ')
                if [ "$VERSION_COUNT" -gt 0 ]; then
                    echo -e "   ${GREEN}✓ Secret '$SECRET' has values${NC}"
                else
                    echo -e "   ${YELLOW}⚠ Secret '$SECRET' exists but has no values${NC}"
                fi
            else
                echo -e "   ${RED}✗ Secret '$SECRET' missing${NC}"
            fi
        done
    else
        echo -e "   ${RED}✗ No secrets exist${NC}"
    fi
else
    echo -e "   ${RED}✗ Project mention001 not found${NC}"
fi

echo ""

# Check backend .env
echo -e "${BLUE}3. Backend Environment Variables${NC}"
echo "   Location: mentions_backend/.env"
if [ -f "mentions_backend/.env" ]; then
    echo -e "   ${GREEN}✓ File exists${NC}"
    
    REQUIRED_VARS=("SUPABASE_URL" "SUPABASE_SERVICE_ROLE_KEY" "DB_CONN" "OPENAI_API_KEY")
    for VAR in "${REQUIRED_VARS[@]}"; do
        if grep -q "^${VAR}=" mentions_backend/.env && ! grep -q "^${VAR}=$" mentions_backend/.env && ! grep -q "^${VAR}=xxx" mentions_backend/.env; then
            echo -e "   ${GREEN}✓ $VAR set${NC}"
        else
            echo -e "   ${RED}✗ $VAR missing or not set${NC}"
        fi
    done
else
    echo -e "   ${YELLOW}⚠ File does not exist (create when ready for local dev)${NC}"
fi

echo ""

# Check frontend .env.local
echo -e "${BLUE}4. Frontend Environment Variables${NC}"
echo "   Location: mentions_frontend/.env.local"
if [ -f "mentions_frontend/.env.local" ]; then
    echo -e "   ${GREEN}✓ File exists${NC}"
    
    REQUIRED_VARS=("NEXT_PUBLIC_SUPABASE_URL" "NEXT_PUBLIC_SUPABASE_ANON_KEY" "NEXT_PUBLIC_API_URL")
    for VAR in "${REQUIRED_VARS[@]}"; do
        if grep -q "^${VAR}=" mentions_frontend/.env.local && ! grep -q "^${VAR}=$" mentions_frontend/.env.local && ! grep -q "^${VAR}=xxx" mentions_frontend/.env.local; then
            echo -e "   ${GREEN}✓ $VAR set${NC}"
        else
            echo -e "   ${RED}✗ $VAR missing or not set${NC}"
        fi
    done
else
    echo -e "   ${YELLOW}⚠ File does not exist (create when ready for local dev)${NC}"
fi

echo ""
echo "=========================================="
echo "  Summary"
echo "=========================================="
echo ""
echo "See VARIABLES-CHECKLIST.md for complete list"
echo "See SETUP-GUIDE.md for setup instructions"
echo ""

