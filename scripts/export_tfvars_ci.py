# scripts/export_tfvars_ci.py
import json, os, sys, re

GITHUB_ENV = os.environ.get("GITHUB_ENV")
if not GITHUB_ENV:
    print("Missing GITHUB_ENV")
    sys.exit(1)

def normalize_list(raw: str) -> str:
    """
    Accepts:
      - '["a","b"]' (JSON) -> pass through
      - '["a", "b"]' (JSON) -> pass through
      - [a,b] or [a, b] (no quotes) -> -> '["a","b"]'
      - '' -> ''
    Returns a JSON string or '' if empty.
    """
    if not raw or raw.strip() == "":
        return ""
    s = raw.strip()
    # if already valid JSON array, keep it
    try:
        arr = json.loads(s)
        if isinstance(arr, list):
            return json.dumps(arr)
    except Exception:
        pass
    # strip outer [ ]
    if s[0] == "[" and s[-1] == "]":
        inner = s[1:-1].strip()
        if not inner:
            return "[]"
        # split on commas not inside quotes (we assume no quotes in bad case)
        parts = [p.strip() for p in inner.split(",")]
        # drop surrounding quotes if any, then re-quote
        cleaned = []
        for p in parts:
            p = p.strip()
            if p.startswith('"') and p.endswith('"'):
                p = p[1:-1]
            cleaned.append(p)
        return json.dumps(cleaned)
    # fallback: single value
    return json.dumps([s])

def write_env(k: str, v: str):
    if not v or v.strip() == "":
        return
    with open(GITHUB_ENV, "a", encoding="utf-8") as f:
        f.write(f"{k}={v}\n")
    print(f"export {k}={v}")

# Always export region (required)
aws_region = os.environ.get("AWS_REGION", "")
if not aws_region:
    print("ERROR: AWS_REGION not provided to export_tfvars_ci.py step.")
    sys.exit(1)
write_env("TF_VAR_region", aws_region)

# Scalar passthroughs (exactly as provided)
for name in [
    "project_name",
    "environment",
    "vpc_cidr",
    "enable_nat_gateway",
    "use_eip",
    "ssh_allowed_cidr",
]:
    raw = os.environ.get(f"RAW_TF_VAR_{name}", "")
    if raw:
        write_env(f"TF_VAR_{name}", raw)

# Lists that need normalization
for name in [
    "azs",
    "public_subnet_cidrs",
    "private_app_subnet_cidrs",
    "private_db_subnet_cidrs",
]:
    raw = os.environ.get(f"RAW_TF_VAR_{name}", "")
    if raw:
        write_env(f"TF_VAR_{name}", normalize_list(raw))
