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
  pr_gate_context = "05 - PR Quality Gate / pr-quality"
}

# ---- MAIN BRANCH----
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

# ---- DEVELOP BRANCH----
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
# === ADDED: Enforce squash-only merges at repository level ===
# GitHub exposes allowed merge methods on the repo, not via rulesets.
# This disables Merge commit and Rebase, leaving Squash as the only option.
resource "github_repository" "repo" {
  name                   = var.repo_name
  allow_merge_commit     = false # ADDED: disable "Merge commit"
  allow_rebase_merge     = false # ADDED: disable "Rebase and merge"
  allow_squash_merge     = true  # ADDED: keep Squash
  delete_branch_on_merge = true  # ADDED: tidy merged branches automatically

  # Optional: make squash commit title/body mirror the PR
  squash_merge_commit_title   = "PR_TITLE"
  squash_merge_commit_message = "PR_BODY"
}
