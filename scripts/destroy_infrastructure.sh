#!/usr/bin/env bash

set -euxo pipefail

TERRAFORM_STATE_BUCKET="${TERRAFORM_STATE_BUCKET:-eq-terraform-load-generator-tfstate}"

terraform init --upgrade --backend-config prefix="${PROJECT_ID}" --backend-config bucket="${TERRAFORM_STATE_BUCKET}"

# Destroy infrastructure
terraform destroy --auto-approve -var "project_id=${PROJECT_ID}"

# Import bucket resource back into the state
terraform import -var "project_id=${PROJECT_ID}" google_storage_bucket.benchmark-output-storage "${PROJECT_ID}"-outputs
