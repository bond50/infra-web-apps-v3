# scripts/bootstrap_imports.py
import os, subprocess, sys

TF_DIR = os.environ.get("TF_DIR", "./bootstrap")
REPO   = os.environ["CFG_REPO"]  # repo name only, no owner
PROJ   = os.environ["CFG_PROJECT_NAME"]

def sh_ok(cmd):
    try:
        subprocess.check_call(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return True
    except subprocess.CalledProcessError:
        return False

def sh_out(cmd):
    return subprocess.check_output(cmd, text=True).strip()

def tf_import(addr, rid):
    print(f"terraform import {addr} {rid}")
    subprocess.call(["terraform","-chdir="+TF_DIR,"import","-input=false",addr,rid])

# 1) OIDC provider
acct = sh_out(["aws","sts","get-caller-identity","--query","Account","--output","text"])
oidc_arn = f"arn:aws:iam::{acct}:oidc-provider/token.actions.githubusercontent.com"
print("Checking OIDC provider…")
oids = sh_out(["aws","iam","list-open-id-connect-providers","--query",
               "OpenIDConnectProviderList[].Arn","--output","text"])
if oidc_arn in oids.split():
    tf_import("aws_iam_openid_connect_provider.github", oidc_arn)
else:
    print("OIDC provider not present; will be created on apply.")

# 2) GitHub repo variables (import-if-present)
gh_vars = [
    ("github_actions_variable.aws_region",              "AWS_REGION"),
    ("github_actions_variable.tf_state_bucket",         "TF_STATE_BUCKET"),
    ("github_actions_variable.tf_state_table",          "TF_STATE_TABLE"),
    ("github_actions_variable.tf_state_key",            "TF_STATE_KEY"),
    ("github_actions_variable.aws_role_arn",            "AWS_ROLE_ARN"),
    ("github_actions_variable.tfvar_project_name",      "TF_VAR_project_name"),
    ("github_actions_variable.tfvar_environment",       "TF_VAR_environment"),
    ("github_actions_variable.tfvar_region",            "TF_VAR_region"),
    ("github_actions_variable.tfvar_vpc_cidr",          "TF_VAR_vpc_cidr"),
    ("github_actions_variable.tfvar_public_subnet_cidrs","TF_VAR_public_subnet_cidrs"),
    ("github_actions_variable.tfvar_private_app_subnet_cidrs","TF_VAR_private_app_subnet_cidrs"),
    ("github_actions_variable.tfvar_private_db_subnet_cidrs","TF_VAR_private_db_subnet_cidrs"),
    ("github_actions_variable.tfvar_enable_nat_gateway","TF_VAR_enable_nat_gateway"),
    ("github_actions_variable.tfvar_use_eip",          "TF_VAR_use_eip"),
    ("github_actions_variable.tfvar_azs",              "TF_VAR_azs"),
]
print("Importing repo variables if they already exist…")
for addr, varname in gh_vars:
    tf_import(addr, f"{REPO}:{varname}")

# 3) S3 bucket
bucket = os.environ["CFG_BUCKET"]
print(f"Checking S3 bucket {bucket}…")
if sh_ok(["aws","s3api","head-bucket","--bucket",bucket]):
    tf_import("aws_s3_bucket.tfstate", bucket)
else:
    print("Bucket not found or not accessible; will be created on apply.")

# 4) DynamoDB table
table = os.environ["CFG_TABLE"]
print(f"Checking DynamoDB table {table}…")
if sh_ok(["aws","dynamodb","describe-table","--table-name",table]):
    tf_import("aws_dynamodb_table.tf_lock", table)
else:
    print("Table not found; will be created on apply.")

# 5) IAM role (+ attachment)
role_name = f"{PROJ}-gha"
print(f"Checking IAM role {role_name}…")
if sh_ok(["aws","iam","get-role","--role-name",role_name]):
    tf_import("aws_iam_role.github_actions", role_name)
    attach_id = f"{role_name}/arn:aws:iam::aws:policy/AdministratorAccess"
    tf_import("aws_iam_role_policy_attachment.gha_admin", attach_id)
else:
    print("Role not found; will be created on apply.")

print("Imports completed (best-effort).")
