#!/bin/bash
# Set OpenAI API key in GCP Secret Manager

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo "=========================================="
echo "  Set OpenAI API Key"
echo "=========================================="
echo ""

# Check if key is provided as argument
if [ -n "$1" ]; then
    OPENAI_KEY="$1"
else
    echo "Enter your OpenAI API key:"
    echo "(The key will be hidden for security)"
    read -s OPENAI_KEY
    echo ""
    
    if [ -z "$OPENAI_KEY" ]; then
        echo -e "${RED}Error: OpenAI API key is required${NC}"
        exit 1
    fi
fi

# Validate key format (starts with sk-)
if [[ ! "$OPENAI_KEY" =~ ^sk- ]]; then
    echo -e "${YELLOW}Warning: OpenAI API keys usually start with 'sk-'${NC}"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

echo ""
echo -e "${BLUE}Setting OpenAI API key in GCP Secret Manager...${NC}"

# Set active project
gcloud config set project mention001 > /dev/null 2>&1

# Add secret version
if echo -n "$OPENAI_KEY" | gcloud secrets versions add openai-api-key --data-file=- 2>&1; then
    echo -e "${GREEN}✓ OpenAI API key added to Secret Manager${NC}"
else
    echo -e "${RED}✗ Failed to add OpenAI API key${NC}"
    echo "Make sure the secret exists (created by Terraform)"
    exit 1
fi

echo ""
echo -e "${GREEN}OpenAI API key configured!${NC}"
echo ""
echo "The key is now stored in GCP Secret Manager and will be available to:"
echo "  - Cloud Run services (via environment variables)"
echo "  - Backend applications (when deployed)"
echo ""

