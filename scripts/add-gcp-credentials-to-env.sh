#!/bin/bash
# Add GOOGLE_APPLICATION_CREDENTIALS to .env file

set -e

ENV_FILE="mentions_backend/.env"
KEY_FILE="${HOME}/.config/gcp/mention001-local-dev-key.json"

# Check if key file exists
if [ ! -f "$KEY_FILE" ]; then
    echo "❌ Service account key file not found: $KEY_FILE"
    echo ""
    echo "Please run the setup script first:"
    echo "  ./scripts/setup-local-gcp-auth.sh"
    exit 1
fi

# Expand the path to absolute
ABS_KEY_FILE=$(realpath "$KEY_FILE")

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ .env file not found: $ENV_FILE"
    exit 1
fi

# Check if GOOGLE_APPLICATION_CREDENTIALS already exists
if grep -q "^GOOGLE_APPLICATION_CREDENTIALS=" "$ENV_FILE" 2>/dev/null; then
    echo "⚠️  GOOGLE_APPLICATION_CREDENTIALS already exists in .env"
    echo ""
    echo "Current value:"
    grep "^GOOGLE_APPLICATION_CREDENTIALS=" "$ENV_FILE"
    echo ""
    read -p "Do you want to update it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Update existing line
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' "s|^GOOGLE_APPLICATION_CREDENTIALS=.*|GOOGLE_APPLICATION_CREDENTIALS=$ABS_KEY_FILE|" "$ENV_FILE"
        else
            # Linux
            sed -i "s|^GOOGLE_APPLICATION_CREDENTIALS=.*|GOOGLE_APPLICATION_CREDENTIALS=$ABS_KEY_FILE|" "$ENV_FILE"
        fi
        echo "✅ Updated GOOGLE_APPLICATION_CREDENTIALS in .env"
    else
        echo "Keeping existing value"
    fi
else
    # Add new line
    echo "" >> "$ENV_FILE"
    echo "# Google Cloud service account credentials (for local development)" >> "$ENV_FILE"
    echo "GOOGLE_APPLICATION_CREDENTIALS=$ABS_KEY_FILE" >> "$ENV_FILE"
    echo "✅ Added GOOGLE_APPLICATION_CREDENTIALS to .env"
fi

echo ""
echo "Current .env setting:"
grep "^GOOGLE_APPLICATION_CREDENTIALS=" "$ENV_FILE"
echo ""
echo "✅ Done! Restart your backend server to use the new credentials."



