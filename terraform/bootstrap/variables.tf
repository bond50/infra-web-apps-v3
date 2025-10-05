###############################################################
# bootstrap/variables.tf
# Inputs for bootstrap run (supplied via workflow inputs/vars)
# These define the configuration parameters needed to set up the
# AWS backend and the CI/CD connection to GitHub.
###############################################################
variable "aws_region" {
  description = "AWS region for backend + role"
  type        = string
  # CRITICAL FIX: The default value has a trailing single quote that should be removed.
  default = "us-east-1"
}

variable "project_name" {
  description = "Project short name (used in names, e.g., 'web-app')"
  type        = string
  # NOTE: This variable is required. It's good practice to omit the 'default'
  # so Terraform forces the user or workflow to supply it.
}

variable "bucket_name" {
  description = "S3 bucket name for Terraform state (must be globally unique)"
  type        = string
  default     = ""
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
}

variable "tf_state_key" {
  description = "State key path inside the bucket (e.g., infra/terraform.tfstate)"
  type        = string
}

variable "github_owner" {
  description = "GitHub org/user that owns the repo (e.g., 'bond5')"
  type        = string
  default     = "bond50"
}

variable "github_repo" {
  description = "GitHub repository name (e.g., 'infra-web-apps-v3') - DO NOT include the owner/org."
  type        = string
  # CRITICAL FIX: The default value here includes the owner and a leading slash, which is incorrect
  # for the GitHub provider. It should only be the repository name.
  default = "infra-web-apps-v3"
}

variable "github_token" {
  description = "Fine-grained PAT to let Terraform write repo variables (passed as a secret)"
  type        = string
  default     = "" # Defaulting to empty string is okay for a secret/token variable.
}
