###############################################################
# backend.tf
# Keep the S3 backend block EMPTY. GitHub Actions will pass
# -backend-config values from repo Variables (bucket/table/key/region).
#
# This setup ensures the Terraform backend configuration is dynamically
# injected at runtime by the CI/CD pipeline, maintaining separation
# of concerns and avoiding hardcoded values in the repository.
###############################################################
terraform {
  # Define the S3 backend type.
  # The actual configuration details (bucket name, key, dynamodb table, etc.)
  # are intentionally omitted here.
  backend "s3" {}
}
