#!/bin/bash
# Get Cloud Run URLs from Terraform outputs for all environments
# Useful for manually updating Vercel or documentation

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TERRAFORM_BASE="mentions_terraform/environments"

echo ""
echo "=========================================="
echo "  Terraform Cloud Run URLs"
echo "=========================================="
echo ""

for env in dev staging prod; do
    ENV_DIR="${TERRAFORM_BASE}/${env}"
    
    if [ ! -d "$ENV_DIR" ]; then
        echo -e "${YELLOW}⚠ ${env}: Directory not found${NC}"
        continue
    fi
    
    echo -e "${BLUE}${env}:${NC}"
    
    cd "$ENV_DIR" 2>/dev/null || {
        echo "  Directory not accessible"
        continue
    }
    
    # Check if terraform is initialized
    if [ ! -d ".terraform" ]; then
        echo "  Terraform not initialized"
        cd - > /dev/null
        continue
    fi
    
    # Get backend URL
    BACKEND_URL=$(terraform output -raw backend_url 2>/dev/null || echo "Not available")
    
    if [[ "$BACKEND_URL" == *"not deployed"* ]] || [[ "$BACKEND_URL" == *"Backend not deployed"* ]] || [[ "$BACKEND_URL" == *"Backend will be deployed"* ]]; then
        echo "  Backend URL: Not deployed yet"
        echo "  → Uncomment backend module in main.tf and run terraform apply"
    elif [[ "$BACKEND_URL" == http* ]]; then
        echo "  Backend URL: ${BACKEND_URL}"
        echo ""
        echo "  Vercel Environment Variable:"
        echo "    NEXT_PUBLIC_API_URL=${BACKEND_URL}"
        case $env in
            dev)
                echo "    Environment: Development"
                ;;
            staging)
                echo "    Environment: Preview"
                ;;
            prod)
                echo "    Environment: Production"
                ;;
        esac
    else
        echo "  Backend URL: Not available"
    fi
    
    cd - > /dev/null
    echo ""
done

echo "=========================================="
echo ""
echo "To update Vercel:"
echo "  1. Go to Vercel Dashboard → Settings → Environment Variables"
echo "  2. Add/update NEXT_PUBLIC_API_URL with the URLs above"
echo "  3. Select the appropriate environment for each"
echo "  4. Redeploy"
echo ""

