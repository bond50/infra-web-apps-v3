###############################################################
# GitHub Branch Protection (Terraform-managed)
# - Provider: integrations/github
# - Patterns covered: main, develop, release/*, hotfix/*
# - Requires a token with "repo:admin" scope when applying
###############################################################

locals {
  # GitHub Actions job name used in your PR gate.
  # This is the check name that shows on PRs.
  pr_gate_context = "05 - PR Quality Gate / pr-quality"
}

# -------------------- MAIN (production, strict) --------------------
resource "github_branch_protection" "main" {
  repository_id                   = var.repo_name # you can pass the repo name directly
  pattern                         = "main"
  enforce_admins                  = true
  allows_deletions                = false # block branch deletion
  allows_force_pushes             = false # block force pushes
  required_linear_history         = true
  require_conversation_resolution = true # <-- from docs

  required_status_checks {
    strict   = true # branch must be up-to-date before merge
    contexts = [local.pr_gate_context]
  }

  required_pull_request_reviews {
    required_approving_review_count = 2
    dismiss_stale_reviews           = true
    require_code_owner_review       = true # set false if you don't use CODEOWNERS
    require_last_push_approval      = true
  }
}

# -------------------- DEVELOP (integration, strong) --------------------
resource "github_branch_protection" "develop" {
  repository_id                   = var.repo_name
  pattern                         = "develop"
  enforce_admins                  = true
  allows_deletions                = false
  allows_force_pushes             = false
  required_linear_history         = true
  require_conversation_resolution = true

  required_status_checks {
    strict   = false # up-to-date not strictly required on develop
    contexts = [local.pr_gate_context]
  }

  required_pull_request_reviews {
    required_approving_review_count = 1
    dismiss_stale_reviews           = true
    require_code_owner_review       = false
    require_last_push_approval      = true
  }
}

# -------------------- RELEASE/* (stabilization, like main) --------------------
resource "github_branch_protection" "release_star" {
  repository_id                   = var.repo_name
  pattern                         = "release/*"
  enforce_admins                  = true
  allows_deletions                = false
  allows_force_pushes             = false
  required_linear_history         = true
  require_conversation_resolution = true

  required_status_checks {
    strict   = true
    contexts = [local.pr_gate_context]
  }

  required_pull_request_reviews {
    required_approving_review_count = 2
    dismiss_stale_reviews           = true
    require_code_owner_review       = true
    require_last_push_approval      = true
  }
}

# -------------------- HOTFIX/* (urgent, fast but reviewed) --------------------
resource "github_branch_protection" "hotfix_star" {
  repository_id                   = var.repo_name
  pattern                         = "hotfix/*"
  enforce_admins                  = true
  allows_deletions                = false
  allows_force_pushes             = false
  required_linear_history         = true
  require_conversation_resolution = true

  required_status_checks {
    strict   = false
    contexts = [local.pr_gate_context]
  }

  required_pull_request_reviews {
    required_approving_review_count = 1
    dismiss_stale_reviews           = true
    require_code_owner_review       = false
    require_last_push_approval      = true
  }
}
