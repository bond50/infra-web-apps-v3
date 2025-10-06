variable "github_owner" {
  description = "GitHub org/user owner"
  type        = string
  default     = "bond50"
}

variable "github_token" {
  description = "GitHub token with repo admin on this repo"
  type        = string
  sensitive   = true
}

variable "repo_name" {
  description = "Repository name (no owner), e.g., infra-web-apps-v3"
  type        = string
  default     = "infra-web-apps-v3"
}
