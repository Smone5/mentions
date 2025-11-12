# Mentions Terraform Infrastructure

This directory contains all Terraform code for managing GCP infrastructure across dev, staging, and production environments.

## Quick Start

### Prerequisites

1. Install Terraform: `brew install terraform`
2. Authenticate to GCP: `gcloud auth application-default login`
3. Ensure you have billing account ID ready

### Initial Setup

1. **Create GCP Projects** (if not done already):
   ```bash
   cd ../scripts
   ./setup-environments.sh
   ```

2. **Initialize Terraform Backend**:
   ```bash
   ./scripts/init-backend.sh dev
   ```

3. **Configure Variables**:
   ```bash
   cd environments/dev
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

4. **Plan and Apply**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Directory Structure

- `modules/` - Reusable Terraform modules
- `environments/` - Environment-specific configurations
- `scripts/` - Helper scripts

## Documentation

See [docs/28-TERRAFORM-INFRASTRUCTURE.md](../docs/28-TERRAFORM-INFRASTRUCTURE.md) for complete documentation.


