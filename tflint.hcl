###############################################################
# .tflint.hcl
# Purpose:
#  - Enable BOTH TFLint plugins:
#      * Terraform Language ruleset  -> syntax/best-practices for TF language
#      * AWS ruleset                 -> provider-specific best-practices
#  - Used by CI (05 - PR Quality Gate) and by devs locally.
# How it works:
#  - `tflint --init` reads this file and downloads the plugins below.
#  - Then `tflint` runs rules from core + these rulesets.
# Requirements:
#  - TFLint v0.42+ (both plugins require this or newer).
###############################################################

# -------------------------------------------------------------
# Plugin: Terraform Language ruleset (pin exact version)
#   - Source : github.com/terraform-linters/tflint-ruleset-terraform
#   - Version: v0.13.0  (latest as of 2025-08-02)
#     Update steps:
#       1) Bump version here
#       2) Run `tflint --init` locally
#       3) Commit updated plugin lock artifacts if generated
# -------------------------------------------------------------
plugin "terraform" {
  enabled = true                                 # turn on TF language checks
  version = "0.13.0"                             # <-- pinned ruleset version
  source  = "github.com/terraform-linters/tflint-ruleset-terraform"
}

# -------------------------------------------------------------
# Plugin: AWS ruleset (pin exact version)
#   - Source : github.com/terraform-linters/tflint-ruleset-aws
#   - Version: v0.43.0  (latest as of 2025-09-20)
#     Update steps:
#       1) Bump version here
#       2) Run `tflint --init` locally
#       3) Commit updated plugin lock artifacts if generated
# -------------------------------------------------------------
plugin "aws" {
  enabled = true                                 # turn on AWS-specific checks
  version = "0.43.0"                             # <-- pinned ruleset version
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# -------------------------------------------------------------
# Global rule toggles (keep strict by default; tune as needed)
# -------------------------------------------------------------
rule "terraform_deprecated_interpolation" { enabled = true }  # prefer modern syntax
rule "terraform_unused_declarations"       { enabled = true }  # catch dead vars/locals
rule "terraform_naming_convention"         { enabled = true }  # consistent names

# Example org policy: require baseline tags (uncomment to enforce)
# rule "aws_resource_missing_tags" {
#   enabled = true
#   tags    = ["Project", "Usage"]              # enforce these tag keys exist
# }

# Example suppression: disable a specific noisy rule by ID
# rule "aws_instance_invalid_type" { enabled = false }

# Optional: ignore folders (generated/vendor)
# ignore_paths = ["**/.terraform/**/*", "modules/experimental/**"]
