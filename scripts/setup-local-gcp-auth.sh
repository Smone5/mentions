#!/bin/bash
# Setup Google Cloud authentication for local development
# This creates a service account key that never expires (unlike gcloud auth application-default login)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ID="mention001"
SERVICE_ACCOUNT_NAME="mentions-backend-local"
KEY_FILE="${HOME}/.config/gcp/${PROJECT_ID}-local-dev-key.json"

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_step() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# Step 1: Check if gcloud is installed
check_gcloud() {
    print_step "Step 1: Checking gcloud CLI"
    
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI not found"
        print_info "Install from: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
    
    print_success "gcloud CLI found"
}

# Step 2: Check authentication
check_auth() {
    print_step "Step 2: Checking Authentication"
    
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        print_error "Not authenticated to GCP"
        print_info "Please run: gcloud auth login"
        exit 1
    fi
    
    ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
    print_success "Authenticated as: $ACTIVE_ACCOUNT"
}

# Step 3: Set project
set_project() {
    print_step "Step 3: Setting Active Project"
    
    gcloud config set project "$PROJECT_ID" &>/dev/null
    print_success "Set active project to $PROJECT_ID"
}

# Step 4: Check if service account exists, create if not
ensure_service_account() {
    print_step "Step 4: Ensuring Service Account Exists"
    
    SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
    
    if gcloud iam service-accounts describe "$SERVICE_ACCOUNT_EMAIL" &>/dev/null 2>&1; then
        print_success "Service account already exists: $SERVICE_ACCOUNT_EMAIL"
    else
        print_info "Creating service account: $SERVICE_ACCOUNT_NAME"
        gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
            --display-name="Mentions Backend Local Development" \
            --description="Service account for local development (never expires)" \
            --project="$PROJECT_ID" 2>&1 | grep -v "already exists" || true
        
        print_success "Service account created: $SERVICE_ACCOUNT_EMAIL"
    fi
}

# Step 5: Grant KMS permissions
grant_kms_permissions() {
    print_step "Step 5: Granting KMS Permissions"
    
    SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
    KEYRING="reddit-secrets"
    KEY="reddit-token-key"
    LOCATION="us-central1"
    
    # Grant KMS encrypt/decrypt permission
    print_info "Granting KMS permissions..."
    gcloud kms keys add-iam-policy-binding "$KEY" \
        --location="$LOCATION" \
        --keyring="$KEYRING" \
        --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
        --role="roles/cloudkms.cryptoKeyEncrypterDecrypter" \
        --project="$PROJECT_ID" 2>&1 | grep -v "already has" || true
    
    print_success "KMS permissions granted"
}

# Step 6: Create and download key
create_key() {
    print_step "Step 6: Creating Service Account Key"
    
    SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$KEY_FILE")"
    
    # Check if key already exists
    if [ -f "$KEY_FILE" ]; then
        print_warning "Key file already exists: $KEY_FILE"
        read -p "Do you want to overwrite it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Keeping existing key file"
            return
        fi
    fi
    
    # Create and download key
    print_info "Creating new service account key..."
    gcloud iam service-accounts keys create "$KEY_FILE" \
        --iam-account="$SERVICE_ACCOUNT_EMAIL" \
        --project="$PROJECT_ID"
    
    print_success "Key file created: $KEY_FILE"
}

# Step 7: Set permissions on key file
set_key_permissions() {
    print_step "Step 7: Setting Key File Permissions"
    
    chmod 600 "$KEY_FILE"
    print_success "Key file permissions set to 600 (owner read/write only)"
}

# Step 8: Display instructions
display_instructions() {
    print_step "Step 8: Setup Complete!"
    
    print_success "Service account key created successfully"
    echo ""
    print_info "Add this to your .env file:"
    echo ""
    echo -e "${GREEN}GOOGLE_APPLICATION_CREDENTIALS=${KEY_FILE}${NC}"
    echo ""
    print_info "Or export it in your shell:"
    echo ""
    echo -e "${GREEN}export GOOGLE_APPLICATION_CREDENTIALS=${KEY_FILE}${NC}"
    echo ""
    print_warning "IMPORTANT: Never commit this key file to git!"
    print_info "The key file is already in .gitignore"
    echo ""
    print_info "This key will never expire (unlike gcloud auth application-default login)"
    print_info "You can now use KMS without re-authenticating!"
}

# Main execution
main() {
    check_gcloud
    check_auth
    set_project
    ensure_service_account
    grant_kms_permissions
    create_key
    set_key_permissions
    display_instructions
}

# Run main
main



