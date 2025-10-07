###############################################################
# Final Repo Rulesets
# - 1 approval on main & develop
# - block force-push & deletion on main/develop
# - keep history linear on main/develop (squash merges OK)
# - require only the PR Quality Gate; NOT strict (avoids "expected" hangs)
###############################################################
# locals {
#   pr_gate_context = "05 - PR Quality Gate / pr-quality"
# }

locals {
  # Match the exact name reported by GitHub Actions for a pull_request event
  pr_gate_context = "05 - PR Quality Gate / pr-quality (pull_request)"
}

# ---- MAIN ----
resource "github_repository_ruleset" "main" {
  repository  = var.repo_name
  name        = "main"
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["refs/heads/main"]
      exclude = []
    }
  }

  rules {
    pull_request {
      required_approving_review_count = 1
      dismiss_stale_reviews_on_push   = true
      require_code_owner_review       = false
      require_last_push_approval      = true
    }

    required_linear_history = true
    non_fast_forward        = true
    deletion                = true

    required_status_checks {
      strict_required_status_checks_policy = false
      required_check { context = local.pr_gate_context }
    }
  }
}

# ---- DEVELOP ----
resource "github_repository_ruleset" "develop" {
  repository  = var.repo_name
  name        = "develop"
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["refs/heads/develop"]
      exclude = []
    }
  }

  rules {
    pull_request {
      required_approving_review_count = 1
      dismiss_stale_reviews_on_push   = true
      require_code_owner_review       = false
      require_last_push_approval      = false
    }

    required_linear_history = true
    non_fast_forward        = true
    deletion                = true

    required_status_checks {
      strict_required_status_checks_policy = false
      required_check { context = local.pr_gate_context }
    }
  }
}
