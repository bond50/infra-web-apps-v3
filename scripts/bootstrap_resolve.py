#!/usr/bin/env python3
import os, sys, boto3

def out(k, v):
    with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as fh:
        fh.write(f"{k}={v}\n")

def env(k, v):
    with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as fh:
        fh.write(f"{k}={v}\n")

aws_region = os.getenv("AWS_REGION")
pn  = os.getenv("TF_VAR_project_name") or "web-apps"

# derive owner/repo
owner = os.getenv("GITHUB_REPOSITORY_OWNER") or ""
repo_full = os.getenv("GITHUB_REPOSITORY") or ""
repo = repo_full.split("/", 1)[-1] if "/" in repo_full else (os.getenv("REPO") or "")

sts = boto3.client("sts", region_name=aws_region)
acct = sts.get_caller_identity()["Account"]

bucket = os.getenv("TF_STATE_BUCKET") or f"{pn}-tfstate-{acct}-{aws_region}"
bucket = bucket.lower()[:63]
ddb    = os.getenv("TF_STATE_TABLE") or f"tf-locks-{pn}"
key    = os.getenv("TF_STATE_KEY") or "infra/terraform.tfstate"

# outputs for later steps
out("project_name", pn)
out("aws_region", aws_region)
out("github_owner", owner)
out("github_repo", repo)
out("bucket_name", bucket)
out("dynamodb_table_name", ddb)
out("tf_state_key", key)

# export TF_VAR_* for bootstrap module
env("TF_VAR_aws_region", aws_region)
env("TF_VAR_project_name", pn)
env("TF_VAR_bucket_name", bucket)
env("TF_VAR_dynamodb_table_name", ddb)
env("TF_VAR_tf_state_key", key)
env("TF_VAR_github_owner", owner)
env("TF_VAR_github_repo", repo)

# pass PAT (provided to step env as GH_TOKEN_ADMIN)
gh_pat = os.getenv("GH_TOKEN_ADMIN", "")
if gh_pat:
    env("TF_VAR_github_token", gh_pat)

# optional TF_VAR_* to materialize in repo variables (defaults are safe)
env("TF_VAR_tfvar_region", os.getenv("TF_VAR_region") or aws_region)
env("TF_VAR_tfvar_project_name", os.getenv("TF_VAR_project_name") or pn)
env("TF_VAR_tfvar_environment", os.getenv("TF_VAR_environment") or "prod")
env("TF_VAR_tfvar_vpc_cidr", os.getenv("TF_VAR_vpc_cidr") or "172.20.0.0/16")
env("TF_VAR_tfvar_azs", os.getenv("TF_VAR_azs") or '["us-east-1a","us-east-1b"]')
env("TF_VAR_tfvar_public_subnet_cidrs", os.getenv("TF_VAR_public_subnet_cidrs") or '["172.20.0.0/24","172.20.1.0/24"]')
env("TF_VAR_tfvar_private_app_subnet_cidrs", os.getenv("TF_VAR_private_app_subnet_cidrs") or '["172.20.10.0/24","172.20.11.0/24"]')
env("TF_VAR_tfvar_private_db_subnet_cidrs", os.getenv("TF_VAR_private_db_subnet_cidrs") or '["172.20.20.0/24","172.20.21.0/24"]')
env("TF_VAR_tfvar_enable_nat_gateway", os.getenv("TF_VAR_enable_nat_gateway") or "false")
env("TF_VAR_tfvar_use_eip", os.getenv("TF_VAR_use_eip") or "false")

print("Resolved bootstrap config and exported TF_VARs.")
