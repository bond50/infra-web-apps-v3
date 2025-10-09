terraform {
  required_version = ">= 1.13.0, < 2.0.0"
  backend "s3" {} # backend values provided by the workflow (OIDC to AWS)
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.3"
    }
  }
}
