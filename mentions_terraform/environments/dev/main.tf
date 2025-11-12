terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    bucket = "mention001-terraform-state"
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

# Project setup (APIs only - project already exists)
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
    "stripe-secret-key"          = ""  # Set manually (optional)
    "stripe-webhook-secret"      = ""  # Set manually (optional)
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

# Cloud Run Backend (commented out until image is built)
# module "backend" {
#   source = "../../modules/cloud-run"
#
#   project_id            = var.project_id
#   location              = var.region
#   service_name          = "mentions-backend"
#   image                 = var.backend_image
#   service_account_email = module.service_accounts.backend_service_account_email
#   allow_unauthenticated = true
#
#   env_vars = {
#     ENV                = "dev"
#     GOOGLE_PROJECT_ID  = var.project_id
#     GOOGLE_LOCATION    = var.region
#     KMS_KEYRING        = "reddit-secrets"
#     KMS_KEY            = "reddit-token-key"
#     SUPABASE_URL       = var.supabase_url
#     ALLOW_POSTS        = "false"
#     LOG_LEVEL          = "DEBUG"
#     LOG_JSON           = "true"
#   }
#
#   secrets = {
#     OPENAI_API_KEY             = { secret_name = "openai-api-key", version = "latest" }
#     SUPABASE_SERVICE_ROLE_KEY  = { secret_name = "supabase-service-role-key", version = "latest" }
#     DB_CONN                    = { secret_name = "db-connection-string", version = "latest" }
#   }
#
#   max_instances = 10
#   min_instances = 0
#   memory        = "1Gi"
#   cpu           = "1"
#
#   depends_on = [
#     module.project,
#     module.service_accounts,
#     module.secrets
#   ]
# }

# Backend outputs
# 
# When backend module is enabled (uncommented above), replace the placeholder output below
# with these outputs:
#
# output "backend_url" {
#   description = "Cloud Run backend service URL (for NEXT_PUBLIC_API_URL in Vercel)"
#   value       = module.backend.service_url
# }
#
# output "backend_service_name" {
#   description = "Cloud Run backend service name"
#   value       = module.backend.service_name
# }
#
# output "vercel_api_url" {
#   description = "Formatted output for Vercel NEXT_PUBLIC_API_URL environment variable"
#   value       = module.backend.service_url
# }

# Placeholder output until backend is deployed
output "backend_url" {
  description = "Cloud Run backend service URL (for NEXT_PUBLIC_API_URL in Vercel). Uncomment backend module above to deploy."
  value       = "Backend not deployed yet. Uncomment backend module in main.tf and run terraform apply."
}

output "service_account_email" {
  value = module.service_accounts.backend_service_account_email
}

output "kms_crypto_key_id" {
  value = module.kms.crypto_key_id
}


