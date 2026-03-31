#!/bin/bash
# Create service account key file for local development
# This script will prompt for authentication if needed

set -e

PROJECT_ID="mention001"
SERVICE_ACCOUNT_NAME="mentions-backend-local"
KEY_FILE="${HOME}/.config/gcp/mention001-local-dev-key.json"
SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "🔐 Creating service account key for local development..."
echo ""

# Check if key file already exists
if [ -f "$KEY_FILE" ]; then
    echo "⚠️  Key file already exists: $KEY_FILE"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing key file."
        exit 0
    fi
    echo "Overwriting existing key file..."
fi

# Create directory if it doesn't exist
mkdir -p "$(dirname "$KEY_FILE")"

# Check if service account exists
echo "Checking if service account exists..."
SERVICE_ACCOUNT_EXISTS=false
if gcloud iam service-accounts describe "$SERVICE_ACCOUNT_EMAIL" --project="$PROJECT_ID" &>/dev/null; then
    echo "✅ Service account exists: $SERVICE_ACCOUNT_EMAIL"
    SERVICE_ACCOUNT_EXISTS=true
else
    echo "❌ Service account does not exist: $SERVICE_ACCOUNT_EMAIL"
    echo ""
    echo "Creating service account..."
    gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
        --display-name="Mentions Backend Local Development" \
        --description="Service account for local development (never expires)" \
        --project="$PROJECT_ID"
    echo "✅ Service account created"
    
    # Wait for service account to propagate (GCP needs a moment)
    echo "Waiting for service account to propagate..."
    for i in {1..10}; do
        if gcloud iam service-accounts describe "$SERVICE_ACCOUNT_EMAIL" --project="$PROJECT_ID" &>/dev/null; then
            echo "✅ Service account is ready"
            SERVICE_ACCOUNT_EXISTS=true
            break
        fi
        echo "  Waiting... ($i/10)"
        sleep 2
    done
    
    if [ "$SERVICE_ACCOUNT_EXISTS" = false ]; then
        echo "⚠️  Service account may not be fully propagated yet, but continuing..."
    fi
fi

# Grant KMS permissions (check if already granted first)
echo ""
echo "Checking KMS permissions..."
if gcloud kms keys get-iam-policy reddit-token-key \
    --location=us-central1 \
    --keyring=reddit-secrets \
    --project="$PROJECT_ID" 2>/dev/null | grep -q "$SERVICE_ACCOUNT_EMAIL"; then
    echo "✅ KMS permissions already granted"
else
    echo "Granting KMS permissions..."
    # Retry logic for permission grant (GCP propagation delay)
    MAX_RETRIES=5
    RETRY_COUNT=0
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if gcloud kms keys add-iam-policy-binding reddit-token-key \
            --location=us-central1 \
            --keyring=reddit-secrets \
            --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
            --role="roles/cloudkms.cryptoKeyEncrypterDecrypter" \
            --project="$PROJECT_ID" 2>&1; then
            echo "✅ KMS permissions granted"
            break
        else
            RETRY_COUNT=$((RETRY_COUNT + 1))
            if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
                echo "  Retrying... ($RETRY_COUNT/$MAX_RETRIES)"
                sleep 3
            else
                echo "⚠️  Failed to grant KMS permissions after $MAX_RETRIES attempts"
                echo "   You may need to grant them manually:"
                echo "   gcloud kms keys add-iam-policy-binding reddit-token-key \\"
                echo "     --location=us-central1 \\"
                echo "     --keyring=reddit-secrets \\"
                echo "     --member=\"serviceAccount:${SERVICE_ACCOUNT_EMAIL}\" \\"
                echo "     --role=\"roles/cloudkms.cryptoKeyEncrypterDecrypter\" \\"
                echo "     --project=\"$PROJECT_ID\""
            fi
        fi
    done
fi

echo ""
echo "Creating service account key..."
echo "This may prompt for authentication if needed..."

# Create the key file
gcloud iam service-accounts keys create "$KEY_FILE" \
    --iam-account="$SERVICE_ACCOUNT_EMAIL" \
    --project="$PROJECT_ID"

# Set secure permissions
chmod 600 "$KEY_FILE"

echo ""
echo "✅ Service account key created successfully!"
echo ""
echo "Key file location: $KEY_FILE"
echo ""
echo "The key file is already configured in your .env file."
echo "Restart your backend server to use it!"

