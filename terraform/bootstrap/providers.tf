###############################################################
# bootstrap/providers.tf
# Purpose: Providers used ONLY for bootstrapping:
# - AWS: create S3 state bucket + DynamoDB lock table + OIDC role
# - GitHub: write repo variables so later workflows can use them
###############################################################
terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 6.0"
    }
    github = {
      source  = "integrations/github"
      version = ">= 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Uses GH_ADMIN_TOKEN from GitHub Actions (env) for write access
provider "github" {
  owner = var.github_owner
  token = var.github_token != "" ? var.github_token : null
}
