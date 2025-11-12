#!/bin/bash
# Sync Terraform Cloud Run URLs to Vercel Environment Variables
# This script reads Terraform outputs and updates Vercel environment variables

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
TERRAFORM_DIR="${1:-mentions_terraform/environments}"
ENVIRONMENT="${2:-dev}"

echo ""
echo "=========================================="
echo "  Sync Terraform → Vercel"
echo "=========================================="
echo ""
echo "Environment: ${ENVIRONMENT}"
echo "Terraform Dir: ${TERRAFORM_DIR}/${ENVIRONMENT}"
echo ""

# Check if Vercel CLI is installed
if ! command -v vercel &> /dev/null; then
    echo -e "${RED}Error: Vercel CLI is not installed${NC}"
    echo "Install it with: npm install -g vercel"
    exit 1
fi

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: Terraform is not installed${NC}"
    exit 1
fi

# Navigate to terraform directory
cd "${TERRAFORM_DIR}/${ENVIRONMENT}" || {
    echo -e "${RED}Error: Directory ${TERRAFORM_DIR}/${ENVIRONMENT} not found${NC}"
    exit 1
}

echo -e "${BLUE}Step 1: Getting Terraform outputs...${NC}"
terraform output -json > /tmp/terraform-outputs.json 2>&1 || {
    echo -e "${RED}Error: Failed to get Terraform outputs${NC}"
    echo "Make sure Terraform is initialized and applied:"
    echo "  cd ${TERRAFORM_DIR}/${ENVIRONMENT}"
    echo "  terraform init"
    echo "  terraform apply"
    exit 1
}

# Parse backend URL from Terraform output
BACKEND_URL=$(terraform output -raw backend_url 2>/dev/null || echo "")

if [ -z "$BACKEND_URL" ] || [ "$BACKEND_URL" == "Backend will be deployed after image is built" ]; then
    echo -e "${YELLOW}Warning: Backend URL not available in Terraform outputs${NC}"
    echo "The backend Cloud Run service may not be deployed yet."
    echo ""
    read -p "Do you want to continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    BACKEND_URL=""
else
    echo -e "${GREEN}✓ Backend URL: ${BACKEND_URL}${NC}"
fi

cd - > /dev/null

echo ""
echo -e "${BLUE}Step 2: Updating Vercel environment variables...${NC}"
echo ""

# Map environment to Vercel environment
case $ENVIRONMENT in
    dev)
        VERCEL_ENV="Development"
        ;;
    staging)
        VERCEL_ENV="Preview"
        ;;
    prod)
        VERCEL_ENV="Production"
        ;;
    *)
        echo -e "${RED}Error: Unknown environment: ${ENVIRONMENT}${NC}"
        echo "Valid environments: dev, staging, prod"
        exit 1
        ;;
esac

if [ -n "$BACKEND_URL" ]; then
    echo "Updating NEXT_PUBLIC_API_URL for ${VERCEL_ENV} environment..."
    echo "Value: ${BACKEND_URL}"
    echo ""
    echo -e "${YELLOW}To update Vercel manually:${NC}"
    echo ""
    echo "1. Go to Vercel Dashboard → Your Project → Settings → Environment Variables"
    echo "2. Find or add: NEXT_PUBLIC_API_URL"
    echo "3. Set value to: ${BACKEND_URL}"
    echo "4. Select environment: ${VERCEL_ENV}"
    echo "5. Save"
    echo ""
    echo -e "${YELLOW}Or use Vercel CLI (if project is linked):${NC}"
    echo ""
    echo "vercel env add NEXT_PUBLIC_API_URL ${VERCEL_ENV}"
    echo "  → When prompted, enter: ${BACKEND_URL}"
    echo ""
else
    echo -e "${YELLOW}No backend URL to sync.${NC}"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}Sync Complete!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Update Vercel environment variable: NEXT_PUBLIC_API_URL"
echo "  2. Redeploy Vercel project to apply changes"
echo ""

