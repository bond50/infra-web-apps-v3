###############################################################
# bootstrap/main.tf
# Creates:
# - S3 bucket for Terraform remote state (versioned + encrypted)
# - DynamoDB table for Terraform state locking
# - IAM OIDC provider for GitHub Actions
# - IAM role for GitHub Actions (assumable via OIDC)
# - GitHub repo variables: AWS_REGION, AWS_ROLE_ARN, TF_STATE_*
#
# This foundational module sets up the secure backend and
# CI/CD connectivity needed for all subsequent infrastructure.
###############################################################

# Retrieve the current caller's identity. Useful for validation,
# or for defining ARN-based policies that reference the account ID.
data "aws_caller_identity" "me" {}

############################
# S3 bucket for tfstate
############################
# This S3 bucket serves as the robust, highly available, and durable
# remote backend for storing Terraform state files.
resource "aws_s3_bucket" "tfstate" {
  bucket        = var.bucket_name
  force_destroy = false # Set to 'true' only for testing/cleanup; avoids accidental deletion of live state.

  tags = {
    Project = var.project_name
    Usage   = "terraform-state"
  }
}

# Enable versioning to keep a history of state files. This is a critical
# safety net, allowing rollbacks in case of a corrupted or undesired state.
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enforce server-side encryption (SSE-S3) for all objects written to the bucket.
# Security best practice ensures state data is encrypted at rest.
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # Simple yet effective AES-256 encryption.
    }
  }
}

# Block all forms of public access. Terraform state should be private!
# This is a strong layer of defense against accidental exposure.
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Optional: require TLS-only access to the bucket
# This denies any requests that do not come over HTTPS,
# ensuring the state file is transferred securely (in-flight encryption).
resource "aws_s3_bucket_policy" "tfstate_tls" {
  bucket = aws_s3_bucket.tfstate.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Deny",
      Principal = "*",
      Action    = "s3:*",
      Resource = [
        aws_s3_bucket.tfstate.arn,
        "${aws_s3_bucket.tfstate.arn}/*",
      ],
      Condition = {
        Bool = { "aws:SecureTransport" = "false" }
      }
    }]
  })
}

############################
# DynamoDB locking table
############################
# DynamoDB is used for state locking, which prevents concurrent Terraform
# operations from corrupting the remote state file. Essential for CI/CD!
resource "aws_dynamodb_table" "tf_lock" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST" # Cost-effective for low-frequency locking operations.
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S" # String type for the lock identifier.
  }

  tags = {
    Project = var.project_name
    Usage   = "terraform-locking"
  }
}

############################
# GitHub OIDC provider
############################
# Set up the OpenID Connect (OIDC) trust relationship with GitHub.
# This allows GitHub Actions to securely assume an AWS IAM Role without
# requiring long-lived AWS credentials (keys). Highly recommended security model!
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"] # The expected audience for the token.

  # Current GitHub Actions thumbprint (if AWS flags a change, update here)
  # This certificate thumbprint verifies the authenticity of the OIDC provider.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Project = var.project_name
    Usage   = "github-oidc"
  }
}

############################
# IAM role for GitHub Actions
############################
# Define the trust policy (Assume Role Policy) for the GitHub Actions role.
data "aws_iam_policy_document" "gha_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn] # Trust the GitHub OIDC provider.
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Crucially, restrict this trust to tokens originating from a specific GitHub repository.
    # This prevents other repos/accounts from assuming the role.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_owner}/${var.github_repo}:*" # Wildcard allows all branches/events.
      ]
    }
  }
}

# The actual IAM role that GitHub Actions will assume to deploy resources.
resource "aws_iam_role" "github_actions" {
  name               = "${var.project_name}-gha"
  assume_role_policy = data.aws_iam_policy_document.gha_assume_role.json

  tags = {
    Project = var.project_name
    Usage   = "github-actions"
  }
}

# Keep simple: attach AdministratorAccess now (tighten later if desired)
# *Note:* Full admin access is often used in bootstrap or management roles
# for simplicity, but it's best practice to scope this down to the
# minimum required permissions (e.g., S3/DynamoDB/IAM management) later.
resource "aws_iam_role_policy_attachment" "gha_admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

############################
# GitHub repo Variables (for later CI)
############################
# The following resources use the GitHub provider to automatically
# populate the GitHub repository's Actions environment variables.
# This simplifies the CI pipeline configuration.

# AWS Region where the infrastructure will be deployed.
resource "github_actions_variable" "aws_region" {
  repository    = var.github_repo
  variable_name = "AWS_REGION"
  value         = var.aws_region
}

# The ARN of the IAM role to be assumed by the GitHub Actions workflow.
resource "github_actions_variable" "aws_role_arn" {
  repository    = var.github_repo
  variable_name = "AWS_ROLE_ARN"
  value         = aws_iam_role.github_actions.arn
}

# The name of the S3 bucket where Terraform state is stored.
resource "github_actions_variable" "tf_state_bucket" {
  repository    = var.github_repo
  variable_name = "TF_STATE_BUCKET"
  value         = aws_s3_bucket.tfstate.bucket
}

# The name of the DynamoDB table used for state locking.
resource "github_actions_variable" "tf_state_table" {
  repository    = var.github_repo
  variable_name = "TF_STATE_TABLE"
  value         = aws_dynamodb_table.tf_lock.name
}

# The key (path) within the S3 bucket for the primary state file.
resource "github_actions_variable" "tf_state_key" {
  repository    = var.github_repo
  variable_name = "TF_STATE_KEY"
  value         = var.tf_state_key
}
