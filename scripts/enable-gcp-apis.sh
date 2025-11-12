#!/bin/bash
# Enable required GCP APIs for mention001

set -e

PROJECT_ID="mention001"

echo "Enabling required APIs for $PROJECT_ID..."

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

for API in "${APIS[@]}"; do
    echo -n "Enabling $API... "
    if gcloud services enable "$API" --project="$PROJECT_ID" 2>&1 | grep -q "already enabled"; then
        echo "✓ Already enabled"
    else
        echo "✓ Enabled"
    fi
done

echo ""
echo "All APIs enabled!"

