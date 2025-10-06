###############################################################
# .tflint.hcl
# Purpose:
#  - Configure TFLint behavior for Terraform code.
#  - (Optional) Enable AWS ruleset plugin for deeper best-practices.
# Notes:
#  - The GitHub Actions workflow installs TFLint and runs:
#       tflint --init
#       tflint -f compact
#  - "--init" reads this file and installs any declared plugins.
###############################################################

# Strict mode: non-zero exit on any error (default behavior).
# leave as-is; our CI should fail fast if there's a real issue.

# OPTIONAL: AWS ruleset plugin (uncomment to enable).
# IMPORTANT: pin to a specific version when you decide which one to use.
# The plugin adds AWS-specific checks beyond core Terraform rules.
# After uncommenting, run locally:
#   tflint --init
# Then in CI it will auto-install via the same flag.
#
# plugin "aws" {
#   enabled = true                                        # turn on the AWS rules
#   version = "X.Y.Z"                                     # <-- pin a released version here
#   source  = "github.com/terraform-linters/tflint-ruleset-aws"
# }

# Global rules configuration (keep defaults; adjust as you see findings).
rule "terraform_deprecated_interpolation" { enabled = true } # prefer modern expressions
rule "terraform_unused_declarations" { enabled = true }      # catch dead vars/locals
rule "terraform_naming_convention" { enabled = true }        # consistent names

# Exclude paths if needed (example: generated or vendored code)
# ignore_paths = ["**/.terraform/**/*"]

# Module source trust (optional) — require registry or verified sources only.
# allowed_module_sources = [
#   "registry.terraform.io/*/*/*"
# ]
