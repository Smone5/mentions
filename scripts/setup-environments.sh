#!/bin/bash
# Environment Setup Script
# This script helps set up Google Cloud, Supabase, and Vercel environments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check gcloud
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI not found. Please install Google Cloud SDK."
        exit 1
    fi
    
    # Check terraform
    if ! command -v terraform &> /dev/null; then
        print_warning "Terraform not found. Install with: brew install terraform"
    fi
    
    # Check if authenticated
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        print_warning "Not authenticated to GCP. Run: gcloud auth login"
    fi
    
    print_success "Prerequisites check complete"
}

# Setup Google Cloud Projects
setup_gcp_projects() {
    print_info "Setting up Google Cloud projects..."
    
    read -p "Enter your GCP billing account ID: " BILLING_ACCOUNT
    
    if [ -z "$BILLING_ACCOUNT" ]; then
        print_error "Billing account ID is required"
        exit 1
    fi
    
    # Use existing project mention001
    PROJECT_ID="mention001"
    
    print_info "Using existing project: ${PROJECT_ID}"
    
    # Check if project exists
    if ! gcloud projects describe "${PROJECT_ID}" &>/dev/null; then
        print_error "Project ${PROJECT_ID} does not exist. Please create it first."
        exit 1
    fi
    
    # Set as active project
    gcloud config set project "${PROJECT_ID}"
    
    # Enable APIs
    print_info "Enabling required APIs for ${PROJECT_ID}..."
    gcloud services enable \
        run.googleapis.com \
        cloudtasks.googleapis.com \
        cloudscheduler.googleapis.com \
        secretmanager.googleapis.com \
        cloudkms.googleapis.com \
        artifactregistry.googleapis.com \
        cloudbuild.googleapis.com \
        compute.googleapis.com \
        storage.googleapis.com \
        --project="${PROJECT_ID}"
    
    print_success "APIs enabled for ${PROJECT_ID}"
    
    # Create Terraform state bucket
    BUCKET_NAME="mention001-terraform-state"
    print_info "Creating Terraform state bucket: ${BUCKET_NAME}"
    
    if gcloud storage buckets describe "gs://${BUCKET_NAME}" &>/dev/null; then
        print_warning "Bucket ${BUCKET_NAME} already exists"
    else
        gcloud storage buckets create "gs://${BUCKET_NAME}" \
            --project="${PROJECT_ID}" \
            --location=us-central1 \
            --uniform-bucket-level-access
        
        # Enable versioning
        gcloud storage buckets update "gs://${BUCKET_NAME}" --versioning
        
        print_success "Created bucket: ${BUCKET_NAME}"
    fi
    
    print_success "Google Cloud projects setup complete!"
    print_info "Next: Set up Supabase projects manually at https://supabase.com"
}

# Display Supabase setup instructions
show_supabase_instructions() {
    print_info "Supabase Setup Instructions"
    echo ""
    echo "1. Go to https://supabase.com and sign in"
    echo "2. Create three projects:"
    echo "   - mentions-dev"
    echo "   - mentions-stg"
    echo "   - mentions-prod"
    echo ""
    echo "3. For each project:"
    echo "   - Go to SQL Editor"
    echo "   - Run: CREATE EXTENSION IF NOT EXISTS vector;"
    echo "   - Run: CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"
    echo ""
    echo "4. Get credentials from Settings → API:"
    echo "   - Project URL"
    echo "   - Anon key"
    echo "   - Service role key (keep secret!)"
    echo ""
    echo "5. Configure Auth → Settings:"
    echo "   - Enable Email provider"
    echo "   - Add redirect URLs:"
    echo "     Dev: http://localhost:3000/auth/callback"
    echo "     Prod: https://yourdomain.com/auth/callback"
    echo ""
    read -p "Press Enter when Supabase projects are created..."
}

# Display Vercel setup instructions
show_vercel_instructions() {
    print_info "Vercel Setup Instructions"
    echo ""
    echo "1. Go to https://vercel.com and sign in"
    echo "2. Click 'Add New Project'"
    echo "3. Import GitHub repository: mentions-frontend"
    echo "4. Configure environment variables:"
    echo "   - NEXT_PUBLIC_ENV"
    echo "   - NEXT_PUBLIC_SUPABASE_URL"
    echo "   - NEXT_PUBLIC_SUPABASE_ANON_KEY"
    echo "   - NEXT_PUBLIC_API_URL"
    echo ""
    echo "5. Set up separate projects for dev/staging/prod or use environment-specific vars"
    echo ""
    read -p "Press Enter when Vercel is configured..."
}

# Main menu
main() {
    echo ""
    echo "=========================================="
    echo "  Mentions Environment Setup"
    echo "=========================================="
    echo ""
    
    check_prerequisites
    
    echo ""
    echo "What would you like to set up?"
    echo "1) Google Cloud Projects (GCP)"
    echo "2) Show Supabase Setup Instructions"
    echo "3) Show Vercel Setup Instructions"
    echo "4) Initialize Terraform Structure"
    echo "5) All of the above"
    echo ""
    read -p "Enter choice [1-5]: " CHOICE
    
    case $CHOICE in
        1)
            setup_gcp_projects
            ;;
        2)
            show_supabase_instructions
            ;;
        3)
            show_vercel_instructions
            ;;
        4)
            print_info "Terraform structure will be created separately"
            print_info "Run: ./scripts/create-terraform-structure.sh"
            ;;
        5)
            setup_gcp_projects
            echo ""
            show_supabase_instructions
            echo ""
            show_vercel_instructions
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
    
    echo ""
    print_success "Setup process complete!"
    print_info "Update ENVIRONMENT-SETUP-PROGRESS.md with your progress"
}

main


