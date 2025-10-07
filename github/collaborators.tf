###############################################################
# github/collaborators.tf
# Adds repo collaborators with "push" (write) permission
# CHANGE the usernames below to your actual accounts.
###############################################################

locals {
  repo = var.repo_name
}

resource "github_repository_collaborator" "reviewer_1" {
  repository = local.repo
  username   = "bondkebs1" # <-- CHANGE if needed
  permission = "push"      # push = write; can review/approve PRs
}

resource "github_repository_collaborator" "reviewer_2" {
  repository = local.repo
  username   = "bondkebs" # <-- CHANGE to the real username
  permission = "push"
}
