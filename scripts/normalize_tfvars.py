#!/usr/bin/env python3
import json, os, re, sys

def pick(*names, default=""):
    for n in names:
        v = os.getenv(n, "").strip()
        if v:
            return v
    return default

def norm_list(val, default_json):
    if not val:
        return default_json
    try:
        data = json.loads(val)
        if isinstance(data, list):
            return json.dumps([str(x) for x in data])
    except Exception:
        pass
    v = val.strip()
    if v.startswith("[") and v.endswith("]"):
        v = v[1:-1]
    items = [i.strip().strip('"').strip("'") for i in v.split(",") if i.strip()]
    return json.dumps(items)

def norm_bool(val, default=False):
    v = (val or "").strip().lower()
    if v in ("true", "false"):
        return v
    return "true" if default else "false"

# Coalesce (lower + UPPER) and apply safe defaults
pn   = pick("TF_VAR_project_name","TF_VAR_PROJECT_NAME", default="web-apps")
envv = pick("TF_VAR_environment","TF_VAR_ENVIRONMENT", default="prod")
reg  = pick("TF_VAR_region","TF_VAR_REGION", default="us-east-1")
vpc  = pick("TF_VAR_vpc_cidr","TF_VAR_VPC_CIDR", default="172.20.0.0/16")
ssh  = pick("TF_VAR_ssh_allowed_cidr","TF_VAR_SSH_ALLOWED_CIDR", default="197.248.148.214/32")

pub = norm_list(pick("TF_VAR_public_subnet_cidrs","TF_VAR_PUBLIC_SUBNET_CIDRS"),
                '["172.20.0.0/24","172.20.1.0/24"]')
app = norm_list(pick("TF_VAR_private_app_subnet_cidrs","TF_VAR_PRIVATE_APP_SUBNET_CIDRS"),
                '["172.20.10.0/24","172.20.11.0/24"]')
db  = norm_list(pick("TF_VAR_private_db_subnet_cidrs","TF_VAR_PRIVATE_DB_SUBNET_CIDRS"),
                '["172.20.20.0/24","172.20.21.0/24"]')
azs = norm_list(pick("TF_VAR_azs","TF_VAR_AZS"),
                '["us-east-1a","us-east-1b"]')

engw = norm_bool(pick("TF_VAR_enable_nat_gateway","TF_VAR_ENABLE_NAT_GATEWAY"), False)
ueip = norm_bool(pick("TF_VAR_use_eip","TF_VAR_USE_EIP"), False)
eni  = norm_bool(pick("TF_VAR_enable_nat_instance","TF_VAR_ENABLE_NAT_INSTANCE"), False)

lines = [
  f"TF_VAR_project_name={pn}",
  f"TF_VAR_environment={envv}",
  f"TF_VAR_region={reg}",
  f"TF_VAR_vpc_cidr={vpc}",
  f"TF_VAR_public_subnet_cidrs={pub}",
  f"TF_VAR_private_app_subnet_cidrs={app}",
  f"TF_VAR_private_db_subnet_cidrs={db}",
  f"TF_VAR_azs={azs}",
  f"TF_VAR_enable_nat_gateway={engw}",
  f"TF_VAR_use_eip={ueip}",
  f"TF_VAR_enable_nat_instance={eni}",
  f"TF_VAR_ssh_allowed_cidr={ssh}",
]

with open(os.environ["GITHUB_ENV"], "a", encoding="utf-8") as fh:
    for line in lines:
        fh.write(line + "\n")
print("Normalized TF_VARs exported.")
