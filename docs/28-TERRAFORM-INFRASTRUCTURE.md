# Terraform Infrastructure

## Overview
All GCP infrastructure is managed via Terraform to ensure consistency across dev, staging, and production environments.

**All Terraform code goes in**: `mentions_terraform/`

This document covers:
- Terraform project structure
- Environment configuration
- Resource definitions
- Deployment workflow
- State management

---

## Directory Structure

```
mentions_terraform/
├── README.md                     # Quick start guide
├── .gitignore                    # Ignore .tfstate, .terraform/, etc.
├── terraform.tfvars.example      # Example variables
│
├── environments/                 # Environment-specific configs
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf            # State backend config
│   ├── staging/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars
│       └── backend.tf
│
├── modules/                      # Reusable Terraform modules
│   ├── project/                  # GCP project setup
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── kms/                      # KMS keyring & keys
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── cloud-run/                # Cloud Run service
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── cloud-tasks/              # Cloud Tasks queues
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── secret-manager/           # Secret Manager secrets
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── service-accounts/         # IAM service accounts
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── scheduler/                # Cloud Scheduler jobs
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
└── scripts/                      # Helper scripts
    ├── init-backend.sh           # Initialize Terraform backend
    ├── apply-all.sh              # Apply all environments
    └── destroy-env.sh            # Destroy specific environment
```

---

## Prerequisites

### Install Terraform

```bash
# macOS
brew install terraform

# Linux
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

# Verify installation
terraform version
```

### Authenticate to GCP

```bash
# Login to GCP
gcloud auth application-default login

# Set default project (optional)
gcloud config set project mentions-dev
```

### Create GCS Buckets for Terraform State

```bash
# Development
gcloud storage buckets create gs://mentions-terraform-state-dev \
  --project=mentions-dev \
  --location=us-central1 \
  --uniform-bucket-level-access

# Staging
gcloud storage buckets create gs://mentions-terraform-state-staging \
  --project=mentions-staging \
  --location=us-central1 \
  --uniform-bucket-level-access

# Production
gcloud storage buckets create gs://mentions-terraform-state-prod \
  --project=mentions-prod \
  --location=us-central1 \
  --uniform-bucket-level-access

# Enable versioning for state rollback
gcloud storage buckets update gs://mentions-terraform-state-prod \
  --versioning
```

---

## Core Modules

### 1. Project Module

`modules/project/main.tf`:

```hcl
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "project_name" {
  description = "GCP Project Name"
  type        = string
}

variable "billing_account" {
  description = "Billing account ID"
  type        = string
}

variable "org_id" {
  description = "GCP Organization ID"
  type        = string
  default     = ""
}

# Enable required APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "cloudtasks.googleapis.com",
    "cloudscheduler.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudkms.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "compute.googleapis.com",
  ])

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}

output "project_id" {
  value = var.project_id
}

output "project_number" {
  value = google_project_service.apis["run.googleapis.com"].project
}
```

### 2. KMS Module

`modules/kms/main.tf`:

```hcl
variable "project_id" {
  type = string
}

variable "location" {
  type    = string
  default = "us-central1"
}

variable "keyring_name" {
  type    = string
  default = "reddit-secrets"
}

variable "key_name" {
  type    = string
  default = "reddit-token-key"
}

# Create KMS Keyring
resource "google_kms_key_ring" "reddit_secrets" {
  name     = var.keyring_name
  location = var.location
  project  = var.project_id
}

# Create KMS Crypto Key
resource "google_kms_crypto_key" "reddit_token_key" {
  name     = var.key_name
  key_ring = google_kms_key_ring.reddit_secrets.id

  rotation_period = "7776000s" # 90 days

  lifecycle {
    prevent_destroy = true
  }
}

output "keyring_id" {
  value = google_kms_key_ring.reddit_secrets.id
}

output "crypto_key_id" {
  value = google_kms_crypto_key.reddit_token_key.id
}
```

### 3. Service Accounts Module

`modules/service-accounts/main.tf`:

```hcl
variable "project_id" {
  type = string
}

variable "location" {
  type = string
}

variable "kms_crypto_key_id" {
  description = "KMS crypto key ID for encryption/decryption"
  type        = string
}

# Backend service account
resource "google_service_account" "backend" {
  account_id   = "mentions-backend"
  display_name = "Mentions Backend Service Account"
  project      = var.project_id
}

# Grant KMS permissions
resource "google_kms_crypto_key_iam_member" "backend_kms" {
  crypto_key_id = var.kms_crypto_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.backend.email}"
}

# Grant Secret Manager access
resource "google_project_iam_member" "backend_secrets" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.backend.email}"
}

# Grant Cloud Tasks enqueuer
resource "google_project_iam_member" "backend_tasks" {
  project = var.project_id
  role    = "roles/cloudtasks.enqueuer"
  member  = "serviceAccount:${google_service_account.backend.email}"
}

output "backend_service_account_email" {
  value = google_service_account.backend.email
}
```

### 4. Secret Manager Module

`modules/secret-manager/main.tf`:

```hcl
variable "project_id" {
  type = string
}

variable "secrets" {
  description = "Map of secret names to initial values (use empty string if setting manually)"
  type        = map(string)
  default     = {}
}

resource "google_secret_manager_secret" "secrets" {
  for_each = var.secrets

  secret_id = each.key
  project   = var.project_id

  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "versions" {
  for_each = {
    for k, v in var.secrets : k => v
    if v != ""
  }

  secret      = google_secret_manager_secret.secrets[each.key].id
  secret_data = each.value
}

output "secret_ids" {
  value = {
    for k, v in google_secret_manager_secret.secrets : k => v.id
  }
}
```

### 5. Cloud Run Module

`modules/cloud-run/main.tf`:

```hcl
variable "project_id" {
  type = string
}

variable "location" {
  type = string
}

variable "service_name" {
  type = string
}

variable "image" {
  description = "Container image URL"
  type        = string
}

variable "service_account_email" {
  type = string
}

variable "env_vars" {
  description = "Environment variables"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Secrets from Secret Manager"
  type = map(object({
    secret_name = string
    version     = string
  }))
  default = {}
}

variable "allow_unauthenticated" {
  type    = bool
  default = false
}

variable "max_instances" {
  type    = number
  default = 10
}

variable "min_instances" {
  type    = number
  default = 0
}

variable "memory" {
  type    = string
  default = "1Gi"
}

variable "cpu" {
  type    = string
  default = "1"
}

resource "google_cloud_run_v2_service" "service" {
  name     = var.service_name
  location = var.location
  project  = var.project_id

  template {
    service_account = var.service_account_email

    scaling {
      max_instance_count = var.max_instances
      min_instance_count = var.min_instances
    }

    containers {
      image = var.image

      resources {
        limits = {
          memory = var.memory
          cpu    = var.cpu
        }
      }

      dynamic "env" {
        for_each = var.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = var.secrets
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value.secret_name
              version = env.value.version
            }
          }
        }
      }

      ports {
        container_port = 8000
      }
    }

    timeout = "300s"
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

# Allow public access if specified
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  count = var.allow_unauthenticated ? 1 : 0

  project  = var.project_id
  location = var.location
  name     = google_cloud_run_v2_service.service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

output "service_url" {
  value = google_cloud_run_v2_service.service.uri
}

output "service_name" {
  value = google_cloud_run_v2_service.service.name
}
```

### 6. Cloud Tasks Module

`modules/cloud-tasks/main.tf`:

```hcl
variable "project_id" {
  type = string
}

variable "location" {
  type = string
}

variable "queues" {
  description = "Map of queue names to configuration"
  type = map(object({
    max_concurrent_dispatches = number
    max_attempts              = number
    max_retry_duration        = string
  }))
}

resource "google_cloud_tasks_queue" "queues" {
  for_each = var.queues

  name     = each.key
  location = var.location
  project  = var.project_id

  rate_limits {
    max_concurrent_dispatches = each.value.max_concurrent_dispatches
  }

  retry_config {
    max_attempts       = each.value.max_attempts
    max_retry_duration = each.value.max_retry_duration
  }
}

output "queue_names" {
  value = {
    for k, v in google_cloud_tasks_queue.queues : k => v.name
  }
}
```

---

## Environment Configuration

### Development Environment

`environments/dev/main.tf`:

```hcl
terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    bucket = "mentions-terraform-state-dev"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  env = "dev"
}

# Project setup
module "project" {
  source = "../../modules/project"

  project_id      = var.project_id
  project_name    = "Mentions Dev"
  billing_account = var.billing_account
  org_id          = var.org_id
}

# KMS
module "kms" {
  source = "../../modules/kms"

  project_id   = var.project_id
  location     = var.region
  keyring_name = "reddit-secrets"
  key_name     = "reddit-token-key"

  depends_on = [module.project]
}

# Service Accounts
module "service_accounts" {
  source = "../../modules/service-accounts"

  project_id        = var.project_id
  location          = var.region
  kms_crypto_key_id = module.kms.crypto_key_id

  depends_on = [module.project]
}

# Secret Manager
module "secrets" {
  source = "../../modules/secret-manager"

  project_id = var.project_id
  secrets = {
    "openai-api-key"             = ""  # Set manually via console
    "supabase-service-role-key"  = ""  # Set manually
    "db-connection-string"       = ""  # Set manually
    "stripe-secret-key"          = ""  # Set manually
    "stripe-webhook-secret"      = ""  # Set manually
  }

  depends_on = [module.project]
}

# Cloud Tasks Queues
module "cloud_tasks" {
  source = "../../modules/cloud-tasks"

  project_id = var.project_id
  location   = var.region

  queues = {
    "reddit-posts-default" = {
      max_concurrent_dispatches = 10
      max_attempts              = 3
      max_retry_duration        = "3600s"
    }
    "generate-drafts" = {
      max_concurrent_dispatches = 5
      max_attempts              = 2
      max_retry_duration        = "1800s"
    }
    "verify-posts" = {
      max_concurrent_dispatches = 20
      max_attempts              = 3
      max_retry_duration        = "1800s"
    }
  }

  depends_on = [module.project]
}

# Cloud Run Backend
module "backend" {
  source = "../../modules/cloud-run"

  project_id            = var.project_id
  location              = var.region
  service_name          = "mentions-backend"
  image                 = var.backend_image
  service_account_email = module.service_accounts.backend_service_account_email
  allow_unauthenticated = true

  env_vars = {
    ENV                = "dev"
    GOOGLE_PROJECT_ID  = var.project_id
    GOOGLE_LOCATION    = var.region
    KMS_KEYRING        = "reddit-secrets"
    KMS_KEY            = "reddit-token-key"
    SUPABASE_URL       = var.supabase_url
    ALLOW_POSTS        = "false"
    LOG_LEVEL          = "DEBUG"
    LOG_JSON           = "true"
  }

  secrets = {
    OPENAI_API_KEY             = { secret_name = "openai-api-key", version = "latest" }
    SUPABASE_SERVICE_ROLE_KEY  = { secret_name = "supabase-service-role-key", version = "latest" }
    DB_CONN                    = { secret_name = "db-connection-string", version = "latest" }
  }

  max_instances = 10
  min_instances = 0
  memory        = "1Gi"
  cpu           = "1"

  depends_on = [
    module.project,
    module.service_accounts,
    module.secrets
  ]
}

output "backend_url" {
  value = module.backend.service_url
}

output "service_account_email" {
  value = module.service_accounts.backend_service_account_email
}
```

`environments/dev/variables.tf`:

```hcl
variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "mentions-dev"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "billing_account" {
  description = "GCP Billing Account ID"
  type        = string
}

variable "org_id" {
  description = "GCP Organization ID"
  type        = string
  default     = ""
}

variable "backend_image" {
  description = "Backend container image"
  type        = string
  default     = "gcr.io/mentions-dev/backend:latest"
}

variable "supabase_url" {
  description = "Supabase project URL"
  type        = string
}
```

`environments/dev/terraform.tfvars`:

```hcl
project_id      = "mentions-dev"
region          = "us-central1"
billing_account = "XXXXX-XXXXX-XXXXX"
org_id          = ""  # Optional

supabase_url    = "https://xxx.supabase.co"
backend_image   = "gcr.io/mentions-dev/backend:latest"
```

### Production Environment

`environments/prod/main.tf`:

```hcl
# Similar to dev/main.tf but with production values

terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    bucket = "mentions-terraform-state-prod"
    prefix = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  env = "prod"
}

# ... (similar module calls with production-specific values)

# Cloud Run Backend with production settings
module "backend" {
  source = "../../modules/cloud-run"

  project_id            = var.project_id
  location              = var.region
  service_name          = "mentions-backend"
  image                 = var.backend_image
  service_account_email = module.service_accounts.backend_service_account_email
  allow_unauthenticated = false  # Require authentication in prod

  env_vars = {
    ENV                = "prod"
    GOOGLE_PROJECT_ID  = var.project_id
    GOOGLE_LOCATION    = var.region
    KMS_KEYRING        = "reddit-secrets"
    KMS_KEY            = "reddit-token-key"
    SUPABASE_URL       = var.supabase_url
    ALLOW_POSTS        = "true"  # Enable posting in production
    LOG_LEVEL          = "INFO"
    LOG_JSON           = "true"
  }

  secrets = {
    OPENAI_API_KEY             = { secret_name = "openai-api-key", version = "latest" }
    SUPABASE_SERVICE_ROLE_KEY  = { secret_name = "supabase-service-role-key", version = "latest" }
    DB_CONN                    = { secret_name = "db-connection-string", version = "latest" }
    STRIPE_SECRET_KEY          = { secret_name = "stripe-secret-key", version = "latest" }
    STRIPE_WEBHOOK_SECRET      = { secret_name = "stripe-webhook-secret", version = "latest" }
  }

  max_instances = 50
  min_instances = 1   # Keep warm in production
  memory        = "2Gi"
  cpu           = "2"

  depends_on = [
    module.project,
    module.service_accounts,
    module.secrets
  ]
}
```

---

## Deployment Workflow

### Initialize Environment

```bash
cd mentions_terraform/environments/dev

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt -recursive
```

### Plan Changes

```bash
# See what will be created/changed
terraform plan

# Save plan to file
terraform plan -out=tfplan
```

### Apply Changes

```bash
# Apply with approval prompt
terraform apply

# Apply saved plan
terraform apply tfplan

# Auto-approve (use carefully!)
terraform apply -auto-approve
```

### View State

```bash
# List all resources
terraform state list

# Show specific resource
terraform state show module.backend.google_cloud_run_v2_service.service

# Show outputs
terraform output
terraform output backend_url
```

### Destroy Resources (Careful!)

```bash
# Destroy all resources
terraform destroy

# Destroy specific resource
terraform destroy -target=module.backend
```

---

## Helper Scripts

### `scripts/init-backend.sh`

```bash
#!/bin/bash
# Initialize Terraform backend for an environment

set -e

ENV=$1

if [ -z "$ENV" ]; then
  echo "Usage: ./init-backend.sh <dev|staging|prod>"
  exit 1
fi

PROJECT_ID="mentions-${ENV}"
BUCKET="mentions-terraform-state-${ENV}"
LOCATION="us-central1"

echo "Initializing Terraform backend for ${ENV}..."

# Create bucket if it doesn't exist
if ! gcloud storage buckets describe gs://${BUCKET} &>/dev/null; then
  echo "Creating state bucket..."
  gcloud storage buckets create gs://${BUCKET} \
    --project=${PROJECT_ID} \
    --location=${LOCATION} \
    --uniform-bucket-level-access
  
  # Enable versioning
  gcloud storage buckets update gs://${BUCKET} --versioning
  
  echo "Bucket created: gs://${BUCKET}"
else
  echo "Bucket already exists: gs://${BUCKET}"
fi

# Initialize Terraform
cd environments/${ENV}
terraform init

echo "Backend initialized successfully!"
```

### `scripts/apply-all.sh`

```bash
#!/bin/bash
# Apply Terraform configuration to all environments

set -e

ENVIRONMENTS=("dev" "staging" "prod")

for ENV in "${ENVIRONMENTS[@]}"; do
  echo "========================================="
  echo "Applying Terraform for ${ENV}..."
  echo "========================================="
  
  cd environments/${ENV}
  terraform init
  terraform plan -out=tfplan
  
  read -p "Apply changes to ${ENV}? (yes/no) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    terraform apply tfplan
    echo "${ENV} applied successfully!"
  else
    echo "Skipping ${ENV}"
  fi
  
  cd ../..
done
```

---

## State Management

### Remote State

All environments use GCS backend for state storage:

```hcl
terraform {
  backend "gcs" {
    bucket = "mentions-terraform-state-dev"
    prefix = "terraform/state"
  }
}
```

### State Locking

GCS provides automatic state locking to prevent concurrent modifications.

### State Import

Import existing resources:

```bash
# Import existing Cloud Run service
terraform import module.backend.google_cloud_run_v2_service.service \
  projects/mentions-dev/locations/us-central1/services/mentions-backend
```

### State Migration

Move resources between modules:

```bash
# Move resource to different module
terraform state mv \
  google_cloud_run_service.backend \
  module.backend.google_cloud_run_service.service
```

---

## Best Practices

### Version Control

✅ **Commit these files:**
- All `.tf` files
- `.terraform.lock.hcl` (lock file)
- `terraform.tfvars.example`

❌ **Never commit:**
- `.terraform/` directory
- `*.tfstate` files
- `terraform.tfvars` (contains secrets)
- `tfplan` files

### Secret Management

- Never hardcode secrets in `.tf` files
- Use Secret Manager for sensitive values
- Set secret values manually via GCP Console or `gcloud`:

```bash
# Set secret value
echo -n "sk-..." | gcloud secrets versions add openai-api-key --data-file=-
```

### Environment Isolation

- Each environment has its own:
  - GCP project
  - Terraform state bucket
  - Service accounts
  - Secrets
- No shared resources between environments

### Naming Conventions

- Projects: `mentions-{env}`
- Buckets: `mentions-terraform-state-{env}`
- Service accounts: `mentions-{service}@{project}.iam.gserviceaccount.com`
- Services: `mentions-{service}`

### Terraform Formatting

```bash
# Format all .tf files
terraform fmt -recursive

# Check formatting
terraform fmt -check -recursive
```

### Validation

```bash
# Validate configuration
terraform validate

# Run terraform plan before apply
terraform plan
```

---

## CI/CD Integration

### GitHub Actions Workflow

`.github/workflows/terraform-plan.yml`:

```yaml
name: Terraform Plan

on:
  pull_request:
    paths:
      - 'mentions_terraform/**'

jobs:
  plan:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, staging, prod]
    
    steps:
      - name: Checkout
        uses: actions/checkout@v3
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.0
      
      - name: Authenticate to GCP
        uses: google-github-actions/auth@v1
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}
      
      - name: Terraform Init
        working-directory: mentions_terraform/environments/${{ matrix.environment }}
        run: terraform init
      
      - name: Terraform Plan
        working-directory: mentions_terraform/environments/${{ matrix.environment }}
        run: terraform plan -no-color
```

`.github/workflows/terraform-apply.yml`:

```yaml
name: Terraform Apply

on:
  push:
    branches:
      - main
    paths:
      - 'mentions_terraform/**'

jobs:
  apply:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout
        uses: actions/checkout@v3
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
      
      - name: Authenticate to GCP
        uses: google-github-actions/auth@v1
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}
      
      - name: Terraform Apply - Dev
        working-directory: mentions_terraform/environments/dev
        run: |
          terraform init
          terraform apply -auto-approve
      
      # Add staging and prod with appropriate safeguards
```

---

## Troubleshooting

### State Lock Issues

```bash
# Force unlock (use carefully!)
terraform force-unlock <LOCK_ID>
```

### Import Existing Resources

```bash
# List resources to import
terraform plan

# Import resource
terraform import <resource_address> <resource_id>
```

### Debug Mode

```bash
# Enable debug logging
export TF_LOG=DEBUG
terraform apply
```

### State Corruption

```bash
# Pull remote state
terraform state pull > backup.tfstate

# Push state (use carefully!)
terraform state push backup.tfstate
```

---

## Migration from Manual Setup

If you already created resources manually via `gcloud`, import them:

```bash
cd mentions_terraform/environments/dev

# Import KMS keyring
terraform import module.kms.google_kms_key_ring.reddit_secrets \
  projects/mentions-dev/locations/us-central1/keyRings/reddit-secrets

# Import KMS key
terraform import module.kms.google_kms_crypto_key.reddit_token_key \
  projects/mentions-dev/locations/us-central1/keyRings/reddit-secrets/cryptoKeys/reddit-token-key

# Import Cloud Run service
terraform import module.backend.google_cloud_run_v2_service.service \
  projects/mentions-dev/locations/us-central1/services/mentions-backend

# ... import other resources
```

---

## Quick Reference

### Common Commands

```bash
# Initialize
terraform init

# Validate
terraform validate

# Format
terraform fmt

# Plan
terraform plan

# Apply
terraform apply

# Destroy
terraform destroy

# Show state
terraform state list
terraform state show <resource>

# Show outputs
terraform output
```

### Directory Navigation

```bash
# Development
cd mentions_terraform/environments/dev

# Staging
cd mentions_terraform/environments/staging

# Production
cd mentions_terraform/environments/prod
```

---

## Next Steps

1. Create `mentions_terraform/` directory
2. Copy module definitions from this document
3. Configure environment-specific `terraform.tfvars`
4. Initialize Terraform: `./scripts/init-backend.sh dev`
5. Plan changes: `terraform plan`
6. Apply infrastructure: `terraform apply`
7. Update **02-ENVIRONMENT-SETUP.md** to reference Terraform

All infrastructure changes should now go through Terraform for consistency and reproducibility across environments.






