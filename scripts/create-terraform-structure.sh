#!/bin/bash
# This script creates the Terraform structure (already done, but kept for reference)

echo "Terraform structure has already been created!"
echo "See: mentions_terraform/"
echo ""
echo "To initialize an environment:"
echo "  cd mentions_terraform/environments/dev"
echo "  cp terraform.tfvars.example terraform.tfvars"
echo "  # Edit terraform.tfvars"
echo "  ../../scripts/init-backend.sh dev"
echo "  terraform init"
echo "  terraform plan"
echo "  terraform apply"


