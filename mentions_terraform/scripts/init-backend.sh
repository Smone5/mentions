#!/bin/bash
# Initialize Terraform backend for an environment

set -e

ENV=$1

if [ -z "$ENV" ]; then
  echo "Usage: ./init-backend.sh <dev|staging|prod>"
  exit 1
fi

if [ "$ENV" = "dev" ]; then
  PROJECT_ID="mention001"
  BUCKET="mention001-terraform-state"
else
  PROJECT_ID="mentions-${ENV}"
  BUCKET="mentions-terraform-state-${ENV}"
fi
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


