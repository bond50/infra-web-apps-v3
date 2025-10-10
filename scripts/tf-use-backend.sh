#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:=us-east-1}"
: "${TF_STATE_BUCKET:=webapps-tf-state-123}"
: "${TF_STATE_KEY:=infra/terraform.tfstate}"
: "${TF_STATE_TABLE:=tf-locks-webapps-tf-state-123}"

rm -rf .terraform .terraform.lock.hcl

terraform init -input=false -reconfigure \
-backend-config="bucket=${TF_STATE_BUCKET}" \
-backend-config="key=${TF_STATE_KEY}/live/terraform.tfstate" \
-backend-config="region=${AWS_REGION}" \
-backend-config="dynamodb_table=${TF_STATE_TABLE}" \
-backend-config="encrypt=true"

terraform workspace select default || terraform workspace new default
terraform workspace show
