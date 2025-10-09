# scripts/bootstrap_resolve_config.py
import json, os, subprocess, sys, re

GITHUB_ENV = os.environ["GITHUB_ENV"]
GITHUB_OUTPUT = os.environ["GITHUB_OUTPUT"]

def sh(cmd, **kw):
    return subprocess.check_output(cmd, text=True, **kw).strip()

aws_region = os.environ["AWS_REGION"]
project_name = os.environ.get("PROJECT_NAME") or "web-apps"

repo = os.environ.get("GITHUB_REPO") or os.environ.get("GITHUB_REPOSITORY", "")
owner = os.environ.get("GITHUB_OWNER") or (repo.split("/")[0] if "/" in repo else os.environ.get("GITHUB_REPOSITORY_OWNER",""))
repo_name = repo.split("/")[-1] if "/" in repo else repo

# derive account id for sane default bucket name
account_id = sh(["aws", "sts", "get-caller-identity", "--query", "Account", "--output", "text"])

bucket = os.environ.get("TF_STATE_BUCKET", "")
if not bucket:
    # 63 chars max, lowercase
    bucket = f"{project_name}-tfstate-{account_id}-{aws_region}".lower()[:63]

table = os.environ.get("TF_STATE_TABLE", "") or f"tf-locks-{project_name}"
key   = os.environ.get("TF_STATE_KEY", "") or "infra/terraform.tfstate"

# write TF_VAR_* to env (used by terraform)
def env_put(k,v):
    with open(GITHUB_ENV, "a", encoding="utf-8") as fh:
        fh.write(f"{k}={v}\n")
    print(f"export {k}={v}")

env_put("TF_VAR_aws_region", aws_region)
env_put("TF_VAR_project_name", project_name)
env_put("TF_VAR_bucket_name", bucket)
env_put("TF_VAR_dynamodb_table_name", table)
env_put("TF_VAR_tf_state_key", key)
env_put("TF_VAR_github_owner", owner)
env_put("TF_VAR_github_repo", repo_name)
env_put("TF_VAR_github_token", os.environ.get("GH_TOKEN_ADMIN",""))

# optional TF_VAR_* values that we want to materialize as GitHub Variables later
def opt(k):
    v = os.environ.get(k, "")
    if v:
        env_put(f"TF_VAR_{k}", v)

for k in [
    "TF_VAR_project_name","TF_VAR_environment","TF_VAR_region","TF_VAR_vpc_cidr",
    "TF_VAR_public_subnet_cidrs","TF_VAR_private_app_subnet_cidrs","TF_VAR_private_db_subnet_cidrs",
    "TF_VAR_enable_nat_gateway","TF_VAR_use_eip","TF_VAR_azs"
]:
    opt(k)

# write outputs for later steps
with open(GITHUB_OUTPUT, "a", encoding="utf-8") as out:
    out.write(f"project_name={project_name}\n")
    out.write(f"aws_region={aws_region}\n")
    out.write(f"github_owner={owner}\n")
    out.write(f"github_repo={repo_name}\n")
    out.write(f"bucket_name={bucket}\n")
    out.write(f"dynamodb_table_name={table}\n")
    out.write(f"tf_state_key={key}\n")

print("Resolved config written to env & outputs.")
