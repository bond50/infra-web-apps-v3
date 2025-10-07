###############################################################
# github/rulesets.tf  (Repository Rulesets)
# Shows under: Settings → Rules → Rulesets
# Enforcement: active (blocking). Use "evaluate" to dry-run.
###############################################################

locals {
  pr_gate_context = "05 - PR Quality Gate / pr-quality"
}

# ===================== MAIN (production, strict) =====================
resource "github_repository_ruleset" "main" {
  repository  = var.repo_name
  name        = "main"
  target      = "branch"
  enforcement = "evaluate"

  conditions {
    ref_name {
      include = ["refs/heads/main"]
      exclude = []
    }
  }

  rules {
    pull_request {
      required_approving_review_count = 2
      dismiss_stale_reviews_on_push   = true
      require_code_owner_review       = true
      require_last_push_approval      = true
    }

    required_linear_history = true
    non_fast_forward        = true
    deletion                = true

    required_status_checks {
      strict_required_status_checks_policy = true
      required_check { context = local.pr_gate_context }
    }
  }
}

# ===================== DEVELOP (integration, strong) =====================
resource "github_repository_ruleset" "develop" {
  repository  = var.repo_name
  name        = "develop"
  target      = "branch"
  enforcement = "evaluate"

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

# ===================== RELEASE/* (like main) =====================
resource "github_repository_ruleset" "release_star" {
  repository  = var.repo_name
  name        = "release/*"
  target      = "branch"
  enforcement = "evaluate"

  conditions {
    ref_name {
      include = ["refs/heads/release/*"]
      exclude = []
    }
  }

  rules {
    pull_request {
      required_approving_review_count = 2
      dismiss_stale_reviews_on_push   = true
      require_code_owner_review       = true
      require_last_push_approval      = true
    }

    # required_linear_history = true  # TEMP disabled
    non_fast_forward        = true
    deletion                = true

    required_status_checks {
      strict_required_status_checks_policy = false
      required_check { context = local.pr_gate_context }
    }
  }
}

# ===================== HOTFIX/* (fast but reviewed) =====================
resource "github_repository_ruleset" "hotfix_star" {
  repository  = var.repo_name
  name        = "hotfix/*"
  target      = "branch"
  enforcement = "evaluate"

  conditions {
    ref_name {
      include = ["refs/heads/hotfix/*"]
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
