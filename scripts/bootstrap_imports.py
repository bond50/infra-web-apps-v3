# scripts/bootstrap_imports.py
import os
import subprocess
import shlex

TF_DIR   = os.environ.get("TF_DIR", "./bootstrap")
REPO     = os.environ["CFG_REPO"]                   # e.g. infra-web-apps-v3
PROJECT  = os.environ["CFG_PROJECT_NAME"]           # e.g. web-apps
BUCKET   = os.environ["CFG_BUCKET"]                 # S3 bucket name
TABLE    = os.environ["CFG_TABLE"]                  # DynamoDB table name

# Optional: Account id is only needed for the OIDC import id
def run(cmd):
    print(f"+ {cmd}")
    try:
        subprocess.run(shlex.split(cmd), check=True)
    except subprocess.CalledProcessError as e:
        # Import must be idempotent — ignore failures so the job can continue
        print(f"  (import ignored error) {e}")

def aws(query):
    out = subprocess.check_output(shlex.split(query))
    return out.decode().strip()

print("== terraform state (before) ==")
subprocess.run(shlex.split(f"terraform -chdir={TF_DIR} state list"), check=False)

# -------- AWS resources (safe idempotent imports) --------
# OIDC provider (import by ARN)
ACCOUNT_ID = aws("aws sts get-caller-identity --query Account --output text")
OIDC_ARN   = f"arn:aws:iam::{ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
run(f'terraform -chdir={TF_DIR} import -input=false aws_iam_openid_connect_provider.github "{OIDC_ARN}"')

# Backend pieces
run(f'terraform -chdir={TF_DIR} import -input=false aws_s3_bucket.tfstate "{BUCKET}"')
run(f'terraform -chdir={TF_DIR} import -input=false aws_dynamodb_table.tf_lock "{TABLE}"')

# GHA role + admin attach
ROLE_NAME = f"{PROJECT}-gha"
run(f'terraform -chdir={TF_DIR} import -input=false aws_iam_role.github_actions "{ROLE_NAME}"')
ATTACH_ID = f'{ROLE_NAME}/arn:aws:iam::aws:policy/AdministratorAccess'
run(f'terraform -chdir={TF_DIR} import -input=false aws_iam_role_policy_attachment.gha_admin "{ATTACH_ID}"')

# -------- GitHub Variables managed by Terraform --------
# NOTE: these resource names MUST match bootstrap/main.tf
gh_vars_base = {
    "github_actions_variable.aws_region":       "AWS_REGION",
    "github_actions_variable.tf_state_bucket":  "TF_STATE_BUCKET",
    "github_actions_variable.tf_state_table":   "TF_STATE_TABLE",
    "github_actions_variable.tf_state_key":     "TF_STATE_KEY",
    "github_actions_variable.aws_role_arn":     "AWS_ROLE_ARN",
}
for addr, varname in gh_vars_base.items():
    run(f'terraform -chdir={TF_DIR} import -input=false {addr} "{REPO}:{varname}"')

# Counted GitHub Variables (only exist when corresponding TF_VAR_* is non-empty)
# IMPORTANT: import to ADDRESS[0]
tfvar_resources = {
    "github_actions_variable.tfvar_project_name":             "TF_VAR_project_name",
    "github_actions_variable.tfvar_environment":              "TF_VAR_environment",
    "github_actions_variable.tfvar_region":                   "TF_VAR_region",
    "github_actions_variable.tfvar_vpc_cidr":                 "TF_VAR_vpc_cidr",
    "github_actions_variable.tfvar_public_subnet_cidrs":      "TF_VAR_public_subnet_cidrs",
    "github_actions_variable.tfvar_private_app_subnet_cidrs": "TF_VAR_private_app_subnet_cidrs",
    "github_actions_variable.tfvar_private_db_subnet_cidrs":  "TF_VAR_private_db_subnet_cidrs",
    "github_actions_variable.tfvar_enable_nat_gateway":       "TF_VAR_enable_nat_gateway",
    "github_actions_variable.tfvar_use_eip":                  "TF_VAR_use_eip",
    "github_actions_variable.tfvar_azs":                      "TF_VAR_azs",
    "github_actions_variable.tfvar_ssh_allowed_cidr":         "TF_VAR_ssh_allowed_cidr",
}

for addr, gh_name in tfvar_resources.items():
    # If the pipeline didn’t pass a value, the TF resource has count=0 → skip import.
    val = os.environ.get(gh_name, "")
    if val is None or str(val).strip() == "":
        print(f"skip {addr}[0] (no value provided for {gh_name})")
        continue
    run(f'terraform -chdir={TF_DIR} import -input=false {addr}[0] "{REPO}:{gh_name}"')

print("== terraform state (after) ==")
subprocess.run(shlex.split(f"terraform -chdir={TF_DIR} state list"), check=False)
print("imports finished")
