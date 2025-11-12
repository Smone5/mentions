#!/bin/bash
# Google Cloud Platform Setup Script
# Focuses only on GCP setup for mention001 project

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ID="mention001"
PROJECT_NUMBER="666103574212"
REGION="us-central1"
STATE_BUCKET="mention001-terraform-state"

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

# Step 1: Check Authentication
check_auth() {
    print_step "Step 1: Checking Authentication"
    
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        print_error "Not authenticated to GCP"
        print_info "Please run: gcloud auth login"
        exit 1
    fi
    
    ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
    print_success "Authenticated as: $ACTIVE_ACCOUNT"
}

# Step 2: Verify Project Access
verify_project() {
    print_step "Step 2: Verifying Project Access"
    
    if gcloud projects describe "$PROJECT_ID" &>/dev/null; then
        print_success "Project $PROJECT_ID is accessible"
        gcloud config set project "$PROJECT_ID" &>/dev/null
        print_success "Set active project to $PROJECT_ID"
    else
        print_error "Cannot access project $PROJECT_ID"
        print_info "Please ensure:"
        print_info "  1. Project exists: $PROJECT_ID"
        print_info "  2. You have access permissions"
        print_info "  3. You're authenticated with the correct account"
        exit 1
    fi
}

# Step 3: Get Billing Account
get_billing() {
    print_step "Step 3: Checking Billing Account"
    
    BILLING_ACCOUNTS=$(gcloud billing accounts list --format="value(name)" 2>/dev/null | wc -l | tr -d ' ')
    
    if [ "$BILLING_ACCOUNTS" -eq 0 ]; then
        print_warning "No billing accounts found"
        print_info "You may need to set up billing in GCP Console"
    else
        print_info "Available billing accounts:"
        gcloud billing accounts list --format="table(name,displayName,open)"
        
        LINKED=$(gcloud billing projects describe "$PROJECT_ID" --format="value(billingAccountName)" 2>/dev/null || echo "")
        if [ -n "$LINKED" ] && [ "$LINKED" != "" ]; then
            print_success "Billing account linked: $LINKED"
        else
            print_warning "No billing account linked to project"
            read -p "Link a billing account now? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                read -p "Enter billing account ID: " BILLING_ID
                gcloud billing projects link "$PROJECT_ID" --billing-account="$BILLING_ID"
                print_success "Billing account linked"
            fi
        fi
    fi
}

# Step 4: Enable APIs
enable_apis() {
    print_step "Step 4: Enabling Required APIs"
    
    APIS=(
        "run.googleapis.com"
        "cloudtasks.googleapis.com"
        "cloudscheduler.googleapis.com"
        "secretmanager.googleapis.com"
        "cloudkms.googleapis.com"
        "artifactregistry.googleapis.com"
        "cloudbuild.googleapis.com"
        "compute.googleapis.com"
        "storage.googleapis.com"
    )
    
    print_info "Enabling ${#APIS[@]} APIs..."
    
    for API in "${APIS[@]}"; do
        if gcloud services list --enabled --filter="name:$API" --format="value(name)" | grep -q "$API"; then
            print_success "$API already enabled"
        else
            print_info "Enabling $API..."
            gcloud services enable "$API" --project="$PROJECT_ID" 2>&1 | grep -v "already enabled" || true
            print_success "$API enabled"
        fi
    done
}

# Step 5: Create State Bucket
create_state_bucket() {
    print_step "Step 5: Creating Terraform State Bucket"
    
    if gcloud storage buckets describe "gs://$STATE_BUCKET" &>/dev/null 2>&1; then
        print_success "State bucket already exists: gs://$STATE_BUCKET"
    else
        print_info "Creating state bucket: gs://$STATE_BUCKET"
        gcloud storage buckets create "gs://$STATE_BUCKET" \
            --project="$PROJECT_ID" \
            --location="$REGION" \
            --uniform-bucket-level-access
        
        gcloud storage buckets update "gs://$STATE_BUCKET" --versioning
        
        print_success "State bucket created: gs://$STATE_BUCKET"
    fi
}

# Step 6: Configure Terraform
configure_terraform() {
    print_step "Step 6: Configuring Terraform"
    
    TFVARS_PATH="mentions_terraform/environments/dev/terraform.tfvars"
    TFVARS_EXAMPLE="mentions_terraform/environments/dev/terraform.tfvars.example"
    
    if [ ! -f "$TFVARS_EXAMPLE" ]; then
        print_error "Terraform example file not found: $TFVARS_EXAMPLE"
        exit 1
    fi
    
    if [ ! -f "$TFVARS_PATH" ]; then
        print_info "Creating terraform.tfvars from example..."
        cp "$TFVARS_EXAMPLE" "$TFVARS_PATH"
        print_success "Created $TFVARS_PATH"
        print_warning "Please edit this file and add your billing_account"
    else
        print_success "terraform.tfvars already exists"
    fi
    
    # Check if billing_account needs to be set
    if grep -q "billing_account.*XXXXX" "$TFVARS_PATH" 2>/dev/null; then
        print_warning "billing_account needs to be set in $TFVARS_PATH"
        BILLING_ID=$(gcloud billing projects describe "$PROJECT_ID" --format="value(billingAccountName)" 2>/dev/null || echo "")
        if [ -n "$BILLING_ID" ] && [ "$BILLING_ID" != "" ]; then
            print_info "Found billing account: $BILLING_ID"
            read -p "Update terraform.tfvars with this billing account? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                # Extract just the ID part (after /)
                BILLING_ID_ONLY=$(echo "$BILLING_ID" | sed 's/.*\///')
                sed -i.bak "s/billing_account = .*/billing_account = \"$BILLING_ID_ONLY\"/" "$TFVARS_PATH"
                rm -f "${TFVARS_PATH}.bak"
                print_success "Updated billing_account in terraform.tfvars"
            fi
        fi
    else
        print_success "billing_account appears to be set"
    fi
}

# Step 7: Initialize Terraform
init_terraform() {
    print_step "Step 7: Initializing Terraform"
    
    cd mentions_terraform/environments/dev
    
    if [ -d ".terraform" ]; then
        print_info "Terraform already initialized"
    else
        print_info "Initializing Terraform backend..."
        terraform init
        print_success "Terraform initialized"
    fi
    
    cd ../../..
}

# Step 8: Plan Terraform
plan_terraform() {
    print_step "Step 8: Planning Terraform Changes"
    
    cd mentions_terraform/environments/dev
    
    print_info "Running terraform plan..."
    terraform plan
    
    cd ../../..
}

# Step 9: Summary
show_summary() {
    print_step "Setup Summary"
    
    echo "Project: $PROJECT_ID"
    echo "Region: $REGION"
    echo "State Bucket: gs://$STATE_BUCKET"
    echo ""
    echo "Next steps:"
    echo "  1. Review terraform.tfvars and ensure billing_account is set"
    echo "  2. Run: cd mentions_terraform/environments/dev"
    echo "  3. Run: terraform plan (to review changes)"
    echo "  4. Run: terraform apply (to create infrastructure)"
    echo ""
    echo "After Terraform applies, you'll have:"
    echo "  ✓ KMS keyring and key"
    echo "  ✓ Service account with permissions"
    echo "  ✓ Secret Manager secrets (empty - add values later)"
    echo "  ✓ Cloud Tasks queues"
    echo ""
}

# Main execution
main() {
    echo ""
    echo "=========================================="
    echo "  Google Cloud Platform Setup"
    echo "  Project: $PROJECT_ID"
    echo "=========================================="
    echo ""
    
    check_auth
    verify_project
    get_billing
    enable_apis
    create_state_bucket
    configure_terraform
    init_terraform
    
    echo ""
    read -p "Run terraform plan now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        plan_terraform
    fi
    
    show_summary
}

main

