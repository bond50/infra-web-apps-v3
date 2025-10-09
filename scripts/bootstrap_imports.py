#!/usr/bin/env python3
import os, subprocess, boto3

def run(cmd, cwd=None):
    print("+", " ".join(cmd))
    try:
        subprocess.run(cmd, cwd=cwd, check=True)
    except subprocess.CalledProcessError:
        # ignore if not importable / already exists
        pass

aws_region = os.getenv("AWS_REGION")
repo = os.getenv("REPO") or (os.getenv("GITHUB_REPOSITORY") or "").split("/")[-1]
bdir = "./bootstrap"

iam = boto3.client("iam", region_name=aws_region)
s3  = boto3.client("s3", region_name=aws_region)
dynamodb = boto3.client("dynamodb", region_name=aws_region)
sts = boto3.client("sts", region_name=aws_region)

acct = sts.get_caller_identity()["Account"]
oidc_arn = f"arn:aws:iam::{acct}:oidc-provider/token.actions.githubusercontent.com"
providers = iam.list_open_id_connect_providers().get("OpenIDConnectProviderList", [])
if any(p.get("Arn") == oidc_arn for p in providers):
    run(["terraform","import","-input=false","aws_iam_openid_connect_provider.github", oidc_arn], cwd=bdir)

# Repo variables (import if present)
for name in [
    "AWS_REGION", "TF_STATE_BUCKET", "TF_STATE_TABLE", "TF_STATE_KEY", "AWS_ROLE_ARN",
    "TF_VAR_project_name","TF_VAR_environment","TF_VAR_region","TF_VAR_vpc_cidr",
    "TF_VAR_public_subnet_cidrs","TF_VAR_private_app_subnet_cidrs","TF_VAR_private_db_subnet_cidrs",
    "TF_VAR_enable_nat_gateway","TF_VAR_use_eip","TF_VAR_azs"
]:
    run(["terraform","import","-input=false", f"github_actions_variable.{name.lower()}", f"{repo}:{name}"], cwd=bdir)

# S3
bucket = os.getenv("BUCKET") or ""
if bucket:
    try:
        s3.head_bucket(Bucket=bucket)
        run(["terraform","import","-input=false","aws_s3_bucket.tfstate", bucket], cwd=bdir)
    except Exception:
        pass

# DynamoDB
table = os.getenv("TABLE") or ""
if table:
    try:
        dynamodb.describe_table(TableName=table)
        run(["terraform","import","-input=false","aws_dynamodb_table.tf_lock", table], cwd=bdir)
    except Exception:
        pass

# IAM role
role_name = os.getenv("ROLE_NAME") or (os.getenv("TF_VAR_project_name","web-apps") + "-gha")
try:
    iam.get_role(RoleName=role_name)
    run(["terraform","import","-input=false","aws_iam_role.github_actions", role_name], cwd=bdir)
    attach_id = f"{role_name}/arn:aws:iam::aws:policy/AdministratorAccess"
    run(["terraform","import","-input=false","aws_iam_role_policy_attachment.gha_admin", attach_id], cwd=bdir)
except Exception:
    pass

print("Import-if-present step finished.")
